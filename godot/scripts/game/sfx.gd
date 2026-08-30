extends Node
## Plays the game's sounds. Registered as the `Sfx` autoload.
##
## The clips are synthesised by tools/make_sounds.py during the build rather
## than shipped as recordings, so there is nothing to license and nothing to
## keep in the repository — and the game still runs, silently, when they are
## missing.

const DIRECTORY := "res://assets/audio/"
const VOICES := ["rifle", "smg", "shotgun", "sniper", "pistol", "explosion",
	"reload", "empty"]

var _clips: Dictionary = {}            # name -> AudioStream

func _ready() -> void:
	for name in VOICES:
		var path := DIRECTORY + name + ".wav"
		if ResourceLoader.exists(path):
			var clip := load(path)
			if clip is AudioStream:
				_clips[name] = clip
	print("[sfx] %d of %d clips loaded" % [_clips.size(), VOICES.size()])

func has(name: String) -> bool:
	return _clips.has(name)

## Plays a clip in the world, so distance and direction are audible. The player
## is freed once the clip finishes, which keeps rapid fire from piling up nodes.
func play_at(where: Node3D, name: String, volume := 1.0, pitch := 1.0) -> void:
	if not _clips.has(name) or where == null or not where.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = _clips[name]
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
func play(name: String, volume := 1.0, pitch := 1.0) -> void:
	if not _clips.has(name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _clips[name]
	player.volume_db = linear_to_db(clampf(volume, 0.01, 4.0))
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
