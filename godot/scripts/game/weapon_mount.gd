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

## Builds the mount under `agent`, arms it from `library`, and returns it.
static func attach(agent: Node3D, library: AssetLibrary, weapon: Dictionary,
		model: Node3D) -> WeaponMount:
	var mount := WeaponMount.new()
	mount.position = Vector3(0.26, 1.22, 0.30)
	agent.add_child(mount)
	mount._arm(library, weapon, model)
	return mount

func _arm(library: AssetLibrary, weapon: Dictionary, model: Node3D) -> void:
	if model != null:
		_hand = ModelUtils.hand_attachment(model)

	var scene: PackedScene = null
	if library != null and library.has("weapons"):
		scene = library.find("weapons", String(weapon.get("model_hint", "")))
		if scene == null:
			scene = library.find("weapons", "blaster")
		if scene == null:
			scene = library.random("weapons")
	if scene == null:
		_build_placeholder(weapon)
		return

	var instance := scene.instantiate() as Node3D
	if instance == null:
		_build_placeholder(weapon)
		return
	add_child(instance)

	# Two gun bodies carry five weapons, so length and colour are what tell a
	# sidearm from a marksman rifle at a glance. Length, not height: a gun is
	# longer than it is tall, and fitting by height sizes them all the same.
	ModelUtils.fit_length_world(instance, float(weapon.get("model_size", 0.5)))
	_paint(instance, weapon.get("tint", Color.WHITE))

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

## A tint over the kit's own shading, not a coat of paint over it.
func _paint(node: Node, tint: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var overlay := StandardMaterial3D.new()
			overlay.albedo_color = Color(tint.r, tint.g, tint.b, 0.24)
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(child as MeshInstance3D).material_overlay = overlay
		_paint(child, tint)

## Call once a frame from the agent that owns it.
func follow(body_yaw: float) -> void:
	if _hand != null and is_instance_valid(_hand):
		global_position = _hand.global_position
	global_rotation = Vector3(0.0, body_yaw, 0.0)
