class_name TouchControls
extends Control
## The touch layer: a floating move stick on the left, aim by dragging the
## right, and the action buttons on top.
##
## Every button's position and size comes from ControlLayout, which the player
## edits in Settings — so this file never hard-codes where anything sits, and
## the drawn button and the region that responds are the same rectangle by
## construction. That mismatch is the commonest way a touch HUD goes wrong.

signal fire_pressed(down: bool)
signal jump_pressed
signal reload_pressed
signal grenade_pressed
signal swap_pressed
signal stance_changed(stance: int)

enum Stance { STAND, CROUCH, PRONE }

const STICK_RADIUS := 150.0
const STICK_DEAD_ZONE := 0.12

var move := Vector2.ZERO
var look := Vector2.ZERO
var sprinting := false
var stance: int = Stance.STAND

var _move_touch := -1
var _look_touch := -1
var _stick_origin := Vector2.ZERO

var _stick_base: Panel
var _stick_knob: Panel
var _buttons: Dictionary = {}          # name -> Control
var _layout: Dictionary = {}
var _pressed: Dictionary = {}          # touch index -> button name

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stick_base = _disc(STICK_RADIUS, Color(0.62, 0.74, 0.88, 0.10),
		Color(0.62, 0.74, 0.88, 0.34))
	_stick_base.visible = false
	_stick_knob = _disc(STICK_RADIUS * 0.40, Color(0.23, 0.91, 1.0, 0.30),
		Color(0.23, 0.91, 1.0, 0.70))
	remove_child(_stick_knob)
	_stick_base.add_child(_stick_knob)

	for key in ControlLayout.ORDER:
		_buttons[key] = _make_button(key)

	_layout = ControlLayout.load_saved()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

## Re-reads the saved layout — called when the player leaves the layout editor.
func refresh_layout() -> void:
	_layout = ControlLayout.load_saved()
	_apply_layout()

func _apply_layout() -> void:
	var view := get_viewport_rect().size
	for key in _buttons:
		var rect := ControlLayout.rect_for(_layout[key], view)
		var node: Control = _buttons[key]
		node.position = rect.position
		node.size = rect.size
		_restyle(node, rect.size.x * 0.5, ControlLayout.ACCENTS[key], false)
		for child in node.get_children():
			if child is Control:
				(child as Control).size = rect.size

# --- widgets ------------------------------------------------------------------

