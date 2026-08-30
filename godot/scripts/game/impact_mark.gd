class_name ImpactMark
extends Node3D
## The mark a bullet leaves where it lands.
##
## A shot that hits a wall and leaves nothing behind gives the player no way to
## tell where they were actually pointing. A scorch on the surface does, and it
## costs one unshaded quad.
##
## Marks are capped and recycled: an automatic weapon puts out ten a second, and
## an uncapped pile of them would be a memory leak with a fuse on it.

const MAX_MARKS := 48
const SIZE := 0.16
const LIFETIME := 22.0

static var _marks: Array[ImpactMark] = []

## Leaves a mark on the surface a shot hit, facing back along its normal.
static func leave(world: Node, at: Vector3, normal: Vector3) -> void:
	if world == null or not world.is_inside_tree():
		return

	_marks = _marks.filter(func(mark): return is_instance_valid(mark))
	while _marks.size() >= MAX_MARKS:
		var oldest: ImpactMark = _marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var mark := ImpactMark.new()
	world.add_child(mark)
	# Lifted off the surface, or it fights the wall it is drawn on.
	mark.global_position = at + normal.normalized() * 0.012
	mark._face(normal)
	_marks.append(mark)

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE) * randf_range(0.75, 1.3)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.04, 0.04, 0.85)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	add_child(mesh)

	rotate_object_local(Vector3.FORWARD, randf() * TAU)

	# They fade rather than vanish, so a wall does not blink.
	var fade := create_tween()
	fade.tween_interval(LIFETIME * 0.7)
	fade.tween_property(material, "albedo_color:a", 0.0, LIFETIME * 0.3)
	fade.tween_callback(queue_free)

## Points the quad's face back along the surface normal.
func _face(normal: Vector3) -> void:
	var direction := normal.normalized()
	# look_at cannot cope with a target directly above or below it, which is
	# exactly what a floor or a ceiling hands it.
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	look_at(global_position + direction, up)
