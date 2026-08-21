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
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, 42, 0)
	light.light_color = Color(1.0, 0.88, 0.74)
	light.light_energy = 1.9
	light.shadow_enabled = true
	add_child(light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16, -128, 0)
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.light_energy = 0.7
	fill.shadow_enabled = false
	add_child(fill)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.10, 0.16, 0.28)
	sky_material.sky_horizon_color = Color(0.28, 0.30, 0.34)
	sky_material.ground_bottom_color = Color(0.04, 0.05, 0.07)
	sky_material.ground_horizon_color = Color(0.18, 0.19, 0.22)
	environment.sky.sky_material = sky_material

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 2.2
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.20, 0.28)
	environment.fog_density = 0.0035
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.5

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

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
		body.global_transform = city.spawn_for(index, int(wanted[peer_id].get("team", 1)))
		NetGame.remote_players[peer_id] = body
		index += 1
