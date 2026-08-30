class_name SettingsScreen
extends CanvasLayer
## Name, aim feel, control layout and which map to play.

signal closed

var _name_field: LineEdit
var _sensitivity: HSlider
var _map_button: Button
var _fov: HSlider

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

	var fov_label := UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_HI)
	column.add_child(fov_label)
	_fov = UiTheme.slider(60.0, 95.0,
		float(Session.get_pref("aim", "fov", 74.0)), 1.0)
	var on_fov := func(value: float) -> void:
		Session.set_pref("aim", "fov", value)
		fov_label.text = "Field of view   %d" % int(value)
	_fov.value_changed.connect(on_fov)
	fov_label.text = "Field of view   %d" % int(_fov.value)
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
