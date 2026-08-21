extends Node
## In-match replication over ENet, registered as the `NetGame` autoload.
##
## Movement is client-authoritative — it has to be, or a phone on Wi-Fi feels
## like it is wading through treacle — while damage is resolved on the host, so
## the worst a bad client can do is misplace itself, not invent kills.
## Transforms go out unreliably twenty times a second: a lost packet is replaced
## by the next one 50 ms later, and resending it would only add latency.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal match_started(map_seed: int)
signal roster_changed

const SEND_INTERVAL := 0.05

var peer: ENetMultiplayerPeer
var is_host := false
var connected := false

## peer_id -> { id, name, agent, team, ready }
var players: Dictionary = {}
var _health: Dictionary = {}           # player_id -> float
var _send_accumulator := 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- lifecycle ----------------------------------------------------------------

func host(room_name: String, map_name: String, mode: int) -> bool:
	shutdown()

	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(Session.GAME_PORT, Session.MAX_PLAYERS)
	if error != OK:
		push_error("[net] cannot host on %d: %d" % [Session.GAME_PORT, error])
		return false

	multiplayer.multiplayer_peer = peer
	is_host = true
	connected = true

	Session.is_host = true
	Session.room_name = room_name
	Session.map_name = map_name
	Session.mode = mode
	Session.map_seed = randi()

	players[1] = Session.local_entry()
	Lan.start_advertising(room_name, map_name, mode, Session.MAX_PLAYERS)
	roster_changed.emit()
	return true

func join(address: String) -> bool:
	shutdown()

	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, Session.GAME_PORT)
	if error != OK:
		push_error("[net] cannot reach %s: %d" % [address, error])
		return false

	multiplayer.multiplayer_peer = peer
	is_host = false
	Session.is_host = false
	return true

func shutdown() -> void:
	Lan.stop_advertising()
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	players.clear()
	_health.clear()
	connected = false
	is_host = false

# --- signals ------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	# The newcomer needs the full picture; everyone else just needs the newcomer.
	_push_roster.rpc_id(peer_id, players, Session.map_seed, Session.map_name, Session.mode)
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	Lan.update_player_count(players.size())
	roster_changed.emit()
	peer_left.emit(peer_id)
	if is_host:
		_push_roster.rpc(players, Session.map_seed, Session.map_name, Session.mode)

func _on_connected() -> void:
	connected = true
	_announce.rpc_id(1, Session.local_entry())

func _on_connection_failed() -> void:
	connected = false
	push_warning("[net] connection failed")

func _on_server_disconnected() -> void:
	connected = false
	shutdown()

# --- roster -------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _announce(entry: Dictionary) -> void:
	if not is_host:
		return
	players[multiplayer.get_remote_sender_id()] = entry
	_health[String(entry.get("id", ""))] = 100.0
	Lan.update_player_count(players.size())
	roster_changed.emit()
	_push_roster.rpc(players, Session.map_seed, Session.map_name, Session.mode)

@rpc("authority", "reliable", "call_local")
func _push_roster(roster: Dictionary, map_seed: int, map_name: String, mode: int) -> void:
	players = roster
	Session.map_seed = map_seed
	Session.map_name = map_name
	Session.mode = mode
	roster_changed.emit()

func start_match() -> void:
	if not is_host:
		return
	_begin_match.rpc(Session.map_seed)

@rpc("authority", "reliable", "call_local")
func _begin_match(map_seed: int) -> void:
	Session.map_seed = map_seed
	match_started.emit(map_seed)

# --- transforms ---------------------------------------------------------------

var local_player: Node3D
var remote_players: Dictionary = {}     # peer_id -> Node3D

func _process(delta: float) -> void:
	if not connected or local_player == null:
		return
	_send_accumulator += delta
	if _send_accumulator < SEND_INTERVAL:
		return
	_send_accumulator = 0.0

	_move.rpc(local_player.global_position, local_player.rotation.y)

@rpc("any_peer", "unreliable_ordered")
func _move(position: Vector3, yaw: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var body: Node3D = remote_players.get(sender)
	if body:
		body.set_meta("target_position", position)
		body.set_meta("target_yaw", yaw)

# --- damage -------------------------------------------------------------------

## Called by the local weapon when its ray lands on someone. The host has the
## final say; a client only ever asks.
func report_hit(victim_id: String, damage: float) -> void:
	if not connected:
		# Solo drill: no host to ask, so resolve it here.
		_apply_damage(victim_id, damage, Session.player_id)
		return
	_damage_request.rpc_id(1, victim_id, damage)

@rpc("any_peer", "reliable")
func _damage_request(victim_id: String, damage: float) -> void:
	if not is_host:
		return
	var attacker := _player_id_for(multiplayer.get_remote_sender_id())
	_apply_damage(victim_id, damage, attacker)
	_damage_applied.rpc(victim_id, damage, attacker)

@rpc("authority", "reliable")
func _damage_applied(victim_id: String, damage: float, attacker_id: String) -> void:
	_apply_damage(victim_id, damage, attacker_id)

func _apply_damage(victim_id: String, damage: float, attacker_id: String) -> void:
	if victim_id == Session.player_id and local_player and local_player.has_method("apply_damage"):
		local_player.apply_damage(damage, attacker_id)

func _player_id_for(peer_id: int) -> String:
	var entry: Dictionary = players.get(peer_id, {})
	return String(entry.get("id", ""))
