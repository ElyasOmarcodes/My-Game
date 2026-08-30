extends Node
## Plays the game's sounds. Registered as the `Sfx` autoload.
##
## The clips are synthesised by tools/make_sounds.py during the build rather
## than shipped as recordings, so there is nothing to license and nothing to
## keep in the repository — and the game still runs, silently, when they are
## missing.

const DIRECTORY := "res://assets/audio/"

var _clips: Dictionary = {}            # name -> AudioStream

## Scans the audio folder rather than naming files, so a recording that the
## build fetched and one this project synthesised are picked up the same way.
func _ready() -> void:
	var folder := DirAccess.open(DIRECTORY)
	if folder == null:
		print("[sfx] no audio folder — the game runs silent")
		return

	for file in folder.get_files():
		var name := String(file).trim_suffix(".remap").trim_suffix(".import")
		if not (name.ends_with(".wav") or name.ends_with(".ogg")):
			continue
		var path := DIRECTORY + name
		if not ResourceLoader.exists(path):
			continue
		var clip: Resource = load(path)
		if clip is AudioStream:
			_clips[name.get_basename()] = clip

	print("[sfx] %d clips: %s" % [_clips.size(),
		", ".join(PackedStringArray(_clips.keys()))])

## Recordings are fetched and can be absent; the synthesised set always ships.
## A weapon names its recording first and its fallback second.
const FALLBACKS := {
	"blaster": "rifle",
	"blaster_repeater": "smg",
	"ak47": "ak47",
}

func has(clip_name: String) -> bool:
	return _clips.has(clip_name)

func _resolve(clip_name: String) -> String:
	if _clips.has(clip_name):
		return clip_name
	var fallback := String(FALLBACKS.get(clip_name, ""))
	return fallback if _clips.has(fallback) else ""

## Plays a clip in the world, so distance and direction are audible. The player
## is freed once the clip finishes, which keeps rapid fire from piling up nodes.
func play_at(where: Node3D, clip_name: String, volume := 1.0, pitch := 1.0) -> void:
	clip_name = _resolve(clip_name)
	if clip_name == "" or where == null or not where.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = _clips[clip_name]
	player.unit_size = 14.0
	player.max_distance = 140.0
	player.volume_db = linear_to_db(clampf(volume, 0.01, 4.0))
	player.pitch_scale = pitch
	# Parented to the world rather than to the emitter, so a clip outlives the
	# grenade that made it.
	var host := where.get_tree().current_scene
	if host == null:
		host = where.get_parent()
	if host == null:
		return
	host.add_child(player)
	player.global_position = where.global_position
	player.play()
	player.finished.connect(player.queue_free)

## Plays without a position — for the local player's own weapon, which should
## sound the same wherever they are standing.
func play(clip_name: String, volume := 1.0, pitch := 1.0) -> void:
	clip_name = _resolve(clip_name)
	if clip_name == "":
		return
	var player := AudioStreamPlayer.new()
	player.stream = _clips[clip_name]
	player.volume_db = linear_to_db(clampf(volume, 0.01, 4.0))
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
