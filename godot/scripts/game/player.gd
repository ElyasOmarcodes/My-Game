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

const GRAVITY := 22.0
const JUMP_SPEED := 7.4
const LOOK_SENSITIVITY := 0.18
const MOUSE_SENSITIVITY := 0.12
const CAMERA_DISTANCE := 5.2
const CAMERA_HEIGHT := 1.9
const RESPAWN_DELAY := 4.0

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
var _stride := 0.0
var _next_shot_at := 0.0
var _reload_until := 0.0
var _respawn_at := 0.0

var _spring: SpringArm3D
var _camera: Camera3D
var _model_root: Node3D
var _animation: AnimationPlayer
var _muzzle: Node3D
var _controls: TouchControls
var _library: AssetLibrary

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

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	collision_layer = 2
	collision_mask = 1

	_build_model()
	if is_local:
		_build_camera()

func set_controls(controls: TouchControls) -> void:
	_controls = controls
	controls.fire_pressed.connect(func(down: bool): set_meta("firing", down))
	controls.jump_pressed.connect(_try_jump)
	controls.reload_pressed.connect(reload)

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
		var instance := scene.instantiate()
		_model_root.add_child(instance)
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
		var instance := scene.instantiate()
		instance.scale = Vector3.ONE * 0.9
		_muzzle.add_child(instance)
	else:
		_add_box(_muzzle, Vector3(0, 0, 0.2), Vector3(0.09, 0.12, 0.55), Color(0.08, 0.09, 0.1))
		_add_box(_muzzle, Vector3(0, 0.08, 0.1), Vector3(0.03, 0.02, 0.1),
			agent.get("accent", Color.CYAN), true)

func _tint(node: Node) -> void:
	# Team colour on the imported model, applied as an overlay so the kit's own
	# textures still read through.
	var accent: Color = Color("#3BE8FF") if team == Session.Team.ALPHA else Color("#FF7A3B")
	for child in node.get_children():
		if child is MeshInstance3D:
			var overlay := StandardMaterial3D.new()
			overlay.albedo_color = Color(accent.r, accent.g, accent.b, 0.22)
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			overlay.emission_enabled = true
			overlay.emission = accent
			overlay.emission_energy_multiplier = 0.6
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
	_spring.position = Vector3(0, CAMERA_HEIGHT, 0)
	_spring.collision_mask = 1        # pull in against world geometry only
	add_child(_spring)

	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.current = true
	_spring.add_child(_camera)

# --- frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not alive:
		if Time.get_ticks_msec() / 1000.0 >= _respawn_at:
			respawn()
		return

	if is_local:
		_read_input(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var planar := Vector2(velocity.x, velocity.z).length()
	_stride += planar * delta * 2.4
	_drive_animation(planar)

func _read_input(_delta: float) -> void:
	if _controls == null:
		return

	var look := _controls.consume_look()
	yaw -= look.x * LOOK_SENSITIVITY
	pitch = clampf(pitch + look.y * LOOK_SENSITIVITY, -35.0, 55.0)
	rotation.y = deg_to_rad(yaw)
	if _spring:
		_spring.rotation.x = deg_to_rad(-pitch)

	var axis := _controls.move_axis()
	var speed: float = float(agent.get("speed", 6.0)) * (1.45 if _controls.sprinting else 1.0)
	var direction := (transform.basis.x * axis.x + transform.basis.z * -axis.y).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if _controls.jump_held():
		_try_jump()
	if get_meta("firing", false) or _controls.fire_held():
		fire()

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_SPEED

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
		reload()
		return

	_next_shot_at = now + 1.0 / maxf(0.1, float(weapon_def.get("rate", 8.0)))
	ammo_in_clip -= 1
	ammo_changed.emit(ammo_in_clip, ammo_reserve)

	var origin: Vector3 = _camera.global_position if _camera else global_position + Vector3.UP * 1.5
	var spread: float = float(weapon_def.get("spread", 0.02))
	var direction := -_camera.global_transform.basis.z if _camera else -global_transform.basis.z
	direction += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0.0)

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction.normalized() * float(weapon_def.get("range", 100.0)))
	query.exclude = [get_rid()]
	query.collision_mask = 1 | 2

	var hit := space.intersect_ray(query)
	if hit.has("collider"):
		var target = hit["collider"]
		if target is Player and target.player_id != player_id:
			NetGame.report_hit(target.player_id, float(weapon_def.get("damage", 20.0)))

func reload() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if ammo_reserve <= 0 or ammo_in_clip >= int(weapon_def.get("clip", 30)) or now < _reload_until:
		return

	_reload_until = now + float(weapon_def.get("reload", 1.6))
	await get_tree().create_timer(float(weapon_def.get("reload", 1.6))).timeout

	var needed: int = int(weapon_def.get("clip", 30)) - ammo_in_clip
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
	alive = true
	visible = true
	velocity = Vector3.ZERO
	if at != Transform3D.IDENTITY:
		global_transform = at
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo_in_clip, ammo_reserve)
