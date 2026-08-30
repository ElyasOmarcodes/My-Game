class_name Player
extends CharacterBody3D
## The locally driven agent: movement, aim, jump and shooting.
##
## The body model comes from the CC0 character kit when one was fetched, and
## falls back to primitives otherwise, so the project always runs. Damage and
## scoring are decided by the host (see net/net_game.gd); this only asks.

signal died(killer_id: String)
signal health_changed(current: float, maximum: float)
signal ammo_changed(in_clip: int, reserve: int)
signal grenades_changed(left: int)

const GRAVITY := 24.0
const JUMP_SPEED := 8.0
const CAMERA_DISTANCE := 5.2
const RESPAWN_DELAY := 4.0

## Movement feel. Ground acceleration is high enough that a tap of the stick
## answers at once, but not instant — an instant velocity change is what makes
## a character feel like a sliding box rather than someone running. Air control
## is deliberately weak, and stopping is faster than starting.
const GROUND_ACCEL := 58.0
const AIR_ACCEL := 14.0
const GROUND_BRAKE := 74.0
const AIR_BRAKE := 4.0
const TURN_SMOOTHING := 16.0      ## how fast the body swings to face the camera
const LOOK_SMOOTHING := 22.0      ## takes the stair-steps out of a touch drag

## Stance: what each one does to speed and to how tall you stand.
const STANCE_SPEED := [1.0, 0.46, 0.22]
const STANCE_HEIGHT := [1.8, 1.25, 0.75]
const STANCE_EYE := [1.95, 1.45, 0.85]

const SPRINT_MULTIPLIER := 1.62
const GRENADE_COOLDOWN := 1.4

var agent: Dictionary = {}
var weapon_def: Dictionary = {}
var player_id: String = ""
var team: int = Session.Team.ALPHA
var is_local := true

var health := 100.0
var max_health := 100.0
var ammo_in_clip := 30
var ammo_reserve := 150
var alive := true

var yaw := 0.0
var pitch := 6.0
var stance: int = 0
var grenades := 3

var _stride := 0.0
var _next_shot_at := 0.0
var _reload_until := 0.0
var _respawn_at := 0.0
var _next_grenade_at := 0.0

## Smoothed aim, and the kick the weapon adds on top of it.
var _look_velocity := Vector2.ZERO
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _sensitivity := 0.20

var _spring: SpringArm3D
var _camera: Camera3D
var _model_root: Node3D
var _animation: AnimationPlayer
var _muzzle: Node3D
var _muzzle_flash: OmniLight3D
var _controls: TouchControls
var _library: AssetLibrary
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D

static func create(library: AssetLibrary, agent_id: String, team_value: int,
		player_identifier: String, local: bool) -> Player:
	var player := Player.new()
	player._library = library
	player.agent = AgentCatalog.agent(agent_id)
	player.weapon_def = AgentCatalog.weapon(player.agent["weapon"])
	player.team = team_value
	player.player_id = player_identifier
	player.is_local = local
	return player

func _ready() -> void:
	max_health = float(agent.get("health", 100.0))
	health = max_health
	ammo_in_clip = int(weapon_def.get("clip", 30))
	ammo_reserve = int(weapon_def.get("reserve", 150))

	_capsule = CapsuleShape3D.new()
	_capsule.height = float(STANCE_HEIGHT[0])
	_capsule.radius = 0.35
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = float(STANCE_HEIGHT[0]) * 0.5
	add_child(_shape)

	collision_layer = 2
	collision_mask = 1
	# Everything a bullet or a blast can find is in one group, so neither has to
	# know how the scene happens to be arranged.
	add_to_group("agents")

	_sensitivity = float(Session.get_pref("aim", "sensitivity", 0.20))
	_build_model()
	if is_local:
		_build_camera()

func set_controls(controls: TouchControls) -> void:
	_controls = controls
	controls.fire_pressed.connect(func(down: bool): set_meta("firing", down))
	controls.jump_pressed.connect(_try_jump)
	controls.reload_pressed.connect(reload)
	controls.grenade_pressed.connect(throw_grenade)
	controls.stance_changed.connect(set_stance)

## Standing, crouched or prone. Changes how fast you move, how tall your hitbox
## is and where the camera sits.
func set_stance(value: int) -> void:
	stance = clampi(value, 0, STANCE_HEIGHT.size() - 1)
	var height := float(STANCE_HEIGHT[stance])
	_capsule.height = height
	_shape.position.y = height * 0.5
	if _spring:
		var rise := create_tween()
		rise.tween_property(_spring, "position:y", float(STANCE_EYE[stance]), 0.18)

# --- construction -------------------------------------------------------------

