extends Node
## Zero-configuration room discovery over Wi-Fi, registered as the `Lan` autoload.
##
## The host broadcasts a small JSON beacon once a second on UDP 47777; clients
## listen on the same port and keep a live room list. No server, no internet, no
## account — just the router everyone is already joined to. The wire format is
## unchanged from the earlier builds, so older clients still see these rooms.

signal rooms_changed(rooms: Array)

const BEACON_INTERVAL := 1.0
const ROOM_TIMEOUT := 4.0

var _beacon_socket: PacketPeerUDP
var _listen_socket: PacketPeerUDP
var _beacon: Dictionary = {}
var _rooms: Dictionary = {}          # room_id -> room dictionary
var _next_beacon_at := 0.0

var advertising := false
var scanning := false

func _process(_delta: float) -> void:
	if scanning:
		_drain_listener()
		_expire_rooms()
	if advertising and Time.get_ticks_msec() / 1000.0 >= _next_beacon_at:
		_next_beacon_at = Time.get_ticks_msec() / 1000.0 + BEACON_INTERVAL
		_send_beacon()

# --- host side ---------------------------------------------------------------

func start_advertising(room_name: String, map_name: String, mode: int, max_players: int) -> void:
	stop_advertising()

	_beacon = {
		"proto": Session.PROTOCOL,
		"roomId": "%s-%d" % [Session.player_id, Time.get_ticks_msec()],
		"roomName": room_name,
		"hostName": Session.display_name,
		"port": Session.GAME_PORT,
		"players": 1,
		"maxPlayers": max_players,
		"mode": mode,
		"map": map_name,
		"locked": false,
	}

	_beacon_socket = PacketPeerUDP.new()
	_beacon_socket.set_broadcast_enabled(true)
	advertising = true
	_next_beacon_at = 0.0

func update_player_count(count: int) -> void:
	if not _beacon.is_empty():
		_beacon["players"] = count

func stop_advertising() -> void:
	advertising = false
	if _beacon_socket:
		_beacon_socket.close()
		_beacon_socket = null

func _send_beacon() -> void:
	if _beacon_socket == null:
		return
	var payload := JSON.stringify(_beacon).to_utf8_buffer()
	for address in _broadcast_addresses():
		_beacon_socket.set_dest_address(address, Session.DISCOVERY_PORT)
		_beacon_socket.put_packet(payload)

## Directed broadcast per interface. 255.255.255.255 is dropped by a fair number
## of consumer routers, so the subnet address is the address that actually works.
func _broadcast_addresses() -> Array:
	var addresses: Array = ["255.255.255.255"]
	for ip in IP.get_local_addresses():
		if ip.begins_with("127.") or ip.find(":") != -1:
			continue
		var parts := ip.split(".")
		if parts.size() == 4:
			addresses.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	return addresses

# --- client side --------------------------------------------------------------

func start_scanning() -> void:
	if scanning:
		return
	_rooms.clear()
	_listen_socket = PacketPeerUDP.new()
	var error := _listen_socket.bind(Session.DISCOVERY_PORT, "*")
	if error != OK:
		push_warning("[LAN] cannot bind udp/%d: %d" % [Session.DISCOVERY_PORT, error])
		_listen_socket = null
		return
	_listen_socket.set_broadcast_enabled(true)
	scanning = true

func stop_scanning() -> void:
	scanning = false
	if _listen_socket:
		_listen_socket.close()
		_listen_socket = null

func _drain_listener() -> void:
	if _listen_socket == null:
		return
	while _listen_socket.get_available_packet_count() > 0:
		var raw := _listen_socket.get_packet().get_string_from_utf8()
		var sender := _listen_socket.get_packet_ip()
		_on_beacon(raw, sender)

func _on_beacon(raw: String, sender_ip: String) -> void:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.get("proto", "") != Session.PROTOCOL:
		return
	# Our own beacon comes back to us on the broadcast; ignore it.
	if advertising and parsed.get("roomId", "") == _beacon.get("roomId", ""):
		return

	parsed["hostAddress"] = sender_ip
	parsed["seenAt"] = Time.get_ticks_msec() / 1000.0
	_rooms[parsed.get("roomId", sender_ip)] = parsed
	rooms_changed.emit(rooms())

func _expire_rooms() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dropped := false
	for id in _rooms.keys():
		if now - float(_rooms[id].get("seenAt", 0.0)) > ROOM_TIMEOUT:
			_rooms.erase(id)
			dropped = true
	if dropped:
		rooms_changed.emit(rooms())

func rooms() -> Array:
	return _rooms.values()

func local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("127.") or ip.find(":") != -1:
			continue
		if ip.begins_with("169.254."):
			continue
		return ip
	return "0.0.0.0"
