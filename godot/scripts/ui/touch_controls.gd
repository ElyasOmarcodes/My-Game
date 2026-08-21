class_name TouchControls
extends Control
## Twin-stick touch layer: the left half of the screen is a floating move stick,
## the right half aims, and the action buttons sit on top of it.
##
## Built in code rather than as a scene so the layout and the hit-testing come
## from one place — the commonest way a touch HUD goes wrong is the drawn button
## drifting away from the region that actually responds.

signal fire_pressed(down: bool)
signal jump_pressed
signal reload_pressed

const STICK_RADIUS := 120.0
const BUTTON_FIRE := 92.0
const BUTTON_SMALL := 54.0

var move := Vector2.ZERO
var look := Vector2.ZERO
var sprinting := false

var _move_touch := -1
var _look_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_handle := Vector2.ZERO

var _stick_base: Control
var _stick_knob: Control
var _buttons: Dictionary = {}          # name -> Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stick_base = _circle(STICK_RADIUS, Color(0.33, 0.40, 0.49, 0.10), Color(0.33, 0.40, 0.49, 0.28))
	_stick_base.visible = false
	_stick_knob = _circle(STICK_RADIUS * 0.42, Color(0.23, 0.91, 1.0, 0.32), Color(0.23, 0.91, 1.0, 0.55))
	_stick_base.add_child(_stick_knob)
	_stick_knob.position = Vector2(STICK_RADIUS * 0.58, STICK_RADIUS * 0.58)

	_buttons["fire"] = _button("FIRE", BUTTON_FIRE, Color(1.0, 0.30, 0.37, 1.0))
	_buttons["jump"] = _button("JUMP", BUTTON_SMALL, Color(0.23, 0.91, 1.0, 1.0))
	_buttons["reload"] = _button("RELOAD", BUTTON_SMALL, Color(1.0, 0.70, 0.23, 1.0))
	_buttons["sprint"] = _button("RUN", BUTTON_SMALL, Color(0.30, 1.0, 0.65, 1.0))

	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var view := get_viewport_rect().size
	_place(_buttons["fire"], Vector2(view.x - 130, view.y - 130), BUTTON_FIRE)
	_place(_buttons["jump"], Vector2(view.x - 268, view.y - 108), BUTTON_SMALL)
	_place(_buttons["reload"], Vector2(view.x - 250, view.y - 236), BUTTON_SMALL)
	_place(_buttons["sprint"], Vector2(view.x - 118, view.y - 288), BUTTON_SMALL)

func _place(node: Control, centre: Vector2, radius: float) -> void:
	node.position = centre - Vector2(radius, radius)
	node.size = Vector2(radius * 2, radius * 2)

func _circle(radius: float, fill: Color, border: Color) -> Control:
	var node := Panel.new()
	node.size = Vector2(radius * 2, radius * 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	node.add_theme_stylebox_override("panel", style)

	add_child(node)
	return node

func _button(label: String, radius: float, accent: Color) -> Control:
	var node := _circle(radius, Color(accent.r, accent.g, accent.b, 0.16), Color(accent.r, accent.g, accent.b, 0.7))

	var text := Label.new()
	text.text = label
	text.add_theme_color_override("font_color", accent)
	text.add_theme_font_size_override("font_size", 13 if radius < 70 else 16)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(text)
	return node

func _button_at(position: Vector2) -> String:
	for button_name in _buttons:
		var node: Control = _buttons[button_name]
		var centre := node.position + node.size * 0.5
		if position.distance_to(centre) <= node.size.x * 0.5:
			return button_name
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseMotion and _look_touch == -2:
		look += event.relative

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var button := _button_at(event.position)
		if button != "":
			_press(button, event.index)
			return

		if event.position.x < get_viewport_rect().size.x * 0.5 and _move_touch == -1:
			_move_touch = event.index
			_stick_origin = event.position
			_stick_handle = event.position
			_stick_base.position = event.position - Vector2(STICK_RADIUS, STICK_RADIUS)
			_stick_base.visible = true
		elif _look_touch == -1:
			_look_touch = event.index
	else:
		_release(event.index)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch:
		var offset := event.position - _stick_origin
		if offset.length() > STICK_RADIUS:
			offset = offset.normalized() * STICK_RADIUS
		_stick_handle = _stick_origin + offset
		_stick_knob.position = Vector2(STICK_RADIUS, STICK_RADIUS) + offset - _stick_knob.size * 0.5
		move = Vector2(offset.x, -offset.y) / STICK_RADIUS
	elif event.index == _look_touch:
		look += event.relative

var _pressed: Dictionary = {}          # touch index -> button name

func _press(button: String, index: int) -> void:
	_pressed[index] = button
	match button:
		"fire": fire_pressed.emit(true)
		"jump": jump_pressed.emit()
		"reload": reload_pressed.emit()
		"sprint": sprinting = not sprinting

func _release(index: int) -> void:
	if _pressed.has(index):
		if _pressed[index] == "fire":
			fire_pressed.emit(false)
		_pressed.erase(index)
		return

	if index == _move_touch:
		_move_touch = -1
		move = Vector2.ZERO
		_stick_base.visible = false
		_stick_knob.position = Vector2(STICK_RADIUS, STICK_RADIUS) - _stick_knob.size * 0.5
	elif index == _look_touch:
		_look_touch = -1

## Reads and clears the accumulated look delta.
func consume_look() -> Vector2:
	var delta := look
	look = Vector2.ZERO
	return delta

## Keyboard falls back in for desktop testing. Keys are read directly rather
## than through the input map: a hand-written map in project.godot is one typo
## away from breaking the whole project file.
func move_axis() -> Vector2:
	var keys := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
	return keys if keys.length_squared() > 0.01 else move

func jump_held() -> bool:
	return Input.is_key_pressed(KEY_SPACE)

func fire_held() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
