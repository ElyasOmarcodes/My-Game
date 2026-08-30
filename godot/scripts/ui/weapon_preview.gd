class_name WeaponPreview
extends SubViewportContainer
## A weapon turning slowly on a plinth, rendered live rather than as a picture.
##
## A name and a damage figure do not tell you what you are about to carry. This
## puts the actual model on screen — its own geometry, its own texture, the same
## one the match will hand you — in a viewport of its own so it can be dropped
## into a settings row like any other control.

const SIZE := Vector2(300, 190)

var _viewport: SubViewport
var _pivot: Node3D
var _library: AssetLibrary

func _init(library: AssetLibrary) -> void:
	_library = library
	stretch = true
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, 34, 0)
	key.light_energy = 1.5
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.6
	_viewport.add_child(fill)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.16, 0.95)
	camera.rotation_degrees = Vector3(-6, 0, 0)
	camera.fov = 42.0
	camera.current = true
	_viewport.add_child(camera)

## Swaps in a different weapon.
func show_weapon(weapon: Dictionary) -> void:
	for child in _pivot.get_children():
		child.queue_free()
	if _library == null or weapon.is_empty():
		return

	var resource: Resource = _library.find("weapons",
		String(weapon.get("model_hint", "")))
	if resource == null:
		return
	var model := ModelUtils.spawn(resource)
	if model == null:
		return
	_pivot.add_child(model)

	# Sized and centred on the pivot, so a pistol and a rifle both fill the
	# frame and both turn about themselves rather than about a corner.
	ModelUtils.fit_length_world(model, 0.62)
	model.rotation_degrees = weapon.get("model_rotation", Vector3.ZERO)
	var bounds := ModelUtils.visual_bounds(model)
	model.position -= bounds.get_center()

func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(delta * 0.8)
