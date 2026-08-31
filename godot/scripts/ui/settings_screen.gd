class_name SettingsScreen
extends CanvasLayer
## Name, aim feel, control layout and which map to play.

signal closed

var _name_field: LineEdit
var _sensitivity: HSlider
var _map_button: Button
var _fov: HSlider
var _library: AssetLibrary

func _ready() -> void:
	layer = 30

	var background := ColorRect.new()
	background.color = UiTheme.VOID
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	background.add_child(margin)

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)

	column.add_child(UiTheme.label("SETTINGS", UiTheme.SIZE_TITLE, UiTheme.TEXT_HI))
	column.add_child(UiTheme.spacer(8))

	_build_identity(column)
	_build_body(column)
	_build_loadout(column)
	_build_aim(column)
	_build_map(column)
	_build_layout(column)

	column.add_child(UiTheme.spacer(16))
	column.add_child(UiTheme.button("Done", UiTheme.SUCCESS, _close))

func _section(parent: Control, title: String) -> VBoxContainer:
	var panel := UiTheme.panel()
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiTheme.label(title, UiTheme.SIZE_HEADING, UiTheme.CYAN))
	return column

# --- who you are --------------------------------------------------------------

func _build_identity(parent: Control) -> void:
	var column := _section(parent, "Agent name")
	column.add_child(UiTheme.label(
		"This is the name other phones see in the Wi-Fi squad list.",
		UiTheme.SIZE_SMALL, UiTheme.TEXT_MID))

	_name_field = UiTheme.text_field(Session.display_name, "Your name")
	_name_field.max_length = 18
	var on_name := func(value: String) -> void:
		Session.set_display_name(value)
	_name_field.text_changed.connect(on_name)
	_name_field.text_submitted.connect(on_name)
	column.add_child(_name_field)

# --- who you look like --------------------------------------------------------

func _build_body(parent: Control) -> void:
	var column := _section(parent, "Body")
	var chosen := String(Session.get_pref("identity", "body", "recruit"))

	var note := UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.TEXT_MID)
	var buttons: Dictionary = {}
	var choose := func(entry: Dictionary) -> void:
		Session.set_pref("identity", "body", String(entry.get("id", "")))
		note.text = String(entry.get("note", ""))
		for id in buttons:
			var button: Button = buttons[id]
			var picked: bool = id == String(entry.get("id", ""))
			button.add_theme_stylebox_override("normal", UiTheme.fill(
				Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b,
					0.30 if picked else 0.08),
				12, 2 if picked else 1,
				UiTheme.CYAN if picked else UiTheme.LINE))

	for entry in AgentCatalog.BODIES:
		var button := UiTheme.button(String(entry.get("name", "")),
			UiTheme.TEXT_HI, choose.bind(entry), 62)
		buttons[String(entry.get("id", ""))] = button
		column.add_child(button)
	column.add_child(note)

	for entry in AgentCatalog.BODIES:
		if String(entry.get("id", "")) == chosen:
			choose.call(entry)
			return
	choose.call(AgentCatalog.BODIES[0])

# --- what you carry -----------------------------------------------------------

func _build_loadout(parent: Control) -> void:
	var column := _section(parent, "Loadout")
	column.add_child(UiTheme.label(
		"Two weapons go into a match: one in your hands, one across your back. "
		+ "The swap button trades them.", UiTheme.SIZE_SMALL, UiTheme.TEXT_MID))

	_library = AssetLibrary.new(0)
	_slot_row(column, "primary", "Primary")
	_slot_row(column, "secondary", "Sidearm")

