class_name AssetLibrary
extends RefCounted
## Looks up the CC0 model kits the build fetched into res://assets.
##
## The kits are downloaded during the build rather than committed, so the game
## cannot assume any particular file is present. `tools/fetch_assets.sh` writes a
## manifest next to them; this reads it and hands back PackedScenes by category.
## When a category is missing the caller gets null and falls back to primitives,
## which keeps the project runnable before the assets have ever been fetched.

const MANIFEST_PATH := "res://assets/manifest.json"

var _catalog: Dictionary = {}          # category -> Array[String] of resource paths
var _cache: Dictionary = {}            # resource path -> PackedScene
var _rng := RandomNumberGenerator.new()

var loaded: bool = false
var attribution: String = ""

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value
	_load_manifest()

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("[assets] no manifest at %s — falling back to primitives" % MANIFEST_PATH)
		return

	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[assets] manifest is not an object")
		return

	attribution = String(parsed.get("attribution", ""))
	var categories = parsed.get("categories", {})
	if typeof(categories) == TYPE_DICTIONARY:
		for key in categories:
			var entries: Array = []
			for path in categories[key]:
				if ResourceLoader.exists(String(path)):
					entries.append(String(path))
			if not entries.is_empty():
				_catalog[key] = entries

	loaded = not _catalog.is_empty()
	print("[assets] %d categories, %d models" % [_catalog.size(), count()])

func count() -> int:
	var total := 0
	for key in _catalog:
		total += _catalog[key].size()
	return total

func has(category: String) -> bool:
	return _catalog.has(category) and not _catalog[category].is_empty()

func paths(category: String) -> Array:
	return _catalog.get(category, [])

## A deterministic pick, so the same seed lays out the same city everywhere.
func pick(category: String, index: int) -> PackedScene:
	if not has(category):
		return null
	var entries: Array = _catalog[category]
	return _load(entries[abs(index) % entries.size()])

func random(category: String) -> PackedScene:
	if not has(category):
		return null
	var entries: Array = _catalog[category]
	return _load(entries[_rng.randi() % entries.size()])

## Finds the first model in a category whose filename contains `needle`.
func find(category: String, needle: String) -> PackedScene:
	var lowered := needle.to_lower()
	for path in paths(category):
		if path.get_file().to_lower().find(lowered) != -1:
			return _load(path)
	return null

func instantiate(category: String, index: int) -> Node3D:
	var scene := pick(category, index)
	return scene.instantiate() if scene else null

func _load(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var scene := load(path) as PackedScene
	if scene:
		_cache[path] = scene
	return scene
