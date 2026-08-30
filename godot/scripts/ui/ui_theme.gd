class_name UiTheme
extends RefCounted
## One place for how the game looks, so the menu, the settings and the HUD
## cannot drift apart.
##
## Everything is built in code rather than as a .tres, which keeps the palette
## reviewable in a plain diff and lets a screen ask for "a primary button" and
## get the same thing everywhere.

const VOID := Color("#070A10")
const SURFACE := Color("#101823")
const SURFACE_HI := Color("#18222F")
const LINE := Color("#243447")
const CYAN := Color("#3BE8FF")
const AMBER := Color("#FFB23B")
const DANGER := Color("#FF4D5E")
const SUCCESS := Color("#4DFFA6")
const VIOLET := Color("#B58CFF")
const TEXT_HI := Color("#EAF4FF")
const TEXT_MID := Color("#9FB3C8")
const TEXT_LOW := Color("#5E738C")

## Type scale. Phone screens are small and held at arm's length, so everything
## here is a step larger than a desktop game would use.
const SIZE_TITLE := 58
const SIZE_HEADING := 30
const SIZE_BODY := 22
const SIZE_SMALL := 18
const BUTTON_HEIGHT := 84

static func fill(colour: Color, radius := 14, border := 0,
		border_colour := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	if border > 0:
		style.set_border_width_all(border)
		style.border_color = border_colour
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

## A full-width action button. `accent` carries the meaning: cyan to go on,
## amber for a secondary road, danger to back out.
static func button(text: String, accent: Color, action: Callable,
		height := BUTTON_HEIGHT) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, height)
	node.add_theme_font_size_override("font_size", SIZE_BODY + 3)
	node.add_theme_color_override("font_color", accent)
	node.add_theme_color_override("font_hover_color", VOID)
	node.add_theme_color_override("font_pressed_color", VOID)

	node.add_theme_stylebox_override("normal",
		fill(Color(accent.r, accent.g, accent.b, 0.12), 14, 2,
			Color(accent.r, accent.g, accent.b, 0.75)))
	node.add_theme_stylebox_override("hover",
		fill(Color(accent.r, accent.g, accent.b, 0.85), 14, 2, accent))
	node.add_theme_stylebox_override("pressed",
		fill(accent, 14, 2, accent))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if action.is_valid():
		node.pressed.connect(action)
	return node

static func label(text: String, size: int, colour: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", colour)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func panel(colour := SURFACE, radius := 20) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", fill(colour, radius, 1, LINE))
	return node

static func spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func text_field(value: String, placeholder := "") -> LineEdit:
	var node := LineEdit.new()
	node.text = value
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, 72)
	node.add_theme_font_size_override("font_size", SIZE_BODY + 2)
	node.add_theme_color_override("font_color", TEXT_HI)
	node.add_theme_stylebox_override("normal", fill(SURFACE_HI, 12, 2, LINE))
	node.add_theme_stylebox_override("focus", fill(SURFACE_HI, 12, 2, CYAN))
	return node

static func slider(minimum: float, maximum: float, value: float,
		step := 0.01) -> HSlider:
	var node := HSlider.new()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = value
	node.custom_minimum_size = Vector2(0, 56)
	return node
