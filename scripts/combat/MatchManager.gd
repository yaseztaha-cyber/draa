class_name MatchManager
extends Node
## 1v1/2v2 match flow (§15): intro countdown, 90s rounds, best-of-3,
## KO / ring-out / timeout verdicts, team elimination for 2v2,
## results + XP. Works offline (vs bot) and over NetworkManager.

signal countdown_tick(text: String, final: bool)
signal timer_changed(seconds_left: float)
signal round_changed(round_index: int, p1_wins: int, p2_wins: int)
signal match_ended(player_won: bool)

const ROUND_TIME := 90.0
const WINS_NEEDED := 2

var fighters: Array[Fighter] = []
var spawns: Array[Vector3] = []
var round_index: int = 0
var team_wins := {0: 0, 1: 0}
var time_left: float = ROUND_TIME
var phase: String = "intro" # intro | fight | round_end | done
var _round_over: bool = false


func configure(p_fighters: Array[Fighter], p_spawns: Array[Vector3]) -> void:
	fighters = p_fighters
	spawns = p_spawns
	for f in fighters:
		f.died.connect(_on_fighter_died)


func start_match() -> void:
	round_index = 0
	team_wins = {0: 0, 1: 0}
	_start_round()


func _start_round() -> void:
	round_index += 1
	_round_over = false
	phase = "intro"
	_clean_roster()
	for i in fighters.size():
		if i < spawns.size():
			fighters[i].revive_full(spawns[i])
		else:
			fighters[i].revive_full(Vector3(i * 3.0, 0.5, 0))
	time_left = ROUND_TIME
	round_changed.emit(round_index, team_wins[0], team_wins[1])
	for f in fighters:
		f.set_frozen(true)
	await _run_countdown()
	for f in fighters:
		f.set_frozen(false)
	if phase == "intro":
		phase = "fight"


func _run_countdown() -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	var keys: Array[String] = ["count_3", "count_2", "count_1", "go"]
	for i in keys.size():
		var txt: String = lm.tr_key(keys[i]) if lm else keys[i]
		countdown_tick.emit(txt, i == keys.size() - 1)
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_countdown(i == keys.size() - 1)
		await get_tree().create_timer(0.7).timeout
		if phase != "intro":
			return


func _process(delta: float) -> void:
	if phase != "fight" or _round_over:
		return
	time_left -= delta
	timer_changed.emit(time_left)
	if time_left <= 0.0:
		_finish_round(-1) # timeout: judge by HP fraction


func _on_fighter_died(_f: Fighter, _killer: Node) -> void:
	if not is_instance_valid(_f) or _f.is_decoy:
		return # decoy pops never end rounds
	if phase != "fight" or _round_over:
		return
	if _is_team_mode():
		if _team_alive(0) == 0 or _team_alive(1) == 0:
			_finish_round(1 if _team_alive(1) > 0 else 0)
	else:
		# 1v1: round goes to the survivor's team.
		_finish_round(_f.team ^ 1 if _f.team in [0, 1] else 0)


func _is_team_mode() -> bool:
	var real := 0
	for f in fighters:
		if is_instance_valid(f) and not f.is_decoy:
			real += 1
	return real > 2


func _clean_roster() -> void:
	# Decoys live one round at most; drop the freed and the expired.
	var kept: Array[Fighter] = []
	for f in fighters:
		if not is_instance_valid(f):
			continue
		if f.is_decoy:
			f.queue_free()
			continue
		kept.append(f)
	fighters = kept
	# Clones spawned mid-round belong to no roster yet — sweep the group.
	for n in get_tree().get_nodes_in_group("fighters"):
		if n is Fighter and is_instance_valid(n) and (n as Fighter).is_decoy:
			(n as Fighter).queue_free()


func _team_alive(team: int) -> int:
	var c := 0
	for f in fighters:
		if not is_instance_valid(f) or f.is_decoy:
			continue
		if f.team == team and f.state != Fighter.St.DEAD:
			c += 1
	return c


func _finish_round(winner_team: int) -> void:
	_round_over = true
	phase = "round_end"
	if winner_team < 0:
		winner_team = _judge_by_hp()
	team_wins[winner_team] = int(team_wins[winner_team]) + 1
	round_changed.emit(round_index, team_wins[0], team_wins[1])
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("punch_zoom"):
		rig.punch_zoom()
	await get_tree().create_timer(1.6).timeout
	if int(team_wins[winner_team]) >= WINS_NEEDED:
		_end_match(winner_team)
	else:
		_start_round()


func _judge_by_hp() -> int:
	var t := {0: 0.0, 1: 0.0}
	for f in fighters:
		if not is_instance_valid(f) or f.is_decoy:
			continue
		if f.team in [0, 1]:
			t[f.team] = float(t[f.team]) + f.health.fraction()
	return 0 if float(t[0]) >= float(t[1]) else 1


func _end_match(winner_team: int) -> void:
	phase = "done"
	var player_won := winner_team == 0 # local player(s) are always team 0
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		sm.record_result(player_won)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		if player_won:
			am.play_victory()
			am.play_voice("win")
		else:
			am.play_defeat()
	var vm := get_tree().get_first_node_in_group("vfx")
	if vm and vm.has_method("burst") and fighters.size() > 0:
		vm.burst("victory", fighters[0].global_position + Vector3(0, 1, 0))
	match_ended.emit(player_won)