func _build_model() -> void:
	_model_root = Node3D.new()
	add_child(_model_root)

	var scene: PackedScene = null
	if _library and _library.has("characters"):
		scene = _library.find("characters", String(agent.get("model_hint", "")))
		if scene == null:
			scene = _library.pick("characters", AgentCatalog.agent_index(agent["id"]))

	if scene:
		var instance := scene.instantiate() as Node3D
		if instance:
			_model_root.add_child(instance)
			# Kits differ wildly in scale; a KayKit adventurer is several units
			# tall out of the box. Everyone stands 1.8 m here.
			ModelUtils.fit_height(instance, 1.8)
			ModelUtils.rest_on_ground(instance)
			_animation = _find_animation_player(instance)
			_tint(instance)
	else:
		_build_placeholder()

	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.25, 1.25, 0.55)
	add_child(_muzzle)
	_attach_weapon()

func _build_placeholder() -> void:
	# Stand-in body so the game is playable before any kit has been fetched.
	var accent: Color = agent.get("accent", Color.CYAN)
	_add_box(_model_root, Vector3(0, 1.15, 0), Vector3(0.6, 0.7, 0.35), Color(0.12, 0.13, 0.16))
	_add_box(_model_root, Vector3(0, 1.62, 0), Vector3(0.32, 0.32, 0.32), Color(0.14, 0.15, 0.18))
	_add_box(_model_root, Vector3(0, 1.63, 0.17), Vector3(0.24, 0.08, 0.04), accent, true)
	_add_box(_model_root, Vector3(-0.15, 0.4, 0), Vector3(0.2, 0.8, 0.22), Color(0.1, 0.11, 0.13))
	_add_box(_model_root, Vector3(0.15, 0.4, 0), Vector3(0.2, 0.8, 0.22), Color(0.1, 0.11, 0.13))

