class_name AgentAnimator
extends RefCounted
## Drives an agent's body from what it is doing.
##
## The old driver guessed at three clip names — Idle, Walk, Run — and played
## whichever one matched a substring. On a rig that has forty-six clips that
## threw away every one that mattered: the crouch walk, the jump broken into
## start, loop and land, and the whole pistol set. Firing looked like standing
## still, which is most of what "the weapon interaction is bad" was.
##
## Intent goes in — stance, speed, airborne, armed — and one clip comes out,
## chosen from what this particular rig actually has. One-shots (a shot, a
## reload, a hit) play over the top and hand control back when they finish.

## Every name the pack uses for each role, best first. A rig that has none of
## them falls through to the next role, and a rig that has nothing at all is
## left alone rather than made to stutter.
const LOOPS := {
	"idle":         ["Pistol_Idle_Loop", "Idle_Loop", "Idle"],
	"walk":         ["Walk_Loop", "Walk"],
	"jog":          ["Jog_Fwd_Loop", "Run", "Walk_Loop"],
	"sprint":       ["Sprint_Loop", "Jog_Fwd_Loop", "Run"],
	"crouch_idle":  ["Crouch_Idle_Loop", "Idle_Loop", "Idle"],
	"crouch_walk":  ["Crouch_Fwd_Loop", "Crouch_Idle_Loop", "Walk_Loop"],
	"prone_idle":   ["Crouch_Idle_Loop", "Idle_Loop", "Idle"],
	"prone_move":   ["Crouch_Fwd_Loop", "Crouch_Idle_Loop", "Walk_Loop"],
	"jump_rise":    ["Jump_Loop", "Jump_Start", "Idle_Loop"],
	"jump_fall":    ["Jump_Loop", "Jump_Land", "Idle_Loop"],
}

const ONE_SHOTS := {
	"shoot":  ["Pistol_Shoot", "Punch_Jab"],
	"reload": ["Pistol_Reload", "Interact"],
	"hit":    ["Hit_Chest", "Hit_Head"],
	"death":  ["Death01"],
	"land":   ["Jump_Land"],
}

const BLEND := 0.16
const WALK_SPEED := 3.2         ## below this a step is a walk
const SPRINT_SPEED := 9.0       ## above this it is a sprint

var _player: AnimationPlayer
var _available: Dictionary = {}   ## role -> the clip name this rig actually has
var _loop := ""
var _one_shot := ""

func _init(model: Node) -> void:
	_player = _find_player(model)
	if _player == null:
		return
	var names := _player.get_animation_list()
	for role in LOOPS:
		_available[role] = _first_present(names, LOOPS[role])
	for role in ONE_SHOTS:
		_available[role] = _first_present(names, ONE_SHOTS[role])
	print("[anim] %d clips, idle=%s shoot=%s crouch=%s" % [names.size(),
		_available.get("idle", "-"), _available.get("shoot", "-"),
		_available.get("crouch_idle", "-")])

func ready() -> bool:
	return _player != null

static func _find_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null

## Exact match first, then a case-insensitive substring, because packs differ on
## capitalisation more often than on wording.
static func _first_present(names: PackedStringArray, wanted: Array) -> String:
	for candidate in wanted:
		for name in names:
			if String(name) == String(candidate):
				return String(name)
	for candidate in wanted:
		var needle := String(candidate).to_lower()
		for name in names:
			if String(name).to_lower().find(needle) != -1:
				return String(name)
	return ""

## What the body should be doing this frame.
func drive(speed: float, stance: int, airborne: bool, rising: bool) -> void:
	if _player == null or _one_shot != "":
		return

	var role := "idle"
	if airborne:
		role = "jump_rise" if rising else "jump_fall"
	elif stance == 2:
		role = "prone_move" if speed > 0.4 else "prone_idle"
	elif stance == 1:
		role = "crouch_walk" if speed > 0.4 else "crouch_idle"
	elif speed > SPRINT_SPEED:
		role = "sprint"
	elif speed > WALK_SPEED:
		role = "jog"
	elif speed > 0.4:
		role = "walk"

	_play_loop(String(_available.get(role, "")))

	# A walk clip authored at one speed looks wrong at another, so the playback
	# rate follows the actual pace rather than the animation dictating it.
	if role in ["walk", "jog", "sprint", "crouch_walk", "prone_move"]:
		_player.speed_scale = clampf(speed / 4.4, 0.65, 1.75)
	else:
		_player.speed_scale = 1.0

func _play_loop(clip: String) -> void:
	if clip == "" or _loop == clip:
		return
	_loop = clip
	_player.play(clip, BLEND)

## A shot, a reload or a flinch, over whatever is looping.
func fire_once(role: String) -> void:
	if _player == null:
		return
	var clip := String(_available.get(role, ""))
	if clip == "":
		return
	_one_shot = clip
	_loop = ""
	_player.speed_scale = 1.0
	_player.play(clip, 0.08)
	if not _player.animation_finished.is_connected(_on_finished):
		_player.animation_finished.connect(_on_finished)

func _on_finished(clip: StringName) -> void:
	if String(clip) == _one_shot:
		_one_shot = ""
