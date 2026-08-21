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
		"health": 120.0, "speed": 6.2, "accent": Color("#3BE8FF"),
		"model_hint": "knight", "weapon": "carbine",
	},
	{
		"id": "spectre", "name": "Spectre", "role": "Recon",
		"blurb": "Silent flanker. Fastest boots in the squad.",
		"health": 90.0, "speed": 7.4, "accent": Color("#B58CFF"),
		"model_hint": "rogue", "weapon": "smg",
	},
	{
		"id": "forge", "name": "Forge", "role": "Engineer",
		"blurb": "Holds ground. Deploys cover and repairs armour.",
		"health": 110.0, "speed": 5.6, "accent": Color("#FFB23B"),
		"model_hint": "barbarian", "weapon": "shotgun",
	},
	{
		"id": "reaper", "name": "Reaper", "role": "Marksman",
		"blurb": "One breath, one shot. Devastating at range.",
		"health": 80.0, "speed": 6.0, "accent": Color("#FF4D5E"),
		"model_hint": "mage", "weapon": "sniper",
	},
]

const WEAPONS := [
	{
		"id": "carbine", "name": "MK-7 Carbine", "class": "Assault rifle",
		"damage": 22.0, "rate": 8.5, "spread": 0.016, "clip": 30, "reserve": 150,
		"reload": 1.7, "range": 110.0, "kick": 1.1, "model_hint": "blaster",
	},
	{
		"id": "smg", "name": "Wasp SMG", "class": "Submachine gun",
		"damage": 15.0, "rate": 14.0, "spread": 0.030, "clip": 35, "reserve": 175,
		"reload": 1.4, "range": 55.0, "kick": 0.8, "model_hint": "smg",
	},
	{
		"id": "sniper", "name": "Longbow DMR", "class": "Marksman rifle",
		"damage": 78.0, "rate": 1.4, "spread": 0.002, "clip": 6, "reserve": 36,
		"reload": 2.4, "range": 220.0, "kick": 3.4, "model_hint": "sniper",
	},
	{
		"id": "shotgun", "name": "Breaker 12", "class": "Shotgun",
		"damage": 14.0, "rate": 1.6, "spread": 0.075, "clip": 7, "reserve": 42,
		"reload": 2.8, "range": 26.0, "kick": 3.0, "model_hint": "shotgun",
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
