class_name LobbyManager
extends Node
## Room lobby (§26): player list (avatar initial, name, ready, fighter),
## host controls mode/map/rounds/start. Reads NetworkManager.players;
## offline it runs a 2-slot local lobby (player + bot) so the same UI
## and ready-check path is exercised without network.

signal lobby_changed
signal match_startable(can_start: bool, reason: String)

var slots: Array[Dictionary] = []
var mode: String = "1v1_bot"
var arena_id: String = "volcano"
var rounds_to_win: int = 2


func _ready() -> void:
	reset_offline()


func reset_offline() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var lm := get_node_or_null("/root/LocalizationManager")
	var nm := str(sm.profile.get("name", "Player")) if sm else "Player"
	var bot_label: String = lm.tr_key("vs_bot") if lm else "Bot"
	slots = [
		{"name": nm, "fighter": "fire", "ready": true, "is_bot": false},
		{"name": bot_label, "fighter": "fire", "ready": true, "is_bot": true},
	]
	lobby_changed.emit()


func refresh_from_network() -> void:
	var net := get_node_or_null("/root/NetworkManager")
	if net == null or net.players.is_empty():
		return
	slots.clear()
	for id in net.players.keys():
		var p: Dictionary = net.players[id]
		slots.append({"name": str(p.get("name", "")), "fighter": str(p.get("fighter", "fire")),
			"ready": bool(p.get("ready", false)), "is_bot": false, "peer": id})
	lobby_changed.emit()


func set_fighter(slot: int, fighter_id: String) -> void:
	if slot >= 0 and slot < slots.size():
		slots[slot]["fighter"] = fighter_id
		lobby_changed.emit()


func set_ready(slot: int, ready: bool) -> void:
	if slot >= 0 and slot < slots.size():
		slots[slot]["ready"] = ready
		lobby_changed.emit()


func check_start() -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	if slots.size() < 2:
		match_startable.emit(false, lm.tr_key("err_match_cant_start") if lm else "need players")
		return
	for s in slots:
		if not bool(s.get("ready", false)):
			match_startable.emit(false, lm.tr_key("err_match_cant_start") if lm else "not ready")
			return
	match_startable.emit(true, "")
