class_name MiniGameBase
extends Node3D
## Shared mini-game framework (§16). Every mini-game runs the same phases:
## INTRO -> COUNTDOWN -> PLAY -> SCORE -> RESULTS, with shared spawn,
## timer, score, winner and reward hooks. Phase 5 games extend this.

signal phase_changed(phase: String)
signal scores_changed(scores: Dictionary)
signal game_finished(winner: int)

enum Phase { INTRO, COUNTDOWN, PLAY, SCORE, DONE }

var phase: int = Phase.INTRO
var time_left: float = 60.0
var scores: Dictionary = {}
var player_ids: Array[int] = []
var config: Dictionary = {}


func setup(p_players: Array[int], p_config: Dictionary) -> void:
	player_ids = p_players
	config = p_config
	for id in player_ids:
		scores[id] = 0


func start_game() -> void:
	_enter(Phase.INTRO)
	await _show_intro()
	_enter(Phase.COUNTDOWN)
	await _run_countdown()
	_enter(Phase.PLAY)
	await _run_play()
	_enter(Phase.SCORE)
	_finish()


func _enter(p: int) -> void:
	phase = p
	phase_changed.emit(["INTRO", "COUNTDOWN", "PLAY", "SCORE", "DONE"][p])


func add_score(player: int, delta: int) -> void:
	scores[player] = int(scores.get(player, 0)) + delta
	scores_changed.emit(scores)


func winner() -> int:
	var best := -1
	var best_s := -999999
	for id in scores.keys():
		if int(scores[id]) > best_s:
			best_s = int(scores[id])
			best = id
	return best


# --- Override points (per-game rules live in subclasses) ---
func _show_intro() -> void:
	await get_tree().create_timer(1.0).timeout


func _run_countdown() -> void:
	for i in 3:
		await get_tree().create_timer(0.6).timeout


func _run_play() -> void:
	var t := float(config.get("duration", 60.0))
	time_left = t
	while time_left > 0.0 and phase == Phase.PLAY:
		await get_tree().process_frame
		time_left -= get_process_delta_time()


func _finish() -> void:
	_enter(Phase.DONE)
	game_finished.emit(winner())
