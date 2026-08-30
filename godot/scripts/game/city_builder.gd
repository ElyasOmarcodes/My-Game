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
const BLOCK_SIZE := 24.0
const ROAD_WIDTH := 8.0
const STOREY_HEIGHT := 3.2   ## what one floor should measure in world units
const TILE := BLOCK_SIZE + ROAD_WIDTH

var spawns: Array[Transform3D] = []

var _rng := RandomNumberGenerator.new()
var _library: AssetLibrary
var _placed := 0

signal spawns_ready

func build(library: AssetLibrary, map_seed: int) -> void:
	_library = library
	_rng.seed = map_seed
	spawns.clear()

	# A map somebody drew beats one a loop generates, so it wins when present.
	if _build_supplied_map():
		_ring_spawns()
		print("[city] supplied map, %d spawns" % spawns.size())
		return

	_build_ground()
	_build_roads()
	for gx in BLOCKS:
		for gz in BLOCKS:
			_build_block(gx, gz)
	_build_spawns()

	print("[city] %d pieces placed, %d spawns" % [_placed, spawns.size()])

## How wide the playable area is, whichever way it was built.
func span() -> float:
	if _from_map:
		return maxf(_map_bounds.size.x, _map_bounds.size.z)
	return BLOCKS * BLOCK_SIZE + (BLOCKS + 1) * ROAD_WIDTH

## The middle of the playable area — a supplied map need not sit on the origin.
func centre() -> Vector3:
	if _from_map:
		return Vector3(_map_bounds.get_center().x, 0.0, _map_bounds.get_center().z)
	return Vector3.ZERO

# --- a map that came ready-made -----------------------------------------------

const MAP_TARGET_SPAN := 320.0   ## what a map gets resized to when it arrives in
const MAP_MIN_SPAN := 45.0       ## some unit other than metres
const MAP_MAX_SPAN := 900.0

var _map_bounds := AABB()
var _from_map := false
var _spawns_resolved := false

func _build_supplied_map() -> bool:
	if _library == null or not _library.has("map"):
		return false
	var scene := _library.pick("map", 0)
	if scene == null:
		return false

	var level := scene.instantiate() as Node3D
	if level == null:
		push_warning("[map] the supplied map is not a 3D scene")
		return false
	add_child(level)

	var bounds := ModelUtils.visual_bounds(level)
	var measured := maxf(bounds.size.x, bounds.size.z)
	print("[map] loaded, bounds %.1f x %.1f x %.1f" % [
		bounds.size.x, bounds.size.y, bounds.size.z])

	if measured <= 0.001:
		push_warning("[map] the supplied map has no visible geometry")
		level.queue_free()
		return false

	# Authored in centimetres, or in some engine's own unit: rescale rather than
	# drop the player into a map the size of a shoebox or a continent.
	if measured < MAP_MIN_SPAN or measured > MAP_MAX_SPAN:
		var factor := MAP_TARGET_SPAN / measured
		level.scale = Vector3.ONE * factor
		bounds = AABB(bounds.position * factor, bounds.size * factor)
		print("[map] rescaled by %.4f to a %.0f m span" % [factor, MAP_TARGET_SPAN])

	# Rest it on y = 0 so the fallback ground plane is never the thing you land on.
	level.position.y -= bounds.position.y
	bounds.position.y = 0.0
	_map_bounds = bounds
	_from_map = true

	_add_map_collision(level)
	_placed += 1
	return true

## The kits and most exported levels ship visuals only, so the walkable surface
## has to be built from the meshes themselves.
func _add_map_collision(level: Node3D) -> void:
	var surfaces := 0
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.create_trimesh_collision()
		surfaces += 1
	print("[map] %d collision surfaces" % surfaces)

## Provisional spawn points around the middle of the map. They are refined onto
## the actual floor on the first physics frame, once the trimesh bodies exist.
func _ring_spawns() -> void:
	var middle := centre()
	var radius := span() * 0.3
	for i in 8:
		var angle := TAU * i / 8.0
		var position := middle + Vector3(cos(angle) * radius,
			_map_bounds.size.y + 3.0, sin(angle) * radius)
		var basis := Basis(Vector3.UP, angle + PI)
		spawns.append(Transform3D(basis, position))

func _physics_process(_delta: float) -> void:
	if _spawns_resolved or not _from_map:
		set_physics_process(false)
		return
	_spawns_resolved = true
	set_physics_process(false)
	_drop_spawns_to_floor()
	spawns_ready.emit()

func _drop_spawns_to_floor() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	for i in spawns.size():
		var from: Vector3 = spawns[i].origin
		var query := PhysicsRayQueryParameters3D.create(
			from, from + Vector3.DOWN * (_map_bounds.size.y + 60.0))
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var floor_point: Vector3 = hit["position"]
		spawns[i] = Transform3D(spawns[i].basis, floor_point + Vector3(0, 1.2, 0))
	print("[map] spawns dropped onto the floor")

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
	material.albedo_color = Color(0.47, 0.43, 0.35)
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
	material.albedo_color = Color(0.20, 0.20, 0.21)
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

	# Two houses to a block: one left every lot looking abandoned from the air.
	var quarter := BLOCK_SIZE * 0.24
	_place_building(centre + Vector3(-quarter, 0, -quarter),
		_rng.randi_range(0, 3) * 90.0)
	if _rng.randf() < 0.75:
		_place_building(centre + Vector3(quarter, 0, quarter),
			_rng.randi_range(0, 3) * 90.0)

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
	material.albedo_color = Color(0.30, 0.42, 0.22)
	mesh.material_override = material
	add_child(mesh)

	for i in 8:
		var offset := Vector3(
			_rng.randf_range(-BLOCK_SIZE * 0.4, BLOCK_SIZE * 0.4), 0.0,
			_rng.randf_range(-BLOCK_SIZE * 0.4, BLOCK_SIZE * 0.4))
		_place_prop("tree", centre + offset, _rng.randf() * 360.0)

