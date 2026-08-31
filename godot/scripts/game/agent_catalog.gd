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
		"model_hint": "universal", "weapon": "m4a4", "sidearm": "sidearm",
	},
	{
		"id": "spectre", "name": "Spectre", "role": "Recon",
		"blurb": "Silent flanker. Fastest boots in the squad.",
		"health": 100.0, "speed": 8.2, "accent": Color("#B58CFF"),
		"model_hint": "universal", "weapon": "smg", "sidearm": "machinepistol",
	},
	{
		"id": "forge", "name": "Forge", "role": "Engineer",
		"blurb": "Holds ground. Deploys cover and repairs armour.",
		"health": 100.0, "speed": 6.9, "accent": Color("#FFB23B"),
		"model_hint": "universal", "weapon": "ak47", "sidearm": "revolver",
	},
	{
		"id": "reaper", "name": "Reaper", "role": "Marksman",
		"blurb": "One breath, one shot. Devastating at range.",
		"health": 100.0, "speed": 7.2, "accent": Color("#FF4D5E"),
		"model_hint": "universal", "weapon": "awp", "sidearm": "sidearm",
	},
]

## The armoury.
##
## `model_hint` matches a filename in the weapons folder; `model_rotation` and
## `model_offset` correct for the way each one was authored, since the supplied
## models come from four different tools and none of them agree on which way is
## forward. Damage is a fifth of a life for the ordinary guns, so five rounds
## kill, and half a life for the marksman rifle.
const WEAPONS := [
	{
		"id": "m4a4", "name": "M4A4", "class": "Assault rifle",
		"damage": 20.0, "rate": 9.0, "spread": 0.013, "clip": 30, "reserve": 180,
		"reload": 1.7, "range": 130.0, "kick": 1.1,
		"model_hint": "m4a4", "model_size": 0.78,
		"model_rotation": Vector3(0, 90, 0), "tint": Color("#4A5560"),
		"voice": "blaster", "slot": "primary",
	},
	{
		"id": "ak47", "name": "AK-47", "class": "Assault rifle",
		"damage": 20.0, "rate": 7.4, "spread": 0.018, "clip": 30, "reserve": 180,
		"reload": 1.9, "range": 120.0, "kick": 1.5,
		"model_hint": "ak47", "model_size": 0.82,
		"model_rotation": Vector3(0, 90, 0), "tint": Color("#6E4526"),
		"voice": "ak47", "slot": "primary",
	},
	{
		"id": "awp", "name": "AWP", "class": "Marksman rifle",
		"damage": 50.0, "rate": 1.1, "spread": 0.002, "clip": 6, "reserve": 36,
		"reload": 2.6, "range": 280.0, "kick": 3.6,
		"model_hint": "awp", "model_size": 0.98,
		"model_rotation": Vector3(0, 90, 0), "tint": Color("#8A6A2A"),
		"voice": "sniper", "slot": "primary",
	},
	{
		"id": "smg", "name": "Wasp SMG", "class": "Submachine gun",
		"damage": 20.0, "rate": 13.0, "spread": 0.028, "clip": 35, "reserve": 210,
		"reload": 1.4, "range": 62.0, "kick": 0.85,
		"model_hint": "pack04", "model_size": 0.46,
		"tint": Color("#5B4E7A"), "voice": "blaster_repeater", "slot": "primary",
	},
	{
		"id": "shotgun", "name": "Breaker 12", "class": "Shotgun",
		"damage": 20.0, "rate": 1.9, "spread": 0.070, "clip": 8, "reserve": 56,
		"reload": 2.6, "range": 28.0, "kick": 3.1,
		"model_hint": "pack08", "model_size": 0.70,
		"tint": Color("#7A4A22"), "voice": "shotgun", "slot": "primary",
	},
	{
		"id": "sidearm", "name": "Vex 9", "class": "Sidearm",
		"damage": 20.0, "rate": 5.5, "spread": 0.020, "clip": 15, "reserve": 90,
		"reload": 1.2, "range": 48.0, "kick": 1.0,
		"model_hint": "pack01", "model_size": 0.28,
		"tint": Color("#3E4A57"), "voice": "pistol", "slot": "secondary",
	},
	{
		"id": "revolver", "name": "Ranger .44", "class": "Revolver",
		"damage": 34.0, "rate": 2.4, "spread": 0.014, "clip": 6, "reserve": 42,
		"reload": 2.2, "range": 70.0, "kick": 2.6,
		"model_hint": "pack02", "model_size": 0.32,
		"tint": Color("#5A4632"), "voice": "pistol", "slot": "secondary",
	},
	{
		"id": "machinepistol", "name": "Hornet", "class": "Machine pistol",
		"damage": 15.0, "rate": 15.0, "spread": 0.042, "clip": 20, "reserve": 140,
		"reload": 1.3, "range": 36.0, "kick": 0.7,
		"model_hint": "pack06", "model_size": 0.34,
		"tint": Color("#44505A"), "voice": "smg", "slot": "secondary",
	},
]

## Which weapons can go in which hand.
static func weapons_for_slot(slot: String) -> Array:
	var found: Array = []
	for entry in WEAPONS:
		if String(entry.get("slot", "primary")) == slot:
			found.append(entry)
	return found



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