func _disc(radius: float, fill: Color, border: Color) -> Panel:
	var node := Panel.new()
	node.size = Vector2(radius * 2, radius * 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_disc(node, radius, fill, border)
	add_child(node)
	return node

func _style_disc(node: Panel, radius: float, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxf(2.0, radius * 0.045))
	style.set_corner_radius_all(int(radius))
	node.add_theme_stylebox_override("panel", style)

func _make_button(key: String) -> Panel:
	var accent: Color = ControlLayout.ACCENTS[key]
	var node := _disc(60.0, Color(accent.r, accent.g, accent.b, 0.15),
		Color(accent.r, accent.g, accent.b, 0.72))
	var icon := ActionIcon.new(key, accent)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(icon)
	return node

## Held buttons light up, and the two stances stay lit while they are the one
## you are in — otherwise there is no way to tell you are prone.
func _restyle(node: Control, radius: float, accent: Color, active: bool) -> void:
	var alpha := 0.42 if active else 0.15
	_style_disc(node as Panel, radius,
		Color(accent.r, accent.g, accent.b, alpha),
		Color(accent.r, accent.g, accent.b, 0.95 if active else 0.72))

func _set_active(key: String, active: bool) -> void:
	if not _buttons.has(key):
		return
	var node: Control = _buttons[key]
	_restyle(node, node.size.x * 0.5, ControlLayout.ACCENTS[key], active)

func _button_at(point: Vector2) -> String:
	# Back to front, so a small button overlapping the fire disc still wins.
	for i in range(ControlLayout.ORDER.size() - 1, -1, -1):
		var key: String = ControlLayout.ORDER[i]
		var node: Control = _buttons[key]
		var centre := node.position + node.size * 0.5
		if point.distance_to(centre) <= node.size.x * 0.5:
			return key
	return ""

# --- input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif _desktop and event is InputEventMouseMotion \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		look += (event as InputEventMouseMotion).relative

func _handle_touch(event: InputEventScreenTouch) -> void:
	if not event.pressed:
		_release(event.index)
		return

	var key := _button_at(event.position)
	if key != "":
		_press(key, event.index)
		return

	if event.position.x < get_viewport_rect().size.x * 0.5 and _move_touch == -1:
		_move_touch = event.index
		_stick_origin = event.position
		_stick_base.position = event.position - Vector2(STICK_RADIUS, STICK_RADIUS)
		_stick_base.visible = true
		_centre_knob(Vector2.ZERO)
	elif _look_touch == -1:
		_look_touch = event.index

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch:
		var offset := event.position - _stick_origin
		if offset.length() > STICK_RADIUS:
			offset = offset.normalized() * STICK_RADIUS
		_centre_knob(offset)
		var axis := Vector2(offset.x, -offset.y) / STICK_RADIUS
		move = Vector2.ZERO if axis.length() < STICK_DEAD_ZONE else axis
	elif event.index == _look_touch:
		look += event.relative

func _centre_knob(offset: Vector2) -> void:
	_stick_knob.position = Vector2(STICK_RADIUS, STICK_RADIUS) + offset \
		- _stick_knob.size * 0.5

func _press(key: String, index: int) -> void:
	_pressed[index] = key
	match key:
		"fire":
			fire_pressed.emit(true)
			_set_active("fire", true)
		"jump":
			jump_pressed.emit()
			_set_active("jump", true)
		"reload":
			reload_pressed.emit()
			_set_active("reload", true)
		"grenade":
			grenade_pressed.emit()
			_set_active("grenade", true)
		"swap":
			swap_pressed.emit()
			_set_active("swap", true)
		"sprint":
			sprinting = not sprinting
			_set_active("sprint", sprinting)
		"crouch":
			_toggle_stance(Stance.CROUCH)
		"prone":
			_toggle_stance(Stance.PRONE)

func _toggle_stance(wanted: int) -> void:
	stance = Stance.STAND if stance == wanted else wanted
	_set_active("crouch", stance == Stance.CROUCH)
	_set_active("prone", stance == Stance.PRONE)
	stance_changed.emit(stance)

func _release(index: int) -> void:
	if _pressed.has(index):
		var key: String = _pressed[index]
		match key:
			"fire":
				fire_pressed.emit(false)
				_set_active("fire", false)
			"jump", "reload", "grenade", "swap":
				_set_active(key, false)
		_pressed.erase(index)
		return

	if index == _move_touch:
		_move_touch = -1
		move = Vector2.ZERO
		_stick_base.visible = false
		_centre_knob(Vector2.ZERO)
	elif index == _look_touch:
		_look_touch = -1

# --- what the player reads ----------------------------------------------------

## Reads and clears the accumulated look delta.
func consume_look() -> Vector2:
	var delta := look
	look = Vector2.ZERO
	return delta

## Keyboard and mouse are for desktop testing only. On a phone they must stay
## out of it entirely: a screen tap used to arrive as a left mouse click and
## fire the weapon from anywhere on the screen.
##
## Keys are read directly rather than through the input map: a hand-written map
## in project.godot is one typo away from breaking the whole project file.
var _desktop := not DisplayServer.is_touchscreen_available()

func move_axis() -> Vector2:
	if not _desktop:
		return move
	var keys := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
	return keys if keys.length_squared() > 0.01 else move

func jump_held() -> bool:
	return _desktop and Input.is_key_pressed(KEY_SPACE)

func fire_held() -> bool:
	if not _desktop:
		return false
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_key_pressed(KEY_CTRL)

func sprint_held() -> bool:
	return sprinting or (_desktop and Input.is_key_pressed(KEY_SHIFT))
