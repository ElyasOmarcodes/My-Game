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
	# A .obj imports as a bare Mesh and is spawned as a single MeshInstance3D,
	# so the node itself is the geometry — searching only its children found
	# nothing, measured zero, and left those models at whatever scale the artist
	# saved them at. One of them filled the sky.
	for child in _mesh_nodes(node):
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
static func measure(scene: Resource) -> AABB:
	var probe := spawn(scene)
	if probe == null:
		return AABB()
	var bounds := _bounds_without_tree(probe)
	probe.free()
	return bounds

## Bounds in `node`'s own local space, without needing it in the tree.
##
## A glTF import nests its meshes under one or more transform nodes, so the
## chain from the root down to each mesh has to be composed — reading only the
## mesh's own transform is what made a one-metre wall measure as three.
static func _bounds_without_tree(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in _mesh_nodes(node):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local: AABB = _chain(node, mesh_instance) * mesh_instance.mesh.get_aabb()
		if first:
			bounds = local
			first = false
		else:
			bounds = bounds.merge(local)
	return bounds

## Every mesh under `node`, including `node` itself when it is one.
static func _mesh_nodes(node: Node3D) -> Array:
	var found: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		found.append(node)
	return found

## The transform of `leaf` expressed in `root`'s space.
static func _chain(root: Node3D, leaf: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var walker: Node = leaf
	while walker != null and walker != root:
		if walker is Node3D:
			transform = (walker as Node3D).transform * transform
		walker = walker.get_parent()
	return transform

## Instances any model resource as a node.
##
## The kits arrive in three shapes: a .glb or .fbx imports as a PackedScene, but
## a .obj imports as a bare Mesh with no node around it. Every caller wants a
## Node3D, so the difference is settled once, here, rather than at each of the
## seven places that load a model.
static func spawn(resource: Resource) -> Node3D:
	if resource == null:
		return null
	if resource is PackedScene:
		return (resource as PackedScene).instantiate() as Node3D
	if resource is Mesh:
		var instance := MeshInstance3D.new()
		instance.mesh = resource as Mesh
		return instance
	push_warning("[models] %s is not a model" % resource.get_class())
	return null

## Instances a modular kit piece into a pivot that occupies exactly one grid
## cell: scaled so the piece is `tile` wide, centred on X and Z, resting on y=0.
##
## Kenney's modules are authored with their own origins and their own idea of a
## unit, so placing them on a grid by position alone leaves either gaps or
## overlaps. Normalising each piece into a cell removes the guesswork.
static func module(scene: Resource, tile: float) -> Node3D:
	var piece := spawn(scene)
	if piece == null:
		return null

	var pivot := Node3D.new()
	pivot.add_child(piece)

	# By the widest horizontal side, not by X: the town kit's wall lies in the YZ
	# plane (0.10 x 1.00 x 1.00), so fitting X to the cell scaled it fifteenfold
	# and turned a cottage into a tower block.
	var bounds := _bounds_without_tree(piece)
	var widest := maxf(bounds.size.x, bounds.size.z)
	if widest > 0.0001:
		var factor := tile / widest
		piece.scale = Vector3.ONE * factor
		bounds = AABB(bounds.position * factor, bounds.size * factor)

	var centre := bounds.get_center()
	piece.position = Vector3(-centre.x, -bounds.position.y, -centre.z)
	return pivot

## An attachment point on the model's hand bone, or null when it has no
## skeleton. KayKit rigs name theirs `handslot.r`; other rigs use `Hand.R` or
## `mixamorig:RightHand`, so the search is on substrings rather than one name.
static func hand_attachment(model: Node3D, right := true) -> BoneAttachment3D:
	for node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		if skeleton == null:
			continue
		var chosen := -1
		var chosen_length := 9999
		for i in skeleton.get_bone_count():
			var bone := skeleton.get_bone_name(i).to_lower()
			if bone.find("hand") == -1:
				continue
			var is_right := bone.find("right") != -1 or bone.ends_with("r") \
				or bone.find(".r") != -1 or bone.find("_r") != -1
			if is_right != right:
				continue
			# A Mixamo rig names every finger joint RightHandThumb1 and so on, so
			# the shortest name is the wrist — the one a weapon belongs in. A rig
			# that offers an explicit slot wins outright.
			if bone.find("slot") != -1:
				chosen = i
				break
			if bone.length() < chosen_length:
				chosen = i
				chosen_length = bone.length()
		if chosen < 0:
			continue
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = skeleton.get_bone_name(chosen)
		return attachment
	return null

## Scales a node so its longest side measures `target` world units, undoing the
## scale it inherited. A gun is longer than it is tall, so fitting it by height
## makes a rifle and a pistol come out the same size.
static func fit_length_world(node: Node3D, target: float) -> void:
	var bounds := _bounds_without_tree(node)
	var longest := maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
	if longest <= 0.0001:
		return
	var inherited := 1.0
	var parent := node.get_parent_node_3d()
	if parent != null:
		inherited = maxf(parent.global_transform.basis.get_scale().y, 0.0001)
	node.scale = Vector3.ONE * (target / longest / inherited)

## Scales a node so it measures `target` in world units, undoing whatever scale
## it inherited from its parents. Needs the node to be inside the tree.
static func fit_height_world(node: Node3D, target: float) -> void:
	var inherited := 1.0
	var parent := node.get_parent_node_3d()
	if parent != null:
		inherited = maxf(parent.global_transform.basis.get_scale().y, 0.0001)
	fit_height(node, target / inherited)

## Gives an untextured model a colour of its own.
##
## The supplied SWAT body has no textures in it at all, so it imports as default
## grey. Anything that does carry a texture is left alone — repainting those
## would throw away the reason for having them.
static func clothe(model: Node3D, colour: Color) -> void:
	for node in _mesh_nodes(model):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var textured := false
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i)
			if material is BaseMaterial3D \
					and (material as BaseMaterial3D).albedo_texture != null:
				textured = true
				break
		if textured:
			continue
		var kit := StandardMaterial3D.new()
		kit.albedo_color = colour
		kit.roughness = 0.78
		kit.metallic = 0.06
		mesh_instance.material_override = kit

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
