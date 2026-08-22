class_name CityBuilder
extends Node3D
## Assembles the map from the CC0 city kit: a road grid with buildings and props
## on the blocks between, laid out from one integer seed.
##
## The host sends the seed and nothing else — every phone builds the identical
## city from the same kit, so there is no level file to download and no risk of
## two players standing in different worlds. When no kit was fetched the same
## layout is built from primitives instead, which keeps the project runnable.

const BLOCKS := 6
const BLOCK_SIZE := 22.0
const ROAD_WIDTH := 7.0
const STOREY_HEIGHT := 3.0   ## what one floor should measure in world units
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

	# One building per block, turned to face a random street.
	_place_building(centre, _rng.randi_range(0, 3) * 90.0)

	for i in 3:
		var offset := Vector3(
			_rng.randf_range(-BLOCK_SIZE * 0.42, BLOCK_SIZE * 0.42), 0.0,
			_rng.randf_range(-BLOCK_SIZE * 0.42, BLOCK_SIZE * 0.42))
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

## Kenney's town kit is modular — walls, roofs and doors, no whole houses — so a
## building is assembled from its pieces on a grid measured from the wall itself.
var _tile := 0.0
var _storey := 0.0

func _measure_module() -> void:
	if _tile > 0.0 or _library == null:
		return
	var wall: PackedScene = _library.find("buildings", "wall")
	if wall == null:
		wall = _library.random("buildings")
	var bounds := ModelUtils.measure(wall)
	_tile = maxf(bounds.size.x, bounds.size.z)
	_storey = bounds.size.y
	if _tile <= 0.01:
		_tile = 1.0
	if _storey <= 0.01:
		_storey = 1.0
	print("[city] module %.2f x %.2f" % [_tile, _storey])

func _place_building(position: Vector3, yaw: float) -> void:
	if _library == null or not _library.has("buildings"):
		var height := _rng.randf_range(3.0, 7.0)
		_primitive_block(position, Vector3(
			_rng.randf_range(4.0, 6.0), height, _rng.randf_range(4.0, 6.0)),
			Color(0.14, 0.15, 0.18), true)
		_placed += 1
		return

	_measure_module()

	var width := _rng.randi_range(2, 4)
	var depth := _rng.randi_range(2, 3)
	var storeys := _rng.randi_range(1, 3)

	var shell := Node3D.new()
	shell.position = position
	shell.rotation.y = deg_to_rad(yaw)
	add_child(shell)

	var door_tile := _rng.randi_range(0, width - 1)

	for level in storeys:
		for x in width:
			for z in depth:
				# Only the perimeter gets walls; the inside is never seen.
				if x > 0 and x < width - 1 and z > 0 and z < depth - 1:
					continue
				_place_wall_tile(shell, x, z, level, width, depth,
					level == 0 and z == 0 and x == door_tile)

	_cap_roof(shell, width, depth, storeys)

	# The kit is authored around one-unit modules; scale the finished shell so a
	# storey is one a person could walk into.
	shell.scale = Vector3.ONE * (STOREY_HEIGHT / _storey)

	# One collider for the whole footprint: far cheaper than a body per wall.
	var size := Vector3(width * _tile, storeys * _storey, depth * _tile)
	var centre := Vector3(0, size.y * 0.5, 0)
	ModelUtils.add_box_collider(shell, AABB(centre - size * 0.5, size))
	_placed += 1

func _place_wall_tile(shell: Node3D, x: int, z: int, level: int,
		width: int, depth: int, is_door: bool) -> void:
	var kind := "wall"
	if is_door:
		kind = "door"
	elif _rng.randf() < 0.45:
		kind = "window"

	var scene: PackedScene = _library.find("buildings", kind)
	if scene == null:
		scene = _library.find("buildings", "wall")
	if scene == null:
		return

	var piece := scene.instantiate() as Node3D
	if piece == null:
		return

	# Face each side outward. Which way the kit's own pieces face is a coin
	# flip between kits, but staying consistent is what matters.
	var yaw := 0.0
	if z == depth - 1:
		yaw = 180.0
	elif x == 0:
		yaw = 90.0
	elif x == width - 1:
		yaw = 270.0

	piece.position = Vector3(
		(x - (width - 1) * 0.5) * _tile,
		level * _storey,
		(z - (depth - 1) * 0.5) * _tile)
	piece.rotation.y = deg_to_rad(yaw)
	shell.add_child(piece)

func _cap_roof(shell: Node3D, width: int, depth: int, storeys: int) -> void:
	var roof: PackedScene = _library.find("buildings", "roof")
	var top := storeys * _storey

	if roof == null:
		# No roof pieces in this kit: a thin cap still closes the silhouette.
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width * _tile * 1.05, _storey * 0.18, depth * _tile * 1.05)
		mesh.mesh = box
		mesh.position = Vector3(0, top + box.size.y * 0.5, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.22, 0.13, 0.11)
		mesh.material_override = material
		shell.add_child(mesh)
		return

	for x in width:
		for z in depth:
			var piece := roof.instantiate() as Node3D
			if piece == null:
				continue
			piece.position = Vector3(
				(x - (width - 1) * 0.5) * _tile, top,
				(z - (depth - 1) * 0.5) * _tile)
			shell.add_child(piece)

func _place_prop(hint: String, position: Vector3, yaw: float) -> void:
	var scene: PackedScene = null
	if _library and _library.has("props"):
		scene = _library.find("props", hint)
		if scene == null:
			scene = _library.random("props")
	if scene:
		_instance(scene, position, yaw, false, 0.0, 2.2 if hint == "tree" else 0.9)
	elif hint == "tree":
		_primitive_block(position, Vector3(0.3, 2.4, 0.3), Color(0.10, 0.08, 0.06), false)
		_primitive_block(position + Vector3(0, 2.0, 0), Vector3(1.8, 1.4, 1.8),
			Color(0.09, 0.17, 0.10), false)
	elif hint == "streetlight":
		_primitive_block(position + Vector3(0, 1.8, 0), Vector3(0.12, 3.6, 0.12),
			Color(0.13, 0.14, 0.17), false)
	_placed += 1

## Instances a kit piece and, when it should block movement, wraps it in a body
## sized to its own bounds — the kits ship visuals only, no collision.
func _instance(scene: PackedScene, position: Vector3, yaw: float, solid: bool,
		fit_width := 0.0, fit_height := 0.0) -> void:
	var node: Node = scene.instantiate()
	if not (node is Node3D):
		return

	var model := node as Node3D
	model.position = position
	model.rotation.y = deg_to_rad(yaw)
	add_child(model)

	var bounds := _visual_bounds(model)

	# Kits are authored at wildly different scales, so nothing is placed on faith.
	if fit_height > 0.0:
		ModelUtils.fit_height(model, fit_height)
	elif fit_width > 0.0 and bounds.size.x > 0.001:
		var largest := maxf(bounds.size.x, bounds.size.z)
		model.scale = Vector3.ONE * clampf(fit_width / largest, 0.5, 3.5)

	if not solid:
		return
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
