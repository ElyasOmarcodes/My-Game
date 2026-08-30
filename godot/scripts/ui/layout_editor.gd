class_name LayoutEditor
extends CanvasLayer
## Lets the player drag the touch buttons where they want them and set how big
## each one is.
##
## Thumb reach is personal — hand size, phone size, whether you hold it high or
## low — so a fixed HUD is wrong for most people. The buttons here are the same
## discs the match draws, moved with a finger and sized with a slider.

signal closed

const REFERENCE_HEIGHT := ControlLayout.REFERENCE_HEIGHT

var _layout: Dictionary = {}
var _discs: Dictionary = {}            # name -> Panel
var _selected := "fire"
var _dragging := ""
var _drag_offset := Vector2.ZERO
var _size_slider: HSlider
var _selection_label: Label

func _ready() -> void:
	layer = 40
	_layout = ControlLayout.load_saved()

	var background := ColorRect.new()
	background.color = Color(UiTheme.VOID.r, UiTheme.VOID.g, UiTheme.VOID.b, 0.90)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	for key in ControlLayout.ORDER:
		_discs[key] = _make_disc(key)
	_place_all()

	_build_panel()
	_select(_selected)

func _make_disc(key: String) -> Panel:
	var accent: Color = ControlLayout.ACCENTS[key]
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)

	var icon := ActionIcon.new(key, accent)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(icon)
	return node

func _place_all() -> void:
	var view := get_viewport().get_visible_rect().size
	for key in _discs:
		var rect := ControlLayout.rect_for(_layout[key], view)
		var node: Panel = _discs[key]
		node.position = rect.position
		node.size = rect.size
		_paint(key)

func _paint(key: String) -> void:
	var node: Panel = _discs[key]
	var accent: Color = ControlLayout.ACCENTS[key]
	var chosen := key == _selected
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.38 if chosen else 0.16)
	style.border_color = Color(1, 1, 1, 0.95) if chosen else \
		Color(accent.r, accent.g, accent.b, 0.7)
	style.set_border_width_all(6 if chosen else 3)
	style.set_corner_radius_all(int(node.size.x * 0.5))
	node.add_theme_stylebox_override("panel", style)

# --- the control panel --------------------------------------------------------

func _build_panel() -> void:
	var panel := UiTheme.panel()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 40
	panel.offset_top = 36
	panel.custom_minimum_size = Vector2(520, 0)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	column.add_child(UiTheme.label("CONTROL LAYOUT", UiTheme.SIZE_HEADING,
		UiTheme.TEXT_HI))
	column.add_child(UiTheme.label(
		"Drag a button to move it. Tap one to pick it, then use the slider to "
		+ "resize.", UiTheme.SIZE_SMALL, UiTheme.TEXT_MID))
	column.add_child(UiTheme.spacer(6))

	_selection_label = UiTheme.label("FIRE", UiTheme.SIZE_BODY, UiTheme.CYAN)
	column.add_child(_selection_label)

	_size_slider = UiTheme.slider(36.0, 220.0, 118.0, 1.0)
	_size_slider.value_changed.connect(_on_size_changed)
	column.add_child(_size_slider)

	column.add_child(UiTheme.spacer(6))
	column.add_child(UiTheme.button("Save layout", UiTheme.SUCCESS, _save, 72))
	column.add_child(UiTheme.button("Reset to default", UiTheme.AMBER,
		_reset, 64))
	column.add_child(UiTheme.button("Cancel", UiTheme.TEXT_MID, _cancel, 64))

func _select(key: String) -> void:
	_selected = key
	_selection_label.text = key.to_upper()
	_size_slider.set_value_no_signal(float(_layout[key]["r"]))
	for other in _discs:
		_paint(other)

func _on_size_changed(value: float) -> void:
	_layout[_selected]["r"] = value
	_place_all()

func _save() -> void:
	ControlLayout.save(_layout)
	_close()

func _reset() -> void:
	ControlLayout.reset()
	_layout = ControlLayout.load_saved()
	_place_all()
	_select(_selected)

func _cancel() -> void:
	_close()

func _close() -> void:
	closed.emit()
	queue_free()

# --- dragging -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_drag(touch.position)
		else:
			_dragging = ""
	elif event is InputEventScreenDrag and _dragging != "":
		_move_to((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_begin_drag(click.position)
			else:
				_dragging = ""
	elif event is InputEventMouseMotion and _dragging != "":
		_move_to((event as InputEventMouseMotion).position)

func _begin_drag(point: Vector2) -> void:
	for i in range(ControlLayout.ORDER.size() - 1, -1, -1):
		var key: String = ControlLayout.ORDER[i]
		var node: Panel = _discs[key]
		var centre := node.position + node.size * 0.5
		if point.distance_to(centre) <= node.size.x * 0.5:
			_dragging = key
			_drag_offset = point - centre
			_select(key)
			return

func _move_to(point: Vector2) -> void:
	var view := get_viewport().get_visible_rect().size
	var centre := point - _drag_offset
	_layout[_dragging]["x"] = clampf(centre.x / view.x, 0.03, 0.97)
	_layout[_dragging]["y"] = clampf(centre.y / view.y, 0.05, 0.97)
	_place_all()
