extends Node
## Everything that outlives a single screen: who the player is, which room they
## are in, and what the match is set to. Registered as the `Session` autoload.

const PROTOCOL := "BOA1"
const DISCOVERY_PORT := 47777
const GAME_PORT := 47778
const MIN_PLAYERS := 2
const MAX_PLAYERS := 8

enum Team { NONE, ALPHA, BRAVO }
enum Mode { TEAM_DEATHMATCH, FREE_FOR_ALL, DOMINATION }

var player_id: String = ""
var display_name: String = "Agent"
var agent_id: String = "vanguard"
var team: int = Team.ALPHA
var is_host: bool = false

var room_name: String = ""
var map_name: String = "Kandahar City"
var mode: int = Mode.TEAM_DEATHMATCH
var map_seed: int = 0

## playerId -> { name, agent, team, ready }
var roster: Dictionary = {}

func _ready() -> void:
	player_id = _stable_id()
	display_name = _load_name()

func _stable_id() -> String:
	# Reused across launches so a reconnecting phone keeps its slot.
	var stored: String = _prefs().get_value("identity", "player_id", "")
	if stored != "":
		return stored
	var fresh := "%08x%04x" % [Time.get_unix_time_from_system(), randi() % 65536]
	_write_pref("identity", "player_id", fresh)
	return fresh

func _load_name() -> String:
	var stored: String = _prefs().get_value("identity", "name", "")
	if stored != "":
		return stored
	var generated := "Agent-%03d" % (randi() % 900 + 100)
	_write_pref("identity", "name", generated)
	return generated

func set_display_name(value: String) -> void:
	if value.strip_edges() == "":
		return
	display_name = value.strip_edges()
	_write_pref("identity", "name", display_name)

func _prefs() -> ConfigFile:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	return config

func _write_pref(section: String, key: String, value) -> void:
	var config := _prefs()
	config.set_value(section, key, value)
	config.save("user://settings.cfg")

func get_pref(section: String, key: String, fallback):
	return _prefs().get_value(section, key, fallback)

func set_pref(section: String, key: String, value) -> void:
	_write_pref(section, key, value)

## Everyone the match should spawn, local player included.
func roster_entries() -> Array:
	var entries: Array = []
	for id in roster:
		var entry: Dictionary = roster[id].duplicate()
		entry["id"] = id
		entries.append(entry)
	entries.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return entries

func local_entry() -> Dictionary:
	return {
		"id": player_id,
		"name": display_name,
		"agent": agent_id,
		"team": team,
		"ready": true,
	}

func reset_room() -> void:
	roster.clear()
	is_host = false
	room_name = ""
