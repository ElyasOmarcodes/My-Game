class_name Hud
extends CanvasLayer
## In-match overlay: vitals bottom-left, ammo bottom-right, crosshair in the
## middle, and the touch controls on top of it all.

var controls: TouchControls

var _health_label: Label
var _health_bar: ColorRect
var _ammo_label: Label
var _weapon_label: Label
var _agent_label: Label
var _banner: Label

const TEXT_HI := Color("#E8F4FF")
const TEXT_LOW := Color("#55677D")
const CYAN := Color("#3BE8FF")
const DANGER := Color("#FF4D5E")
const SUCCESS := Color("#4DFFA6")

func _ready() -> void:
	layer = 10

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_vitals(root)
	_build_ammo(root)
	_build_crosshair(root)
	_build_banner(root)

	controls = TouchControls.new()
	root.add_child(controls)

func _build_vitals(root: Control) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(24, 0)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_top = -110
	box.offset_left = 24
	box.offset_right = 300
	box.offset_bottom = -24
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	_agent_label = _label(box, "VANGUARD", 17, CYAN)
	_health_label = _label(box, "120", 34, TEXT_HI)

	var track := ColorRect.new()
	track.color = Color(0.02, 0.03, 0.05, 0.85)
	track.custom_minimum_size = Vector2(240, 6)
	box.add_child(track)

	_health_bar = ColorRect.new()
	_health_bar.color = SUCCESS
	_health_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(_health_bar)

func _build_ammo(root: Control) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -560
	box.offset_right = -300
	box.offset_top = -90
	box.offset_bottom = -24
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	_ammo_label = _label(box, "30 / 150", 30, TEXT_HI, HORIZONTAL_ALIGNMENT_RIGHT)
	_weapon_label = _label(box, "MK-7 CARBINE", 12, TEXT_LOW, HORIZONTAL_ALIGNMENT_RIGHT)

func _build_crosshair(root: Control) -> void:
	var dot := ColorRect.new()
	dot.color = CYAN
	dot.custom_minimum_size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)

func _build_banner(root: Control) -> void:
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 18
	_banner.offset_left = -300
	_banner.offset_right = 300
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", SUCCESS)
	_banner.add_theme_font_size_override("font_size", 15)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	root.add_child(_banner)

func _label(parent: Control, text: String, size: int, colour: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_color_override("font_color", colour)
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

# --- bindings -----------------------------------------------------------------

func bind(player: Player) -> void:
	player.set_controls(controls)
	player.health_changed.connect(set_health)
	player.ammo_changed.connect(set_ammo)

	_agent_label.text = String(player.agent.get("name", "AGENT")).to_upper()
	_weapon_label.text = String(player.weapon_def.get("name", "")).to_upper()
	set_health(player.health, player.max_health)
	set_ammo(player.ammo_in_clip, player.ammo_reserve)

func set_health(current: float, maximum: float) -> void:
	_health_label.text = str(int(ceil(current)))
	var fraction := clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	_health_bar.anchor_right = fraction
	_health_bar.color = DANGER if fraction < 0.3 else SUCCESS

func set_ammo(in_clip: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [in_clip, reserve]
	_ammo_label.add_theme_color_override("font_color", DANGER if in_clip == 0 else TEXT_HI)

func flash(message: String, seconds := 3.0) -> void:
	_banner.text = message
	_banner.visible = true
	await get_tree().create_timer(seconds).timeout
	_banner.visible = false
