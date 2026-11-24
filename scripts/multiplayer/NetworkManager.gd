class_name DraaNetwork
extends Node
## DRAA NetworkManager (autoload, §27). Real ENet room layer:
## host_room() -> 6-digit code, join_room(code, ip) connects.
## Gameplay logic never touches ENet directly — it talks to
## LobbyManager/MatchManager. Offline + LAN work today; WAN relay and
## server-authoritative validation plug in here without API change.
## Damage is NEVER applied from a remote damage report without a
## distance/facing sanity check (see validate_hit()).

signal room_created(code: String)
signal joined_room(code: String)
signal connection_failed(reason: String)
signal player_joined(peer_id: int)
signal player_left(peer_id: int)

var peer: ENetMultiplayerPeer
var room_code: String = ""
var is_host: bool = false
var players: Dictionary = {} # peer_id -> {name, fighter, ready}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit("connection_failed"))
	multiplayer.server_disconnected.connect(_on_server_lost)


func make_code() -> String:
	return "%06d" % randi_range(100000, 999999)


func port_for(code: String) -> int:
	return 27000 + (abs(hash(code)) % 5000)


func host_room(host_name: String = "") -> String:
	close()
	room_code = make_code()
	is_host = true
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port_for(room_code), 8)
	if err != OK:
		room_code = ""
		connection_failed.emit("err_match_cant_start")
		return ""
	multiplayer.multiplayer_peer = peer
	var nm := host_name
	if nm.is_empty():
		var sm := get_node_or_null("/root/SaveManager")
		nm = str(sm.profile.get("name", "Player")) if sm else "Player"
	players[1] = {"name": nm, "fighter": "fire", "ready": true}
	room_created.emit(room_code)
	return room_code


func join_room(code: String, host_ip: String = "127.0.0.1") -> void:
	close()
	room_code = code.strip_edges()
	is_host = false
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(host_ip, port_for(room_code))
	if err != OK:
		connection_failed.emit("err_no_room")
		return
	multiplayer.multiplayer_peer = peer
	# ENet connects async; joined_room fires in _on_peer_connected on host
	# side and via connected_to_server here:
	multiplayer.connected_to_server.connect(_on_connected_once, CONNECT_ONE_SHOT)


func _on_connected_once() -> void:
	joined_room.emit(room_code)


func close() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	players.clear()
	room_code = ""
	is_host = false


func _on_peer_connected(id: int) -> void:
	players[id] = {"name": "Player %d" % id, "fighter": "fire", "ready": false}
	player_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_left.emit(id)


func _on_server_lost() -> void:
	# §45: never freeze — caller swaps the leaver for a bot.
	connection_failed.emit("net_disconnected")
	close()


func set_local_ready(ready: bool) -> void:
	var mine := multiplayer.get_unique_id()
	if players.has(mine):
		players[mine]["ready"] = ready
		_sync_lobby.rpc(players)


@rpc("any_peer", "call_local", "reliable")
func _sync_lobby(state: Dictionary) -> void:
	players = state


## Server-side sanity gate for future authoritative combat: clamps
## impossible reports (range / facing / cooldown) instead of trusting them.
static func validate_hit(reporter_pos: Vector3, victim_pos: Vector3, facing: Vector3, max_range: float, cooldown_ok: bool) -> bool:
	if not cooldown_ok:
		return false
	var to: Vector3 = victim_pos - reporter_pos
	to.y = 0.0
	if to.length() > max_range + 1.0: # 1m tolerance for latency
		return false
	var f := facing
	f.y = 0.0
	if f.length() < 0.01:
		return false
	return f.normalized().dot(to.normalized()) > 0.0
