class_name AgentCatalog
extends RefCounted
## The playable roster and the weapon each one carries.
##
## Plain data rather than resources so it stays diffable in git and costs nothing
## in the export. `model_hint` and `weapon_hint` are matched against the filenames
## in the CC0 kits, which lets the pack change without touching this table.

const AGENTS := [
	{
		"id": "vanguard", "name": "Vanguard", "role": "Assault",
		"blurb": "Front-line breacher. Trades range for raw pressure.",
		"health": 100.0, "speed": 7.4, "accent": Color("#3BE8FF"),
		"model_hint": "soldier", "weapon": "carbine",
	},
	{
		"id": "spectre", "name": "Spectre", "role": "Recon",
		"blurb": "Silent flanker. Fastest boots in the squad.",
		"health": 100.0, "speed": 8.2, "accent": Color("#B58CFF"),
		"model_hint": "soldier", "weapon": "smg",
	},
	{
		"id": "forge", "name": "Forge", "role": "Engineer",
		"blurb": "Holds ground. Deploys cover and repairs armour.",
		"health": 100.0, "speed": 6.9, "accent": Color("#FFB23B"),
		"model_hint": "soldier", "weapon": "shotgun",
	},
	{
		"id": "reaper", "name": "Reaper", "role": "Marksman",
		"blurb": "One breath, one shot. Devastating at range.",
		"health": 100.0, "speed": 7.2, "accent": Color("#FF4D5E"),
		"model_hint": "soldier", "weapon": "sniper",
	},
]

const WEAPONS := [
	{
		"id": "carbine", "name": "MK-7 Carbine", "class": "Assault rifle",
		"damage": 20.0, "rate": 8.5, "spread": 0.014, "clip": 30, "reserve": 180,
		"reload": 1.7, "range": 120.0, "kick": 1.15,
		"model_hint": "blasterD", "voice": "rifle",
	},
	{
		"id": "smg", "name": "Wasp SMG", "class": "Submachine gun",
		"damage": 20.0, "rate": 13.0, "spread": 0.028, "clip": 35, "reserve": 210,
		"reload": 1.4, "range": 62.0, "kick": 0.85,
		"model_hint": "blasterE", "voice": "smg",
	},
	{
		"id": "shotgun", "name": "Breaker 12", "class": "Shotgun",
		"damage": 20.0, "rate": 1.9, "spread": 0.070, "clip": 8, "reserve": 56,
		"reload": 2.6, "range": 28.0, "kick": 3.1,
		"model_hint": "blasterB", "voice": "shotgun",
	},
	{
		"id": "sniper", "name": "Longshot", "class": "Marksman rifle",
		"damage": 50.0, "rate": 1.1, "spread": 0.002, "clip": 6, "reserve": 36,
		"reload": 2.4, "range": 260.0, "kick": 3.6,
		"model_hint": "blasterK", "voice": "sniper",
	},
	{
		"id": "sidearm", "name": "Vex 9", "class": "Sidearm",
		"damage": 20.0, "rate": 5.5, "spread": 0.020, "clip": 15, "reserve": 90,
		"reload": 1.2, "range": 48.0, "kick": 1.0,
		"model_hint": "blasterA", "voice": "pistol",
	},
]

static func agent(id: String) -> Dictionary:
	for entry in AGENTS:
		if entry["id"] == id:
			return entry
	return AGENTS[0]

static func weapon(id: String) -> Dictionary:
	for entry in WEAPONS:
		if entry["id"] == id:
			return entry
	return WEAPONS[0]

static func agent_index(id: String) -> int:
	for i in AGENTS.size():
		if AGENTS[i]["id"] == id:
			return i
	return 0
