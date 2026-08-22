class_name ModelUtils
extends RefCounted
## Measuring and fitting for imported kit models.
##
## Every CC0 kit is authored at its own scale — a KayKit character stands several
## units tall while a Kenney town module is one unit wide — so nothing can be
## placed on faith. Everything here works from the model's own measured bounds.

## World-space bounds of every mesh under `node`, in the node's local space.
static func visual_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local := mesh_instance.mesh.get_aabb()
		# Account for any transform between the model root and the mesh.
		var offset := node.global_transform.affine_inverse() * mesh_instance.global_transform
		local = offset * local
		if first:
			bounds = local
			first = false
		else:
			bounds = bounds.merge(local)
	return bounds

## Scales the model so it stands `target` units tall. Returns the factor used.
static func fit_height(node: Node3D, target: float, minimum := 0.05, maximum := 40.0) -> float:
	var bounds := visual_bounds(node)
	if bounds.size.y <= 0.0001:
		return 1.0
	var factor := clampf(target / bounds.size.y, minimum, maximum)
	node.scale = Vector3.ONE * factor
	return factor

## Scales the model so its widest horizontal side is `target` units.
static func fit_width(node: Node3D, target: float, minimum := 0.05, maximum := 40.0) -> float:
	var bounds := visual_bounds(node)
	var widest := maxf(bounds.size.x, bounds.size.z)
	if widest <= 0.0001:
		return 1.0
	var factor := clampf(target / widest, minimum, maximum)
	node.scale = Vector3.ONE * factor
	return factor

## Drops the model so its lowest point rests on y = `ground`.
static func rest_on_ground(node: Node3D, ground := 0.0) -> void:
	var bounds := visual_bounds(node)
	node.position.y = ground - bounds.position.y * node.scale.y

## Measures a scene without adding it to the tree.
static func measure(scene: PackedScene) -> AABB:
	if scene == null:
		return AABB()
	var probe := scene.instantiate() as Node3D
	if probe == null:
		return AABB()
	var bounds := _bounds_without_tree(probe)
	probe.free()
	return bounds

static func _bounds_without_tree(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
		if first:
			bounds = local
			first = false
		else:
			bounds = bounds.merge(local)
	return bounds

## A box collider matching the model's own bounds, added under it.
static func add_box_collider(model: Node3D, bounds: AABB, layer := 1) -> void:
	if bounds.size == Vector3.ZERO:
		return
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	model.add_child(body)
