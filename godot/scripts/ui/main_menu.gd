class_name MainMenu
extends CanvasLayer
## Front screen: pick an agent, then host a squad, join one already on this
## Wi-Fi, or drop in alone.

signal host_requested(room_name: String)
signal join_requested(address: String)
signal solo_requested

var _room_list: VBoxContainer
var _status: Label
var _agent_row: HBoxContainer
var _agent_blurb: Label
var _agent_cards: Dictionary = {}       # agent id -> PanelContainer
var _name_label: Label

func _ready() -> void:
	layer = 20

	var background := ColorRect.new()
	background.color = UiTheme.VOID
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# A slab of colour behind the title, so the screen has a horizon rather
	# than reading as a form on black.
	var wash := ColorRect.new()
	wash.color = Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b, 0.05)
	wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wash.offset_bottom = 260
	background.add_child(wash)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	background.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	margin.add_child(columns)

	_build_left(columns)
	_build_right(columns)

	Lan.rooms_changed.connect(_render_rooms)
	Lan.start_scanning()
	_render_rooms(Lan.rooms())

func _exit_tree() -> void:
	if Lan.rooms_changed.is_connected(_render_rooms):
		Lan.rooms_changed.disconnect(_render_rooms)

# --- left: identity, agents, actions ------------------------------------------

func _build_left(parent: Control) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.35
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)

	column.add_child(UiTheme.label("// B O A", UiTheme.SIZE_SMALL, UiTheme.CYAN))
	column.add_child(UiTheme.label("BATTLE OF AGENTS", UiTheme.SIZE_TITLE,
		UiTheme.TEXT_HI))
	column.add_child(UiTheme.label("Wi-Fi squad combat · 2–8 agents",
		UiTheme.SIZE_BODY, UiTheme.TEXT_MID))
	column.add_child(UiTheme.spacer(14))

	column.add_child(UiTheme.label("CHOOSE YOUR AGENT", UiTheme.SIZE_SMALL,
		UiTheme.TEXT_LOW))
	_agent_row = HBoxContainer.new()
	_agent_row.add_theme_constant_override("separation", 12)
	column.add_child(_agent_row)
	for entry in AgentCatalog.AGENTS:
		_agent_cards[entry["id"]] = _agent_card(entry)

	_agent_blurb = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEXT_MID)
	column.add_child(_agent_blurb)
	_choose_agent(Session.agent_id)

	# Lambdas are bound before they are passed: GDScript will not accept a
	# multi-line one written inside a call.
	var on_host := func() -> void:
		host_requested.emit("%s's squad" % Session.display_name)
	var on_solo := func() -> void:
		solo_requested.emit()

	column.add_child(UiTheme.spacer(16))
	column.add_child(UiTheme.button("HOST A SQUAD", UiTheme.CYAN, on_host))
	column.add_child(UiTheme.button("SOLO DRILL", UiTheme.AMBER, on_solo))
	column.add_child(UiTheme.button("SETTINGS", UiTheme.TEXT_MID, _open_settings, 70))

	column.add_child(UiTheme.spacer(8))
	_name_label = UiTheme.label(_identity_text(), UiTheme.SIZE_SMALL,
		UiTheme.TEXT_LOW)
	column.add_child(_name_label)

func _identity_text() -> String:
	return "%s   ·   %s" % [Session.display_name, Lan.local_ip()]

func _agent_card(entry: Dictionary) -> PanelContainer:
	var accent: Color = entry.get("accent", UiTheme.CYAN)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	# No wrapping: "VANGUARD" broke across two lines on a four-card row.
	var title := UiTheme.label(String(entry["name"]).to_upper(),
		UiTheme.SIZE_SMALL + 2, accent, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	column.add_child(title)
	column.add_child(UiTheme.label(String(entry["role"]), UiTheme.SIZE_SMALL,
		UiTheme.TEXT_MID, HORIZONTAL_ALIGNMENT_CENTER))

	var agent_id := String(entry["id"])
	var on_input := func(event: InputEvent) -> void:
		var touched: bool = event is InputEventScreenTouch \
			and (event as InputEventScreenTouch).pressed
		var clicked: bool = event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed
		if touched or clicked:
			_choose_agent(agent_id)
	card.gui_input.connect(on_input)

	_agent_row.add_child(card)
	return card

func _choose_agent(agent_id: String) -> void:
	Session.agent_id = agent_id
	Session.set_pref("identity", "agent", agent_id)

	for id in _agent_cards:
		var entry := AgentCatalog.agent(id)
		var accent: Color = entry.get("accent", UiTheme.CYAN)
		var chosen: bool = id == agent_id
		var card: PanelContainer = _agent_cards[id]
		card.add_theme_stylebox_override("panel", UiTheme.fill(
			Color(accent.r, accent.g, accent.b, 0.22 if chosen else 0.06),
			16, 3 if chosen else 1,
			accent if chosen else UiTheme.LINE))

	var chosen_entry := AgentCatalog.agent(agent_id)
	var weapon := AgentCatalog.weapon(String(chosen_entry.get("weapon", "")))
	_agent_blurb.text = "%s   ·   %s" % [
		chosen_entry.get("blurb", ""), weapon.get("name", "")]

# --- right: the Wi-Fi squad list ----------------------------------------------

func _build_right(parent: Control) -> void:
	var panel := UiTheme.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	column.add_child(UiTheme.label("SQUADS ON THIS WI-FI", UiTheme.SIZE_HEADING,
		UiTheme.TEXT_HI))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_room_list = VBoxContainer.new()
	_room_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_room_list)

	_status = UiTheme.label("scanning…", UiTheme.SIZE_BODY, UiTheme.TEXT_MID)
	column.add_child(_status)

func _render_rooms(rooms: Array) -> void:
	for child in _room_list.get_children():
		child.queue_free()

	if rooms.is_empty():
		_status.text = "No squads yet."
		return

	_status.text = "%d squad%s found" % [rooms.size(), "" if rooms.size() == 1 else "s"]
	for room in rooms:
		var address := String(room.get("hostAddress", ""))
		var caption := "%s        %s        %d/%d" % [
			room.get("roomName", "room"), room.get("hostName", "?"),
			int(room.get("players", 1)), int(room.get("maxPlayers", 8))]
		var on_join := func() -> void:
			join_requested.emit(address)
		_room_list.add_child(UiTheme.button(caption, UiTheme.SUCCESS, on_join, 76))

# --- settings -----------------------------------------------------------------

func _open_settings() -> void:
	var screen := SettingsScreen.new()
	screen.closed.connect(_refresh_identity)
	get_tree().root.add_child(screen)

func _refresh_identity() -> void:
	_name_label.text = _identity_text()
