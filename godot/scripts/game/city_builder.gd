class_name CityBuilder
extends Node3D
## Assembles the map from the CC0 city kit: a road grid with buildings and props
## on the blocks between, laid out from one integer seed.
##
## The host sends the seed and nothing else — every phone builds the identical
## city from the same kit, so there is no level file to download and no risk of
## two players standing in different worlds. When no kit was fetched the same
## layout is built from primitives instead, which keeps the project runnable.

const BLOCKS := 5
const BLOCK_SIZE := 36.0
const ROAD_WIDTH := 12.0
const TILE := BLOCK_SIZE + ROAD_WIDTH

var spawns: Array[Transform3D] = []

var _rng := RandomNumberGenerator.new()
var _library: AssetLibrary
var _placed := 0

func build(library: AssetLibrary, map_seed: int) -> void:
	_library = library
	_rng.seed = map_seed
	spawns.clear()

	_build_ground()
	_build_roads()
	for gx in BLOCKS:
		for gz in BLOCKS:
			_build_block(gx, gz)
	_build_spawns()

	print("[city] %d pieces placed, %d spawns" % [_placed, spawns.size()])

func span() -> float:
	return BLOCKS * BLOCK_SIZE + (BLOCKS + 1) * ROAD_WIDTH

# --- ground and roads ---------------------------------------------------------

func _build_ground() -> void:
	var size := span() + 40.0

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	body.collision_layer = 1
	add_child(body)

	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(size, 1.0, size)
	mesh.mesh = plane
	mesh.position.y = -0.5

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.10, 0.12)
	material.roughness = 0.95
	mesh.material_override = material
	add_child(mesh)

func _build_roads() -> void:
	var half := span() * 0.5
	for i in BLOCKS + 1:
		var offset := -half + ROAD_WIDTH * 0.5 + i * TILE
		_road_strip(Vector3(offset, 0.02, 0), Vector3(ROAD_WIDTH, 0.04, span()))
		_road_strip(Vector3(0, 0.02, offset), Vector3(span(), 0.04, ROAD_WIDTH))

		for j in BLOCKS:
			var along := -half + ROAD_WIDTH + j * TILE + BLOCK_SIZE * 0.5
			_place_prop("streetlight", Vector3(offset - ROAD_WIDTH * 0.42, 0, along), 90.0)
			_place_prop("streetlight", Vector3(along, 0, offset + ROAD_WIDTH * 0.42), 0.0)

func _road_strip(centre: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = centre

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.06, 0.072)
	material.roughness = 0.85
	mesh.material_override = material
	add_child(mesh)

# --- blocks -------------------------------------------------------------------

func _block_centre(gx: int, gz: int) -> Vector3:
	var half := span() * 0.5
	return Vector3(
		-half + ROAD_WIDTH + BLOCK_SIZE * 0.5 + gx * TILE, 0.0,
		-half + ROAD_WIDTH + BLOCK_SIZE * 0.5 + gz * TILE)

func _build_block(gx: int, gz: int) -> void:
	var centre := _block_centre(gx, gz)

	# A park breaks up the grid and gives the middle of the map an open fight.
	var middle := (BLOCKS - 1) * 0.5
	if absf(gx - middle) < 0.6 and absf(gz - middle) < 0.6:
		_build_park(centre)
		return

	var lots := 2
	var lot_size := BLOCK_SIZE / lots
	for lx in lots:
		for lz in lots:
			var position := centre + Vector3(
				-BLOCK_SIZE * 0.5 + lot_size * (lx + 0.5), 0.0,
				-BLOCK_SIZE * 0.5 + lot_size * (lz + 0.5))
			_place_building(position, _rng.randf() * 360.0)

	for i in 3:
		var offset := Vector3(
			_rng.randf_range(-BLOCK_SIZE * 0.45, BLOCK_SIZE * 0.45), 0.0,
			_rng.randf_range(-BLOCK_SIZE * 0.45, BLOCK_SIZE * 0.45))
		_place_prop(["box", "trash", "bench", "barrier"][_rng.randi() % 4],
			centre + offset, _rng.randf() * 360.0)

