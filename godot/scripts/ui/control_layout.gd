class_name ControlLayout
extends RefCounted
## Where each touch button sits and how big it is.
##
## Positions are fractions of the viewport rather than pixels, so a layout set
## on one phone still lands in the same place on another. Radii are in pixels
## against a 1080p reference and scaled at draw time.

const REFERENCE_HEIGHT := 1080.0

## name -> { x, y (0..1 of the viewport), r (radius at 1080p), icon, accent }
const DEFAULTS := {
	"fire":    {"x": 0.885, "y": 0.735, "r": 118.0},
	"jump":    {"x": 0.718, "y": 0.845, "r": 74.0},
	"reload":  {"x": 0.700, "y": 0.575, "r": 70.0},
	"grenade": {"x": 0.885, "y": 0.410, "r": 72.0},
	"sprint":  {"x": 0.575, "y": 0.640, "r": 64.0},
	"crouch":  {"x": 0.575, "y": 0.870, "r": 66.0},
	"prone":   {"x": 0.468, "y": 0.905, "r": 66.0},
	"swap":    {"x": 0.700, "y": 0.360, "r": 66.0},
}

const ACCENTS := {
	"fire":    Color("#FF4D5E"),
	"jump":    Color("#3BE8FF"),
	"reload":  Color("#FFB23B"),
	"grenade": Color("#4DFFA6"),
	"sprint":  Color("#3BE8FF"),
	"crouch":  Color("#B58CFF"),
	"prone":   Color("#B58CFF"),
	"swap":    Color("#FFB23B"),
}

## The order buttons are drawn and hit-tested in. Later entries win a tie, so
## the big fire button is listed first and the small ones can overlap its edge.
const ORDER := ["fire", "jump", "reload", "grenade", "sprint", "crouch",
	"prone", "swap"]

static func load_saved() -> Dictionary:
	var layout: Dictionary = {}
	for key in ORDER:
		var fallback: Dictionary = DEFAULTS[key]
		var stored = Session.get_pref("layout", key, null)
		if typeof(stored) == TYPE_DICTIONARY \
				and stored.has("x") and stored.has("y") and stored.has("r"):
			layout[key] = {
				"x": clampf(float(stored["x"]), 0.03, 0.97),
				"y": clampf(float(stored["y"]), 0.05, 0.97),
				"r": clampf(float(stored["r"]), 36.0, 220.0),
			}
		else:
			layout[key] = fallback.duplicate()
	return layout

static func save(layout: Dictionary) -> void:
	for key in layout:
		Session.set_pref("layout", key, layout[key])

static func reset() -> void:
	for key in ORDER:
		Session.set_pref("layout", key, DEFAULTS[key].duplicate())

## Screen rectangle for one button, at this viewport's size.
static func rect_for(entry: Dictionary, view: Vector2) -> Rect2:
	var radius := float(entry["r"]) * (view.y / REFERENCE_HEIGHT)
	var centre := Vector2(float(entry["x"]) * view.x, float(entry["y"]) * view.y)
	return Rect2(centre - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
