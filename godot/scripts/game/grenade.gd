class_name Grenade
extends RigidBody3D
## A thrown grenade: it arcs, it bounces, it cooks for a fixed fuse and then
## kills anything close.
##
## The throw is a real rigid body rather than a scripted arc, so it rolls off a
## roof and down a step the way a player expects, and everyone watching sees it
## land in the same place because only the thrower resolves the damage.

const FUSE := 2.4
const BLAST_RADIUS := 7.0
const KILLING_RADIUS := 4.5
const DAMAGE := 250.0          ## one grenade, one kill, as asked
const THROW_SPEED := 15.0
const RADIUS := 0.13

var owner_id := ""

var _fuse_left := FUSE

## Throws one from `origin` along `direction`, and hands it back so the caller
## can hold a reference if it wants one.
static func throw_from(world: Node, library: AssetLibrary, origin: Vector3,
		direction: Vector3, thrower_id: String) -> Grenade:
	var grenade := Grenade.new()
	grenade.owner_id = thrower_id
	grenade.set_meta("library", library)
	world.add_child(grenade)
	grenade.global_position = origin
	# Up-weighted, so a flat throw still arcs instead of skidding along a wall.
	grenade.linear_velocity = (direction.normalized() + Vector3.UP * 0.34) \
		.normalized() * THROW_SPEED
	grenade.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8),
		randf_range(-8, 8))
	return grenade

func _ready() -> void:
	gravity_scale = 1.35            # a grenade is dense; it falls fast
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.32
	physics_material_override.friction = 0.85

	collision_layer = 4
	collision_mask = 1

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)

	_build_model()

func _build_model() -> void:
	var library = get_meta("library", null)
	var scene: Resource = null
	if library is AssetLibrary and (library as AssetLibrary).has("throwables"):
		scene = (library as AssetLibrary).find("throwables", "bomb")

	if scene:
		var model := ModelUtils.spawn(scene)
		if model:
			add_child(model)
			ModelUtils.fit_height(model, RADIUS * 2.4)
			return

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.22, 0.15)
	material.metallic = 0.4
	material.roughness = 0.6
	mesh.material_override = material
	add_child(mesh)

func _process(delta: float) -> void:
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		_detonate()

func _detonate() -> void:
	var here := global_position
	Sfx.play_at(self, "explosion", 1.0)
	ImpactMark.leave(get_parent(), here, Vector3.UP)
	_flash(here)

	# Only the thrower resolves damage; the host still has the last word on it.
	for node in get_tree().get_nodes_in_group("agents"):
		var body := node as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var victim_id := String(body.get("player_id"))
		if victim_id == "":
			continue
		var distance := body.global_position.distance_to(here)
		if distance > BLAST_RADIUS:
			continue
		# Full kill inside the killing radius, falling off to the edge.
		var share := 1.0 if distance <= KILLING_RADIUS else \
			1.0 - (distance - KILLING_RADIUS) / (BLAST_RADIUS - KILLING_RADIUS)
		NetGame.report_hit(victim_id, DAMAGE * share)

	queue_free()

## A short bloom of light and a shell, freed on its own timer.
func _flash(at: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.35)
	light.light_energy = 18.0
	light.omni_range = BLAST_RADIUS * 2.2
	parent.add_child(light)
	light.global_position = at + Vector3.UP * 0.6

	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BLAST_RADIUS * 0.5
	sphere.height = BLAST_RADIUS
	shell.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.66, 0.28, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.6, 0.25)
	material.emission_energy_multiplier = 3.0
	shell.material_override = material
	parent.add_child(shell)
	shell.global_position = at + Vector3.UP * 0.6

	var fade := parent.create_tween()
	fade.set_parallel(true)
	fade.tween_property(light, "light_energy", 0.0, 0.45)
	fade.tween_property(shell, "scale", Vector3.ONE * 1.8, 0.45)
	fade.tween_property(material, "albedo_color:a", 0.0, 0.45)
	fade.chain().tween_callback(_clear_flash.bind(light, shell))

func _clear_flash(light: Node, shell: Node) -> void:
	if is_instance_valid(light):
		light.queue_free()
	if is_instance_valid(shell):
		shell.queue_free()