## One row per slot: the choices on the left, the model turning on the right.
func _slot_row(parent: Control, slot: String, title: String) -> void:
	var choices := AgentCatalog.weapons_for_slot(slot)
	if choices.is_empty():
		return

	var chosen_id := String(Session.get_pref("loadout", slot,
		String(choices[0].get("id", ""))))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	row.add_child(list)
	list.add_child(UiTheme.label(title.to_upper(), UiTheme.SIZE_SMALL,
		UiTheme.TEXT_LOW))

	var preview := WeaponPreview.new(_library)
	row.add_child(preview)

	var buttons: Dictionary = {}
	var choose := func(weapon: Dictionary) -> void:
		Session.set_pref("loadout", slot, String(weapon.get("id", "")))
		preview.show_weapon(weapon)
		for id in buttons:
			var button: Button = buttons[id]
			var picked: bool = id == String(weapon.get("id", ""))
			button.add_theme_stylebox_override("normal", UiTheme.fill(
				Color(UiTheme.CYAN.r, UiTheme.CYAN.g, UiTheme.CYAN.b,
					0.30 if picked else 0.08),
				12, 2 if picked else 1,
				UiTheme.CYAN if picked else UiTheme.LINE))

	for weapon in choices:
		var caption := "%s   ·   %s" % [weapon.get("name", ""),
			weapon.get("class", "")]
		var button := UiTheme.button(caption, UiTheme.TEXT_HI,
			choose.bind(weapon), 62)
		buttons[String(weapon.get("id", ""))] = button
		list.add_child(button)

	for weapon in choices:
		if String(weapon.get("id", "")) == chosen_id:
			choose.call(weapon)
			return
	choose.call(choices[0])

# --- aim ----------------------------------------------------------------------

func _build_aim(parent: Control) -> void:
	var column := _section(parent, "Aim and camera")

	var sensitivity_label := UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_HI)
	column.add_child(sensitivity_label)
	_sensitivity = UiTheme.slider(0.05, 0.60,
		float(Session.get_pref("aim", "sensitivity", 0.20)))
	var on_sensitivity := func(value: float) -> void:
		Session.set_pref("aim", "sensitivity", value)
		sensitivity_label.text = "Look sensitivity   %.2f" % value
	_sensitivity.value_changed.connect(on_sensitivity)
	sensitivity_label.text = "Look sensitivity   %.2f" % _sensitivity.value
	column.add_child(_sensitivity)

	column.add_child(UiTheme.label(
		"A wider view stretches whatever is near the edges of the screen. "
		+ "Narrow it if that bothers you.", UiTheme.SIZE_SMALL, UiTheme.TEXT_MID))
	var fov_label := UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_HI)
	column.add_child(fov_label)
	_fov = UiTheme.slider(55.0, 95.0,
		float(Session.get_pref("aim", "fov", 72.0)), 1.0)
	var on_fov := func(value: float) -> void:
		Session.set_pref("aim", "fov", value)
		fov_label.text = "Field of view (across)   %d" % int(value)
	_fov.value_changed.connect(on_fov)
	fov_label.text = "Field of view (across)   %d" % int(_fov.value)
	column.add_child(_fov)

# --- which world --------------------------------------------------------------

func _build_map(parent: Control) -> void:
	var column := _section(parent, "Map")
	column.add_child(UiTheme.label(
		"The supplied map is used when the build managed to fetch it; the town "
		+ "is assembled from the kit and always works.",
		UiTheme.SIZE_SMALL, UiTheme.TEXT_MID))

	_map_button = UiTheme.button(_map_text(), UiTheme.AMBER, _cycle_map, 72)
	column.add_child(_map_button)

func _map_text() -> String:
	var choice := String(Session.get_pref("world", "map", "auto"))
	match choice:
		"town": return "Map:  Generated town"
		"supplied": return "Map:  Supplied map"
		_: return "Map:  Automatic (supplied if present)"

func _cycle_map() -> void:
	var order := ["auto", "supplied", "town"]
	var choice := String(Session.get_pref("world", "map", "auto"))
	var index := maxi(0, order.find(choice))
	Session.set_pref("world", "map", order[(index + 1) % order.size()])
	_map_button.text = _map_text()

# --- controls -----------------------------------------------------------------

func _build_layout(parent: Control) -> void:
	var column := _section(parent, "Controls")
	column.add_child(UiTheme.label(
		"Move every button where your thumbs actually reach, and size it to "
		+ "suit your phone.", UiTheme.SIZE_SMALL, UiTheme.TEXT_MID))
	column.add_child(UiTheme.button("Edit control layout", UiTheme.CYAN,
		_open_layout_editor, 76))

func _open_layout_editor() -> void:
	var editor := LayoutEditor.new()
	get_tree().root.add_child(editor)

func _close() -> void:
	Session.set_display_name(_name_field.text)
	closed.emit()
	queue_free()
