class_name ActionIcon
extends Control
## The glyph on a touch button, drawn rather than imported.
##
## A pictogram is read faster than a word under a thumb, and it does not need
## translating. Drawing them keeps the APK free of an icon atlas and lets every
## glyph scale to whatever size the player drags the button to.

## Filename fragments to look for in the fetched icon pack, best first. Kenney's
## on-screen controls pack does not name things the way this game does, so each
## button lists what it would accept rather than one exact filename.
const WANTED := {
	"fire":    ["shootbutton", "buttona", "circle", "target", "crosshair"],
	"jump":    ["arrowup", "up_", "buttonb", "chevronup"],
	"reload":  ["return", "reload", "refresh", "rotate", "buttonx"],
	"grenade": ["bomb", "grenade", "buttony", "star"],
	"sprint":  ["arrowright", "right_", "fast", "forward"],
	"crouch":  ["arrowdown", "down_", "chevrondown"],
	"prone":   ["minus", "bar", "line", "dash"],
	"swap":    ["swap", "exchange", "switch", "arrowleftright", "shuffle"],
}

const ICON_DIRECTORY := "res://assets/icons/"

static var _catalogue: PackedStringArray = PackedStringArray()
static var _scanned := false

var _texture: Texture2D

var kind := "fire":
	set(value):
		kind = value
		queue_redraw()

var colour := Color.WHITE:
	set(value):
		colour = value
		queue_redraw()

func _init(icon_kind := "fire", tint := Color.WHITE) -> void:
	kind = icon_kind
	colour = tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = _find_texture(icon_kind)

## Reads the icon folder once and keeps the listing, rather than opening the
## directory eight times while the HUD is being built.
static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	var folder := DirAccess.open(ICON_DIRECTORY)
	if folder == null:
		return
	for file in folder.get_files():
		var name := String(file).trim_suffix(".remap").trim_suffix(".import")
		if name.ends_with(".png"):
			_catalogue.append(name)

## The best match in the fetched pack, or null to fall back to a drawn glyph.
static func _find_texture(icon_kind: String) -> Texture2D:
	_scan()
	if _catalogue.is_empty():
		return null
	for fragment in WANTED.get(icon_kind, []):
		for file in _catalogue:
			if file.to_lower().find(String(fragment)) == -1:
				continue
			var path := ICON_DIRECTORY + file
			if not ResourceLoader.exists(path):
				continue
			var texture := load(path)
			if texture is Texture2D:
				return texture
	return null

func _draw() -> void:
	# A real icon when the pack landed; the drawn glyph is the fallback, so the
	# buttons still read before any art has been fetched.
	if _texture != null:
		var side := minf(size.x, size.y) * 0.56
		var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
		draw_texture_rect(_texture, box, false, colour)
		return

	var box := size
	var mid := box * 0.5
	var unit := minf(box.x, box.y) * 0.5      # the glyph's working radius
	var stroke := maxf(2.0, unit * 0.13)

	match kind:
		"fire":     _draw_reticle(mid, unit, stroke)
		"jump":     _draw_jump(mid, unit, stroke)
		"reload":   _draw_reload(mid, unit, stroke)
		"grenade":  _draw_grenade(mid, unit, stroke)
		"crouch":   _draw_crouch(mid, unit, stroke)
		"prone":    _draw_prone(mid, unit, stroke)
		"sprint":   _draw_sprint(mid, unit, stroke)
		"swap":     _draw_swap(mid, unit, stroke)
		_:          draw_circle(mid, unit * 0.4, colour)

## Fire: a reticle, because the thing it does is put a shot where you are aiming.
func _draw_reticle(mid: Vector2, unit: float, stroke: float) -> void:
	var ring := unit * 0.62
	draw_arc(mid, ring, 0.0, TAU, 48, colour, stroke, true)
	draw_circle(mid, unit * 0.16, colour)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(mid + direction * ring * 0.78, mid + direction * unit,
			colour, stroke, true)

func _draw_jump(mid: Vector2, unit: float, stroke: float) -> void:
	var top := mid + Vector2(0, -unit * 0.72)
	_chevron(top, unit * 0.52, stroke, true)
	_chevron(top + Vector2(0, unit * 0.52), unit * 0.52, stroke, true)
	draw_line(mid + Vector2(-unit * 0.62, unit * 0.74),
		mid + Vector2(unit * 0.62, unit * 0.74), colour, stroke, true)

