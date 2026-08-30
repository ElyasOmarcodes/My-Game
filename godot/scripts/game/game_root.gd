extends Node3D
## Entry point. Shows the menu, then builds and runs a match.
##
## Scene content is deliberately minimal — this node is the whole .tscn. The
## world is assembled here from the CC0 kits at runtime, which keeps the
## repository free of hand-edited scene files and lets the art be swapped
## without touching a single scene.

var library: AssetLibrary
var city: CityBuilder
var hud: Hud
var menu: MainMenu
var local_player: Player

func _ready() -> void:
	_build_environment()
	_show_menu()

	NetGame.match_started.connect(_on_match_started)
	NetGame.roster_changed.connect(_on_roster_changed)

func _build_environment() -> void:
	WorldLook.apply(self)

func _show_menu() -> void:
	menu = MainMenu.new()
	menu.host_requested.connect(_on_host)
	menu.join_requested.connect(_on_join)
	menu.solo_requested.connect(_on_solo)
	add_child(menu)

func _clear_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null

# --- entry points -------------------------------------------------------------

func _on_host(room_name: String) -> void:
	if not NetGame.host(room_name, "Kandahar Town", Session.Mode.TEAM_DEATHMATCH):
		return
	_clear_menu()
	_start_match(Session.map_seed)
	if hud:
		hud.flash("HOSTING · %s · %s" % [room_name, Lan.local_ip()], 4.0)

func _on_join(address: String) -> void:
	if not NetGame.join(address):
		return
	_clear_menu()
	# The host answers with the seed; the match starts when that arrives.

func _on_solo() -> void:
	Session.map_seed = randi()
	_clear_menu()
	_start_match(Session.map_seed)

func _on_match_started(map_seed: int) -> void:
	if city == null:
		_start_match(map_seed)

func _on_roster_changed() -> void:
	if city == null:
		return
	_sync_remote_players()

# --- match --------------------------------------------------------------------

func _start_match(map_seed: int) -> void:
	library = AssetLibrary.new(map_seed)

	city = CityBuilder.new()
	add_child(city)
	city.spawns_ready.connect(_on_spawns_ready)
	city.build(library, map_seed)

	local_player = Player.create(library, Session.agent_id, Session.team,
		Session.player_id, true)
	add_child(local_player)
	local_player.global_transform = city.spawn_for(0, Session.team)
	NetGame.local_player = local_player

	hud = Hud.new()
	add_child(hud)
	hud.bind(local_player)

	if not library.loaded:
		hud.flash("Art kits not bundled — running on placeholders", 5.0)

	_sync_remote_players()

## A supplied map's floor only exists once physics has seen it, so the spawns
## are provisional until then and everyone is re-seated when they firm up.
func _on_spawns_ready() -> void:
	if local_player:
		local_player.global_transform = city.spawn_for(0, Session.team)
	var index := 1
	for peer_id in NetGame.remote_players:
		var body: Node = NetGame.remote_players[peer_id]
		if body is RemotePlayer:
			(body as RemotePlayer).place(city.spawn_for(index, Session.Team.BRAVO))
		index += 1

func _sync_remote_players() -> void:
	var wanted: Dictionary = {}
	for peer_id in NetGame.players:
		var entry: Dictionary = NetGame.players[peer_id]
		if String(entry.get("id", "")) == Session.player_id:
			continue
		wanted[peer_id] = entry

	for peer_id in NetGame.remote_players.keys():
		if not wanted.has(peer_id):
			var stale: Node = NetGame.remote_players[peer_id]
			if is_instance_valid(stale):
				stale.queue_free()
			NetGame.remote_players.erase(peer_id)

	var index := 1
	for peer_id in wanted:
		if NetGame.remote_players.has(peer_id):
			continue
		var body := RemotePlayer.create(library, wanted[peer_id])
		add_child(body)
		body.place(city.spawn_for(index, int(wanted[peer_id].get("team", 1))))
		NetGame.remote_players[peer_id] = body
		index += 1