func _build_park(centre: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BLOCK_SIZE, 0.2, BLOCK_SIZE)
	mesh.mesh = box
	mesh.position = centre + Vector3(0, 0.1, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.16, 0.10)
	mesh.material_override = material
	add_child(mesh)

	for i in 8:
		var offset := Vector3(
			_rng.randf_range(-BLOCK_SIZE * 0.4, BLOCK_SIZE * 0.4), 0.0,
			_rng.randf_range(-BLOCK_SIZE * 0.4, BLOCK_SIZE * 0.4))
		_place_prop("tree", centre + offset, _rng.randf() * 360.0)

# --- placement ----------------------------------------------------------------

func _place_building(position: Vector3, yaw: float) -> void:
	var scene: PackedScene = _library.random("buildings") if _library else null
	if scene:
		_instance(scene, position, yaw, true)
	else:
		var height := _rng.randf_range(6.0, 22.0)
		_primitive_block(position, Vector3(
			_rng.randf_range(8.0, 14.0), height, _rng.randf_range(8.0, 14.0)),
			Color(0.14, 0.15, 0.18), true)
	_placed += 1

func _place_prop(hint: String, position: Vector3, yaw: float) -> void:
	var scene: PackedScene = null
	if _library and _library.has("props"):
		scene = _library.find("props", hint)
		if scene == null:
			scene = _library.random("props")
	if scene:
		_instance(scene, position, yaw, false)
	elif hint == "tree":
		_primitive_block(position, Vector3(0.5, 4.0, 0.5), Color(0.10, 0.08, 0.06), false)
		_primitive_block(position + Vector3(0, 3.4, 0), Vector3(3.0, 2.4, 3.0),
			Color(0.09, 0.17, 0.10), false)
	elif hint == "streetlight":
		_primitive_block(position + Vector3(0, 3.5, 0), Vector3(0.2, 7.0, 0.2),
			Color(0.13, 0.14, 0.17), false)
	_placed += 1

## Instances a kit piece and, when it should block movement, wraps it in a body
## sized to its own bounds — the kits ship visuals only, no collision.
func _instance(scene: PackedScene, position: Vector3, yaw: float, solid: bool) -> void:
	var node := scene.instantiate()
	if not (node is Node3D):
		return

	var model := node as Node3D
	model.position = position
	model.rotation.y = deg_to_rad(yaw)
	add_child(model)

	if not solid:
		return

	var bounds := _visual_bounds(model)
	if bounds.size == Vector3.ZERO:
		return

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	model.add_child(body)

func _visual_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local := mesh_instance.mesh.get_aabb()
		if first:
			bounds = local
			first = false
		else:
			bounds = bounds.merge(local)
	return bounds

func _primitive_block(position: Vector3, size: Vector3, colour: Color, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position + Vector3(0, size.y * 0.5, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	mesh.material_override = material
	add_child(mesh)

	if not solid:
		return

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = size
	shape.shape = collision
	body.add_child(shape)
	body.position = mesh.position
	add_child(body)

# --- spawns -------------------------------------------------------------------

func _build_spawns() -> void:
	var half := span() * 0.5
	for gx in BLOCKS:
		for gz in BLOCKS:
			if (gx + gz) % 2 != 0:
				continue
			var position := Vector3(
				-half + ROAD_WIDTH * 0.5 + gx * TILE, 1.2,
				-half + ROAD_WIDTH * 0.5 + gz * TILE)
			var basis := Basis(Vector3.UP, deg_to_rad(_rng.randi_range(0, 3) * 90))
			spawns.append(Transform3D(basis, position))

func spawn_for(index: int, team: int) -> Transform3D:
	if spawns.is_empty():
		return Transform3D(Basis(), Vector3(0, 2, 0))
	var offset := 0 if team == Session.Team.ALPHA else spawns.size() / 2
	return spawns[(index + offset) % spawns.size()]