func _draw_crouch(mid: Vector2, unit: float, stroke: float) -> void:
	var top := mid + Vector2(0, -unit * 0.52)
	_chevron(top, unit * 0.52, stroke, false)
	_chevron(top + Vector2(0, unit * 0.5), unit * 0.52, stroke, false)
	draw_line(mid + Vector2(-unit * 0.62, unit * 0.78),
		mid + Vector2(unit * 0.62, unit * 0.78), colour, stroke, true)

## Prone: a body lying flat, over the same ground line the other stances use.
func _draw_prone(mid: Vector2, unit: float, stroke: float) -> void:
	draw_circle(mid + Vector2(-unit * 0.52, -unit * 0.12), unit * 0.2, colour)
	draw_line(mid + Vector2(-unit * 0.3, -unit * 0.12),
		mid + Vector2(unit * 0.66, -unit * 0.12), colour, stroke * 1.5, true)
	draw_line(mid + Vector2(-unit * 0.72, unit * 0.5),
		mid + Vector2(unit * 0.72, unit * 0.5), colour, stroke, true)

func _draw_reload(mid: Vector2, unit: float, stroke: float) -> void:
	var ring := unit * 0.66
	draw_arc(mid, ring, PI * 0.42, PI * 2.05, 40, colour, stroke, true)
	# Arrowhead closing the loop, so the direction of the turn is legible.
	var tip := mid + Vector2(cos(PI * 0.42), sin(PI * 0.42)) * ring
	var head := PackedVector2Array([
		tip + Vector2(-unit * 0.02, unit * 0.30),
		tip + Vector2(-unit * 0.34, -unit * 0.06),
		tip + Vector2(unit * 0.16, -unit * 0.18)])
	draw_colored_polygon(head, colour)

func _draw_grenade(mid: Vector2, unit: float, stroke: float) -> void:
	var body := mid + Vector2(0, unit * 0.16)
	draw_circle(body, unit * 0.52, colour)
	# Segment lines, so it reads as a fragmentation grenade and not a ball.
	var dark := Color(0, 0, 0, 0.45)
	draw_line(body + Vector2(-unit * 0.5, -unit * 0.16),
		body + Vector2(unit * 0.5, -unit * 0.16), dark, stroke * 0.7, true)
	draw_line(body + Vector2(-unit * 0.5, unit * 0.18),
		body + Vector2(unit * 0.5, unit * 0.18), dark, stroke * 0.7, true)
	draw_line(body + Vector2(0, -unit * 0.52),
		body + Vector2(0, unit * 0.52), dark, stroke * 0.7, true)
	# Spoon and pin ring on top.
	draw_line(body + Vector2(-unit * 0.1, -unit * 0.52),
		body + Vector2(-unit * 0.1, -unit * 0.88), colour, stroke * 1.2, true)
	draw_arc(body + Vector2(unit * 0.34, -unit * 0.74), unit * 0.22,
		0.0, TAU, 20, colour, stroke * 0.9, true)

func _draw_sprint(mid: Vector2, unit: float, stroke: float) -> void:
	for i in 3:
		var offset := Vector2(unit * (0.18 - i * 0.42), 0)
		_chevron_right(mid + offset, unit * 0.46, stroke)

## Two arrows passing each other: the weapon in hand goes to the back and the
## one on the back comes to hand.
func _draw_swap(mid: Vector2, unit: float, stroke: float) -> void:
	var reach := unit * 0.66
	draw_line(mid + Vector2(-reach, -unit * 0.3),
		mid + Vector2(reach, -unit * 0.3), colour, stroke, true)
	draw_line(mid + Vector2(-reach, unit * 0.3),
		mid + Vector2(reach, unit * 0.3), colour, stroke, true)
	_chevron_right(mid + Vector2(reach, -unit * 0.3), unit * 0.30, stroke)
	draw_line(mid + Vector2(-reach + unit * 0.21, unit * 0.06),
		mid + Vector2(-reach, unit * 0.3), colour, stroke, true)
	draw_line(mid + Vector2(-reach, unit * 0.3),
		mid + Vector2(-reach + unit * 0.21, unit * 0.54), colour, stroke, true)

func _chevron(tip: Vector2, span: float, stroke: float, pointing_up: bool) -> void:
	var drop := span if pointing_up else -span
	draw_line(tip + Vector2(-span, drop), tip, colour, stroke, true)
	draw_line(tip, tip + Vector2(span, drop), colour, stroke, true)

func _chevron_right(tip: Vector2, span: float, stroke: float) -> void:
	draw_line(tip + Vector2(-span * 0.7, -span), tip, colour, stroke, true)
	draw_line(tip, tip + Vector2(-span * 0.7, span), colour, stroke, true)
