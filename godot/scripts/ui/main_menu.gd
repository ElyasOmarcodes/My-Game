class_name MainMenu
extends CanvasLayer
## Front screen: host a squad, join one that is already on this Wi-Fi, or drop
## into the city alone to look around.

signal host_requested(room_name: String)
signal join_requested(address: String)
signal solo_requested

const VOID := Color("#05070C")
const SURFACE := Color("#0B1119")
const LINE := Color("#1E2C3C")
const CYAN := Color("#3BE8FF")
const AMBER := Color("#FFB23B")
const TEXT_HI := Color("#E8F4FF")
const TEXT_MID := Color("#93A6BC")
const TEXT_LOW := Color("#55677D")

var _room_list: VBoxContainer
var _status: Label

func _ready() -> void:
	layer = 20

	var background := ColorRect.new()
	background.color = VOID
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 56
	left.offset_right = 460
	left.offset_top = 48
	left.offset_bottom = -48
	left.add_theme_constant_override("separation", 10)
	background.add_child(left)

	_heading(left, "// B O A", 15, CYAN)
	_heading(left, "BATTLE OF AGENTS", 40, TEXT_HI)
	_heading(left, "Wi-Fi squad combat · 2–8 agents", 15, TEXT_MID)
	_spacer(left, 18)

	_button(left, "Host a squad", CYAN, func():
		host_requested.emit("%s's squad" % Session.display_name))
	_button(left, "Solo drill", AMBER, func(): solo_requested.emit())
	_spacer(left, 12)
	_heading(left, "%s · %s" % [Session.display_name, Lan.local_ip()], 13, TEXT_LOW)

	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -520
	right.offset_right = -56
	right.offset_top = 48
	right.offset_bottom = -48
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = LINE
	style.set_border_width_all(1)
	right.add_theme_stylebox_override("panel", style)
	background.add_child(right)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	right.add_child(column)

	_heading(column, "SQUADS ON THIS WI-FI", 13, TEXT_LOW)
	_room_list = VBoxContainer.new()
	_room_list.add_theme_constant_override("separation", 6)
	_room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_room_list)

	_status = _heading(column, "scanning…", 13, TEXT_MID)

	Lan.rooms_changed.connect(_render_rooms)
	Lan.start_scanning()
	_render_rooms(Lan.rooms())

func _exit_tree() -> void:
	if Lan.rooms_changed.is_connected(_render_rooms):
		Lan.rooms_changed.disconnect(_render_rooms)

func _render_rooms(rooms: Array) -> void:
	for child in _room_list.get_children():
		child.queue_free()

	if rooms.is_empty():
		_status.text = "No squads yet — ask the host to open a room."
		return

	_status.text = "%d squad%s found" % [rooms.size(), "" if rooms.size() == 1 else "s"]
	for room in rooms:
		var row := Button.new()
		row.text = "%s   ·   %s   ·   %d/%d" % [
			room.get("roomName", "room"), room.get("hostName", "?"),
			int(room.get("players", 1)), int(room.get("maxPlayers", 8))]
		row.add_theme_font_size_override("font_size", 15)
		row.custom_minimum_size = Vector2(0, 46)
		var address := String(room.get("hostAddress", ""))
		row.pressed.connect(func(): join_requested.emit(address))
		_room_list.add_child(row)

# --- widgets ------------------------------------------------------------------

func _heading(parent: Control, text: String, size: int, colour: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_color_override("font_color", colour)
	node.add_theme_font_size_override("font_size", size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func _spacer(parent: Control, height: int) -> void:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	parent.add_child(node)

func _button(parent: Control, text: String, accent: Color, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, 58)
	node.add_theme_font_size_override("font_size", 19)
	node.add_theme_color_override("font_color", accent)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	style.set_border_width_all(2)
	node.add_theme_stylebox_override("normal", style)

	var hovered := style.duplicate() as StyleBoxFlat
	hovered.bg_color = Color(accent.r, accent.g, accent.b, 0.24)
	node.add_theme_stylebox_override("hover", hovered)
	node.add_theme_stylebox_override("pressed", hovered)

	node.pressed.connect(action)
	parent.add_child(node)
	return node
