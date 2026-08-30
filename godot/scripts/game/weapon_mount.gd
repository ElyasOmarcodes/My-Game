class_name WeaponMount
extends Node3D
## Holds an agent's weapon: at the hand, pointing where the agent faces.
##
## Both the local player and every remote agent need exactly this, and when each
## had its own copy the remote ones kept carrying their rifles sideways after the
## local one was fixed. There is one copy now.
##
## The weapon is not parented to the hand bone. A bone carries the animation's
## rotation with it, and an idle arm hangs down, so a gun parented to it points
## at the floor across the agent's hip. This follows the bone's position and
## takes its heading from the body instead — right in every pose, without an
## aiming animation the rig does not have.

var _hand: BoneAttachment3D
var muzzle: Marker3D            ## the barrel tip — where a shot comes from

## Builds the mount under `agent`, arms it from `library`, and returns it.
static func attach(agent: Node3D, library: AssetLibrary, weapon: Dictionary,
		model: Node3D) -> WeaponMount:
	var mount := WeaponMount.new()
	mount.position = Vector3(0.26, 1.15, 0.22)
	agent.add_child(mount)
	mount._arm(library, weapon, model)
	return mount

## The other weapon, slung across the agent's back. It is never fired from
## there, so it needs no muzzle and no hand to follow.
static func sling(agent: Node3D, library: AssetLibrary,
		weapon: Dictionary) -> WeaponMount:
	if weapon.is_empty():
		return null
	var mount := WeaponMount.new()
	mount.position = Vector3(-0.06, 1.28, 0.20)
	mount.rotation_degrees = Vector3(0, 0, 52)
	agent.add_child(mount)
	mount._arm(library, weapon, null)
	mount.set_process(false)
	return mount

## Where the shot leaves the gun, in world space.
func barrel() -> Vector3:
	return muzzle.global_position if muzzle != null else global_position

func _arm(library: AssetLibrary, weapon: Dictionary, model: Node3D) -> void:
	if model != null:
		_hand = ModelUtils.hand_attachment(model)

	var scene: Resource = null
	if library != null and library.has("weapons"):
		scene = library.find("weapons", String(weapon.get("model_hint", "")))
		if scene == null:
			scene = library.find("weapons", "blaster")
		if scene == null:
			scene = library.random("weapons")
	if scene == null:
		_build_placeholder(weapon)
		return

	var instance := ModelUtils.spawn(scene)
	if instance == null:
		_build_placeholder(weapon)
		return
	add_child(instance)

	# Two gun bodies carry five weapons, so length and colour are what tell a
	# sidearm from a marksman rifle at a glance. Length, not height: a gun is
	# longer than it is tall, and fitting by height sizes them all the same.
	ModelUtils.fit_length_world(instance, float(weapon.get("model_size", 0.5)))
	_orient(instance, weapon)
	_paint_if_untextured(instance, weapon.get("tint", Color.WHITE))
	_place_muzzle(instance)

func _build_placeholder(weapon: Dictionary) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.12, float(weapon.get("model_size", 0.5)))
	mesh.mesh = box
	mesh.position.z = -box.size.z * 0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = weapon.get("tint", Color(0.2, 0.2, 0.22))
	mesh.material_override = material
	add_child(mesh)

## Every model arrives pointing a different way — one pack is authored down +X,
## another down -Z, and an .obj from a 3ds Max exporter is usually Z-up. The
## correction is per weapon, in the catalogue, rather than guessed here.
func _orient(instance: Node3D, weapon: Dictionary) -> void:
	if weapon.has("model_rotation"):
		instance.rotation_degrees = weapon["model_rotation"]
	else:
		# Nothing stated: lay the model's longest side down -Z, which is where
		# the agent is looking. The thirteen-weapon pack has no two guns facing
		# the same way, and one of them was carried pointing at the sky.
		var bounds := ModelUtils.visual_bounds(instance)
		if bounds.size.x > bounds.size.z and bounds.size.x > bounds.size.y:
			instance.rotation_degrees = Vector3(0, 90, 0)
		elif bounds.size.y > bounds.size.z and bounds.size.y > bounds.size.x:
			instance.rotation_degrees = Vector3(90, 0, 0)
	instance.position = weapon.get("model_offset", Vector3.ZERO)

## A tint only where there is nothing to tint over. The supplied guns carry
## their own textures and painting over those would throw away the whole point
## of them; the untextured kit models still need a colour of their own.
func _paint_if_untextured(node: Node, tint: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if not _has_texture(mesh_instance):
				var material := StandardMaterial3D.new()
				material.albedo_color = tint
				material.metallic = 0.55
				material.metallic_specular = 0.6
				material.roughness = 0.38
				mesh_instance.material_override = material
		_paint_if_untextured(child, tint)

func _has_texture(mesh_instance: MeshInstance3D) -> bool:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return false
	for i in mesh.get_surface_count():
		var material := mesh_instance.get_active_material(i)
		if material is BaseMaterial3D \
				and (material as BaseMaterial3D).albedo_texture != null:
			return true
	return false

## The barrel tip, taken from the model's own bounds: the far end of its longest
## side. A shot that starts at the camera crosses the player from behind, which
## is exactly what the tracer looked like it was doing.
func _place_muzzle(instance: Node3D) -> void:
	muzzle = Marker3D.new()
	add_child(muzzle)
	var bounds := ModelUtils.visual_bounds(instance)
	if bounds.size == Vector3.ZERO:
		muzzle.position = Vector3(0, 0, -0.4)
		return
	var centre := bounds.get_center()
	if bounds.size.z >= bounds.size.x:
		muzzle.position = Vector3(centre.x, centre.y, bounds.position.z)
	else:
		muzzle.position = Vector3(bounds.position.x + bounds.size.x, centre.y, centre.z)

## Call once a frame from the agent that owns it.
func follow(body_yaw: float) -> void:
	if _hand != null and is_instance_valid(_hand):
		global_position = _hand.global_position
	global_rotation = Vector3(0.0, body_yaw, 0.0)