func _add_box(parent: Node3D, offset: Vector3, size: Vector3, colour: Color,
		emissive := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset

	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if emissive:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 2.5
	mesh.material_override = material

	parent.add_child(mesh)
	return mesh

func _attach_weapon() -> void:
	var scene: PackedScene = null
	if _library and _library.has("weapons"):
		scene = _library.find("weapons", String(weapon_def.get("model_hint", "")))
		if scene == null:
			scene = _library.random("weapons")

	if scene:
		var instance := scene.instantiate() as Node3D
		if instance:
			# In the hand when the rig offers one, at the hip when it does not.
			var hand: BoneAttachment3D = null
			if _model_root.get_child_count() > 0:
				hand = ModelUtils.hand_attachment(_model_root.get_child(0) as Node3D)
			if hand != null:
				hand.add_child(instance)
			else:
				_muzzle.add_child(instance)
			# Two gun bodies carry five weapons, so size and colour are what
			# separate a sidearm from a marksman rifle at a glance.
			ModelUtils.fit_length_world(instance,
				float(weapon_def.get("model_size", 0.6)))
			_paint_weapon(instance, weapon_def.get("tint", Color.WHITE))
	else:
		_add_box(_muzzle, Vector3(0, 0, 0.2), Vector3(0.09, 0.12, 0.55), Color(0.08, 0.09, 0.1))
		_add_box(_muzzle, Vector3(0, 0.08, 0.1), Vector3(0.03, 0.02, 0.1),
			agent.get("accent", Color.CYAN), true)

## Recolours the gun without hiding the model's own shading.
func _paint_weapon(node: Node, tint: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var overlay := StandardMaterial3D.new()
			overlay.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(child as MeshInstance3D).material_overlay = overlay
		_paint_weapon(child, tint)

func _tint(node: Node) -> void:
	# Team colour on the imported model, applied as an overlay so the kit's own
	# textures still read through.
	var accent: Color = Color("#3BE8FF") if team == Session.Team.ALPHA else Color("#FF7A3B")
	for child in node.get_children():
		if child is MeshInstance3D:
			var overlay := StandardMaterial3D.new()
			overlay.albedo_color = Color(accent.r, accent.g, accent.b, 0.12)
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			overlay.emission_enabled = true
			overlay.emission = accent
			overlay.emission_energy_multiplier = 0.25
			child.material_overlay = overlay
		_tint(child)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _build_camera() -> void:
	_spring = SpringArm3D.new()
	_spring.spring_length = CAMERA_DISTANCE
	_spring.position = Vector3(0, float(STANCE_EYE[0]), 0)
	_spring.collision_mask = 1        # pull in against world geometry only
	add_child(_spring)

	_camera = Camera3D.new()
	_camera.fov = float(Session.get_pref("aim", "fov", 74.0))
	_camera.current = true
	_spring.add_child(_camera)

# --- frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not alive:
		if Time.get_ticks_msec() / 1000.0 >= _respawn_at:
			respawn()
		return

	if is_local:
		_aim(delta)
		_drive(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var planar := Vector2(velocity.x, velocity.z).length()
	_stride += planar * delta * 2.4
	_drive_animation(planar)

## Aim, smoothed. A raw touch drag arrives in coarse jumps, and feeding those
## straight into the camera is what makes a phone shooter feel cheap; easing
## towards the drag keeps the same total travel without the stair-steps.
func _aim(delta: float) -> void:
	if _controls == null:
		return

	var wanted := _controls.consume_look() * _sensitivity
	_look_velocity = _look_velocity.lerp(wanted / maxf(delta, 0.0001),
		1.0 - exp(-LOOK_SMOOTHING * delta))
	var applied := _look_velocity * delta

	yaw -= applied.x
	pitch = clampf(pitch + applied.y, -40.0, 62.0)

	# Recoil is added on top of the aim and pulled back down, so a burst walks
	# the camera up and settles rather than teleporting it.
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, 1.0 - exp(-9.0 * delta))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, 1.0 - exp(-9.0 * delta))

	rotation.y = deg_to_rad(yaw + _recoil_yaw)
	if _spring:
		_spring.rotation.x = deg_to_rad(-(pitch + _recoil_pitch))

## Movement, accelerated rather than assigned. Reaching top speed over a few
## frames and braking faster than it accelerates is most of what separates a
## body that feels like a person from one that feels like a cursor.
func _drive(delta: float) -> void:
	if _controls == null:
		return

	var axis := _controls.move_axis()
	var grounded := is_on_floor()

	var speed := float(agent.get("speed", 7.2)) * float(STANCE_SPEED[stance])
	if _controls.sprint_held() and stance == 0:
		speed *= SPRINT_MULTIPLIER

	var forward := -transform.basis.z
	var right := transform.basis.x
	var wanted := (right * axis.x + forward * axis.y)
	if wanted.length() > 1.0:
		wanted = wanted.normalized()

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var target := wanted * speed
	var rate := 0.0
	if wanted.length_squared() > 0.001:
		rate = GROUND_ACCEL if grounded else AIR_ACCEL
	else:
		rate = GROUND_BRAKE if grounded else AIR_BRAKE

	planar = planar.move_toward(target, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z

	# The body leans into the turn slightly, which reads as weight.
	if _model_root:
		var lean: float = clampf(-axis.x * 0.06, -0.09, 0.09)
		_model_root.rotation.z = lerpf(_model_root.rotation.z, lean,
			1.0 - exp(-TURN_SMOOTHING * delta))

	if _controls.jump_held():
		_try_jump()
	if get_meta("firing", false) or _controls.fire_held():
		fire()

func _try_jump() -> void:
	if is_on_floor() and alive:
		velocity.y = JUMP_SPEED
		if stance != 0:
			set_stance(0)

func _drive_animation(planar_speed: float) -> void:
	if _animation == null:
		# Placeholder body: swing it slightly so movement reads without a rig.
		if _model_root:
			_model_root.rotation.z = sin(_stride) * 0.04 * clampf(planar_speed / 6.0, 0.0, 1.0)
		return

	var wanted := "Idle" if planar_speed < 0.4 else ("Run" if planar_speed > 7.0 else "Walk")
	var chosen := _match_animation(wanted)
	if chosen != "" and _animation.current_animation != chosen:
		_animation.play(chosen)

func _match_animation(wanted: String) -> String:
	var lowered := wanted.to_lower()
	for name in _animation.get_animation_list():
		if String(name).to_lower().find(lowered) != -1:
			return name
	return ""

# --- combat -------------------------------------------------------------------

func fire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not alive or now < _reload_until or now < _next_shot_at:
		return
	if ammo_in_clip <= 0:
		Sfx.play("empty", 0.5)
		reload()
		return

	_next_shot_at = now + 1.0 / maxf(0.1, float(weapon_def.get("rate", 8.0)))
	ammo_in_clip -= 1
	ammo_changed.emit(ammo_in_clip, ammo_reserve)

	var origin := _eye_position()
	var direction := _aim_direction()
	var reach := float(weapon_def.get("range", 100.0))

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * reach)
	query.exclude = [get_rid()]
	query.collision_mask = 1 | 2

	var hit: Dictionary = space.intersect_ray(query)
	var landed: Vector3 = hit["position"] if hit.has("position") else \
		origin + direction * reach

	if hit.has("collider"):
		# The body a shot lands on is rarely the agent node itself — a remote
		# agent's hitbox is a child StaticBody3D — so walk up to whatever owns
		# a player id rather than testing the collider's own type.
		var victim := _agent_owning(hit["collider"])
		if victim != null:
			var victim_id := String(victim.get("player_id"))
			if victim_id != "" and victim_id != player_id:
				NetGame.report_hit(victim_id, float(weapon_def.get("damage", 20.0)))

	_report_shot(origin, landed)
	_kick()

## Everything a shot does that is not damage: the flash, the tracer and the
## report. Without these a hit that lands looks exactly like one that misses,
## which is why firing read as doing nothing at all.
func _report_shot(from: Vector3, to: Vector3) -> void:
	Sfx.play(String(weapon_def.get("voice", "rifle")), 0.8,
		randf_range(0.94, 1.06))
	_flash_muzzle()
	_tracer(from, to)

func _kick() -> void:
	var kick := float(weapon_def.get("kick", 1.2))
	_recoil_pitch += kick * randf_range(0.85, 1.25)
	_recoil_yaw += kick * randf_range(-0.45, 0.45)

func _eye_position() -> Vector3:
	if _camera:
		return _camera.global_position
	return global_position + Vector3.UP * float(STANCE_EYE[stance])

## Where the shot goes: down the camera's own axis, spread a little, so what is
## under the crosshair is what gets hit.
func _aim_direction() -> Vector3:
	var basis := _camera.global_transform.basis if _camera else global_transform.basis
	var spread := float(weapon_def.get("spread", 0.02))
	var direction := -basis.z \
		+ basis.x * randf_range(-spread, spread) \
		+ basis.y * randf_range(-spread, spread)
	return direction.normalized()

## Climbs from whatever the ray struck to the agent that owns it.
func _agent_owning(collider: Variant) -> Node:
	var node := collider as Node
	while node != null:
		if node.is_in_group("agents"):
			return node
		node = node.get_parent()
	return null

func _flash_muzzle() -> void:
	if _muzzle == null:
		return
	if _muzzle_flash == null:
		_muzzle_flash = OmniLight3D.new()
		_muzzle_flash.light_color = Color(1.0, 0.85, 0.55)
		_muzzle_flash.omni_range = 6.0
		_muzzle_flash.light_energy = 0.0
		_muzzle.add_child(_muzzle_flash)

	_muzzle_flash.light_energy = 7.0
	var fade := create_tween()
	fade.tween_property(_muzzle_flash, "light_energy", 0.0, 0.07)

## A line that lives for a couple of frames. Cheap, and it tells you instantly
## whether you were pointing where you thought you were.
func _tracer(from: Vector3, to: Vector3) -> void:
	var world := get_parent()
	if world == null:
		return

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(to - from)
	mesh.surface_end()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.92, 0.62, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.5)
	material.emission_energy_multiplier = 4.0

	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = material
	world.add_child(line)
	line.global_position = from

	var fade := world.create_tween()
	fade.tween_property(material, "albedo_color:a", 0.0, 0.09)
	fade.tween_callback(line.queue_free)

