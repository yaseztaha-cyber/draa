class_name BotController
extends Node
## Bot driver (§28) using the same Fighter.try_* API as touch input.
## Reaction times are human-like per difficulty — never frame-perfect.

var fighter: Fighter
var difficulty: String = "normal"
var aggression: float = 0.6
var reaction: float = 0.35
var aim_error: float = 0.25

var _think: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_t: float = 0.0


func setup(p_fighter: Fighter, p_difficulty: String) -> void:
	fighter = p_fighter
	difficulty = p_difficulty
	match p_difficulty:
		"easy":
			reaction = 0.65
			aim_error = 0.55
			aggression = 0.4
		"hard":
			reaction = 0.2
			aim_error = 0.1
			aggression = 0.85
		_:
			reaction = 0.35
			aim_error = 0.25
			aggression = 0.6


func _exit_tree() -> void:
	# A freed driver must not leave a stuck move_dir behind (the body
	# would march forever with no one steering).
	if fighter:
		fighter.move_dir = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if fighter == null or fighter.state == Fighter.St.DEAD:
		return
	_think -= delta
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_dir = -_strafe_dir if randf() < 0.7 else randf_range(-1.0, 1.0)
		_strafe_t = randf_range(0.6, 1.6)
	var foe := _closest_foe()
	if foe == null:
		fighter.move_dir = Vector3.ZERO
		return
	var to: Vector3 = foe.global_position - fighter.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
	# Movement: approach until mid-range, strafe in range, flee when weak.
	var frac := fighter.health.fraction()
	if frac < 0.25 and difficulty != "easy" and dist < 5.0 and randf() < 0.7:
		fighter.move_dir = -dir # retreat
	elif dist > 3.2:
		fighter.move_dir = dir
	else:
		var side := Vector3(-dir.z, 0, dir.x) * _strafe_dir
		fighter.move_dir = (dir * 0.3 + side * 0.7).normalized()
	# Decisions on the think tick (reaction-gated, never instant).
	if _think > 0.0:
		return
	_think = reaction
	if foe.state == Fighter.St.DEAD:
		return
	fighter.set_block(false)
	var roll := randf()
	if dist < 2.8 and roll < aggression:
		fighter.try_attack()
	elif dist < 5.5 and roll < aggression * 0.5:
		if randf() < 0.5:
			fighter.try_ability1()
		else:
			fighter.try_ability2()
	elif dist > 5.0 and roll < 0.3:
		fighter.try_dash()
	if fighter.ult >= Fighter.ULT_MAX and dist < 5.0 and roll < aggression:
		fighter.try_ultimate()
	if difficulty == "hard" and dist < 3.0 and randf() < 0.25:
		fighter.set_block(true)


func _closest_foe() -> Fighter:
	var best: Fighter = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("fighters"):
		if n == fighter or not (n is Fighter):
			continue
		var f := n as Fighter
		if f.team == fighter.team or f.state == Fighter.St.DEAD:
			continue
		var d := fighter.global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best