# --- placement ----------------------------------------------------------------

## Kenney's town kit is modular — walls, roofs and doors, no whole houses — so a
## house is assembled from those pieces on a grid whose cell size comes from the
## wall module itself.
var _cell := 0.0        ## world size of one module cell
var _face_yaw := 0.0    ## turn that makes a wall module face -Z
var _measured := false

func _measure_module() -> void:
	if _measured:
		return
	_measured = true
	_cell = STOREY_HEIGHT

	var wall: PackedScene = _wall_scene("wall")
	if wall == null:
		return
	var bounds := ModelUtils.measure(wall)
	var width := maxf(bounds.size.x, bounds.size.z)
	if width <= 0.001 or bounds.size.y <= 0.001:
		return

	# A wall module is one storey tall by construction, so sizing the cell from
	# the module's own aspect ratio makes a storey a storey however it is drawn.
	_cell = clampf(STOREY_HEIGHT * width / bounds.size.y, 1.0, 8.0)

	# Which way it faces is the kit's business, not ours: this one is thin along
	# X, so it needs a quarter turn before its face points down -Z.
	_face_yaw = 90.0 if bounds.size.x < bounds.size.z else 0.0

	print("[city] wall %.2f x %.2f x %.2f -> cell %.2f, face yaw %.0f" % [
		bounds.size.x, bounds.size.y, bounds.size.z, _cell, _face_yaw])
	if _library and _library.has("roofs"):
		for hint in ["roofFlat", "roofGable", "roof"]:
			var roof: PackedScene = _library.find("roofs", hint.to_lower())
			if roof:
				var roof_bounds := ModelUtils.measure(roof)
				print("[city] %s %.2f x %.2f x %.2f" % [hint,
					roof_bounds.size.x, roof_bounds.size.y, roof_bounds.size.z])

## Wall modules. The kit ships a stone family and a wood one; a building picks
## one and keeps to it, so a house does not look like a salvage yard.
func _wall_scene(hint: String) -> PackedScene:
	if _library == null or not _library.has("walls"):
		return null
	var scene: PackedScene = _library.find("walls", hint)
	if scene == null:
		scene = _library.find("walls", "wall")
	return scene

func _place_building(position: Vector3, yaw: float) -> void:
	_measure_module()

	if _library == null or not _library.has("walls"):
		var height := _rng.randf_range(4.0, 9.0)
		_primitive_block(position, Vector3(
			_rng.randf_range(6.0, 9.0), height, _rng.randf_range(6.0, 9.0)),
			Color(0.34, 0.32, 0.30), true)
		_placed += 1
		return

	var width := _rng.randi_range(2, 3)
	var depth := _rng.randi_range(2, 3)
	var storeys := _rng.randi_range(1, 3)
	var family := "wallWood" if _rng.randf() < 0.45 else "wall"

	var shell := Node3D.new()
	shell.position = position
	shell.rotation.y = deg_to_rad(yaw)
	add_child(shell)

	var half_x := width * _cell * 0.5
	var half_z := depth * _cell * 0.5
	var door_at := _rng.randi_range(0, width - 1)

	for level in storeys:
		var y := level * STOREY_HEIGHT
		# Walls sit on the four edge planes of the footprint, not in its cells:
		# on the cells the corners never meet and the house reads as loose panels.
		for x in width:
			var along := (x - (width - 1) * 0.5) * _cell
			_wall(shell, family, Vector3(along, y, -half_z), 0.0,
				level == 0 and x == door_at)
			_wall(shell, family, Vector3(along, y, half_z), 180.0, false)
		for z in depth:
			var along := (z - (depth - 1) * 0.5) * _cell
			_wall(shell, family, Vector3(-half_x, y, along), 90.0, false)
			_wall(shell, family, Vector3(half_x, y, along), 270.0, false)

	_cap_roof(shell, width, depth, storeys)

	# One collider for the whole footprint: far cheaper than a body per wall.
	var size := Vector3(width * _cell, storeys * STOREY_HEIGHT, depth * _cell)
	ModelUtils.add_box_collider(shell, AABB(
		Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	_placed += 1

func _wall(shell: Node3D, family: String, at: Vector3, yaw: float,
		is_door: bool) -> void:
	var hint := family
	if is_door:
		hint = family + "Door"
	elif _rng.randf() < 0.4:
		hint = family + "Window"

	var piece := ModelUtils.module(_wall_scene(hint.to_lower()), _cell)
	if piece == null:
		return
	piece.position = at
	piece.rotation.y = deg_to_rad(yaw + _face_yaw)
	shell.add_child(piece)

func _cap_roof(shell: Node3D, width: int, depth: int, storeys: int) -> void:
	var top := storeys * STOREY_HEIGHT
	var roof: PackedScene = null
	if _library and _library.has("roofs"):
		# A flat cap tiles across any footprint; a gable only reads right on a
		# roof one module deep, and this town has none.
		roof = _library.find("roofs", "roofflat")
		if roof == null:
			roof = _library.find("roofs", "roof")

	if roof == null:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width * _cell * 1.06, 0.35, depth * _cell * 1.06)
		mesh.mesh = box
		mesh.position = Vector3(0, top + box.size.y * 0.5, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.35, 0.20, 0.16)
		mesh.material_override = material
		shell.add_child(mesh)
		return

	for x in width:
		for z in depth:
			var piece := ModelUtils.module(roof, _cell)
			if piece == null:
				continue
			piece.position = Vector3(
				(x - (width - 1) * 0.5) * _cell, top,
				(z - (depth - 1) * 0.5) * _cell)
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