## One grenade, thrown along the camera's line, cooking on its own fuse.
func throw_grenade() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not alive or grenades <= 0 or now < _next_grenade_at:
		return
	_next_grenade_at = now + GRENADE_COOLDOWN
	grenades -= 1
	grenades_changed.emit(grenades)

	var world := get_parent()
	if world == null:
		return
	Grenade.throw_from(world, _library, _eye_position() + _aim_direction() * 0.8,
		_aim_direction(), player_id)

func reload() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var clip: int = int(weapon_def.get("clip", 30))
	if ammo_reserve <= 0 or ammo_in_clip >= clip or now < _reload_until:
		return

	var seconds := float(weapon_def.get("reload", 1.6))
	_reload_until = now + seconds
	Sfx.play("reload", 0.7)
	await get_tree().create_timer(seconds).timeout

	var needed: int = clip - ammo_in_clip
	var taken: int = mini(needed, ammo_reserve)
	ammo_in_clip += taken
	ammo_reserve -= taken
	ammo_changed.emit(ammo_in_clip, ammo_reserve)

func apply_damage(amount: float, attacker_id: String) -> void:
	if not alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die(attacker_id)

func _die(killer_id: String) -> void:
	alive = false
	visible = false
	_respawn_at = Time.get_ticks_msec() / 1000.0 + RESPAWN_DELAY
	died.emit(killer_id)

func respawn(at: Transform3D = Transform3D.IDENTITY) -> void:
	health = max_health
	ammo_in_clip = int(weapon_def.get("clip", 30))
	ammo_reserve = int(weapon_def.get("reserve", 150))
	grenades = 3
	set_stance(0)
	alive = true
	visible = true
	velocity = Vector3.ZERO
	if at != Transform3D.IDENTITY:
		global_transform = at
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo_in_clip, ammo_reserve)
	grenades_changed.emit(grenades)
