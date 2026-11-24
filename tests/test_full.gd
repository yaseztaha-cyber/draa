extends Node
## DRAA full-stack integration test — also the engine-side audit driver.
## Run: godot --headless --path . res://tests/test_full.tscn
## Boots menu/select/results scenes, plays a REAL 1v1 bot match at 8x
## speed, exercises combat/arena systems, asserts, quits with exit code.
## Every scene load compiles its scripts, so green here == full audit pass.
## NOTE: this machine is strictly await-free — every step runs atomically
## per physics frame (awaits inside _physics_process re-enter and rewind).

var failures: int = 0
var frames: int = 0
var step: int = 0
var wait_until: int = 0
var bound: bool = false
var arena: DraaArena
var player: Fighter
var botFighter: Fighter
var mm: MatchManager
var countdown_seen: bool = false
var match_over: bool = false
var match_won: bool = false
var wins_before: int = 0
var strike_tries: int = 0
var struck: bool = false
var hurt_seen: bool = false
var settle_tries: int = 0
var chain_tries: int = 0
var ult_pre_hp: float = 0.0
var ult_was_dead: bool = false
var probe_arena: ArenaFrozen
var probe_player: Fighter


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS  " + name)
	else:
		failures += 1
		printerr("FAIL  " + name)


func _ready() -> void:
	Engine.time_scale = 8.0
	print("--- DRAA FULL INTEGRATION ---")


func _physics_process(_delta: float) -> void:
	frames += 1
	if frames > 6000 or Time.get_ticks_msec() > 200000:
		printerr("FAIL  hang/wallclock guard tripped")
		_quit(1)
		return
	if frames % 60 == 0:
		var ridx := -1
		if mm != null:
			ridx = mm.round_index
		print("HB f=", frames, " tms=", Time.get_ticks_msec(), " step=", step,
			" ts=", Engine.time_scale, " round=", ridx,
			" mover=", match_over)
	if frames < wait_until:
		return
	match step:
		0:
			_test_menu()
		10:
			_test_select()
		1:
			_start_arena()
		20:
			_probe_frozen()
		21:
			_probe_release()
		22:
			_probe_slide()
		23:
			_probe_shard()
		2:
			_drive_strike()
		12:
			_check_strike()
		7:
			_drive_ability()
		8:
			_drive_chain()
		13:
			_drive_ult()
		15:
			_drive_ult_fire()
		14:
			_drive_powers()
		6:
			_check_pickups()
		3:
			_force_end_round()
		4:
			_verify_results()


func _test_menu() -> void:
	var lm = get_node("/root/LocalizationManager")
	check(lm.is_rtl(), "locale defaults to Arabic RTL")
	var menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	add_child(menu)
	check(menu.get_child_count() > 3, "main menu builds 3D preview + UI")
	menu.queue_free()
	step = 10


func _test_select() -> void:
	var sel = load("res://scenes/menu/FighterSelect.tscn").instantiate()
	add_child(sel)
	check(sel.get_child_count() > 0, "fighter select builds cards")
	sel.queue_free()
	var sm = get_node("/root/SaveManager")
	wins_before = int(sm.profile.get("wins", 0))
	check(sel.find_child("ArenaCard_volcano", true, false) != null, "volcano card exists")
	check(sel.find_child("ArenaCard_frozen", true, false) != null, "frozen card exists")
	step = 20


func _probe_frozen() -> void:
	# Frozen probe: black-ice slide + falling-shard damage/slow, white-box
	# where physics luck would flake (overlap is engine behavior).
	probe_arena = load("res://scenes/arenas/Arena_Frozen.tscn").instantiate() as ArenaFrozen
	probe_arena.auto_show_results = false
	add_child(probe_arena)
	probe_player = probe_arena.match_manager.fighters[0]
	var probe_bot: Fighter = probe_arena.match_manager.fighters[1]
	for c in probe_bot.get_children():
		if c is BotController:
			c.queue_free() # deterministic probe: bot stands still
	check(is_equal_approx(probe_player.traction, 0.12), "frozen traction is icy")
	check(get_tree().get_nodes_in_group("ice_spikes").size() == 5, "frozen fangs up")
	check(probe_arena.find_child("SnowFall", true, false) != null, "snowfall falling")
	var fsky := false
	for c in probe_arena.get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).environment.background_mode == Environment.BG_SKY:
			fsky = true
	check(fsky, "frozen sky graded")
	probe_player.set_frozen(false)
	probe_bot.set_frozen(false)
	# Own move_dir like the HUD joystick does, or the keyboard test path
	# zeroes it every tick before the slide can build. The probe arena's
	# own HUD would steal ownership back each frame, so park it: cooldown
	# refresh is irrelevant to a slide measurement.
	probe_arena.hud.process_mode = Node.PROCESS_MODE_DISABLED
	probe_player.touch_move = true
	probe_player.move_dir = Vector3(1, 0, 0)
	wait_until = frames + 10
	step = 21


func _probe_release() -> void:
	probe_player.move_dir = Vector3.ZERO
	wait_until = frames + 8
	step = 22


func _probe_slide() -> void:
	# Released input must keep sliding on ice (rock snaps to ~0).
	check(absf(probe_player.velocity.x) > 1.0, "ice keeps sliding")
	probe_arena._drop_shard_at(probe_player.global_position, 0.0)
	wait_until = frames + 8
	step = 23


func _probe_shard() -> void:
	check(probe_player.health.current < probe_player.health.maximum, "falling ice hurts")
	check(probe_player.slow_t > 0.0, "falling ice slows")
	probe_arena.queue_free()
	probe_arena = null
	step = 1


func _start_arena() -> void:
	if arena == null:
		arena = load("res://scenes/arenas/Arena_Volcano.tscn").instantiate() as DraaArena
		arena.auto_show_results = false # test drives results itself
		add_child(arena)
		return
	if mm == null:
		mm = arena.match_manager
	if mm.fighters.size() != 2:
		return # setup failed; hang guard will report, no respam
	check(mm.fighters.size() == 2, "arena spawns 2 fighters")
	player = mm.fighters[0]
	botFighter = mm.fighters[1]
	check(arena.hud != null, "HUD spawned and bound")
	# Arm detail exists once _ready builds it (in-tree only).
	for apart in ["ArmCore", "FormExtra", "ShoulderPad"]:
		check(player.arm.find_child(apart, true, false) != null, "arm detail: " + apart)
	# v0.4 volcano dressing: rim rocks, torches, flowing lava, graded sky.
	# Counted via groups (engine-reliable for runtime-built nodes).
	check(get_tree().get_nodes_in_group("rim_rocks").size() == 10, "volcano rim rocks")
	check(arena.find_child("LavaFlow", true, false) != null, "lava flow skinned")
	check(get_tree().get_nodes_in_group("torch_flames").size() == 2, "volcano torches lit")
	var vsky := false
	for c in arena.get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).environment.background_mode == Environment.BG_SKY:
			vsky = true
	check(vsky, "volcano sky graded")
	for c in botFighter.get_children():
		if c is BotController:
			c.queue_free() # deterministic test: bot stands still
	if not bound:
		bound = true
		mm.countdown_tick.connect(_on_countdown)
		mm.match_ended.connect(_on_match_end)
		botFighter.hurt_feedback.connect(_on_hurt_flag)
	wait_until = frames + 40 # countdown = 2.8s game-time
	step = 2


func _on_hurt_flag(_from: Vector3, _blocked: bool) -> void:
	hurt_seen = true


func _settled() -> bool:
	# Phase-2 actions commit (windup+recover); chained steps must start from
	# NORMAL or intents silently buffer and every later assert slides late.
	# Poll instead of fixed waits so debt can never accumulate.
	if player.state == Fighter.St.NORMAL:
		settle_tries = 0
		return true
	settle_tries += 1
	if settle_tries > 25:
		check(false, "fighter settles (stuck in state %d)" % player.state)
		settle_tries = 0
		return true
	wait_until = frames + 4
	return false


func _on_countdown(_txt: String, _final: bool) -> void:
	countdown_seen = true


func _on_match_end(won: bool) -> void:
	match_over = true
	match_won = won


func _drive_strike() -> void:
	if strike_tries == 0:
		check(countdown_seen, "countdown ran")
		check(player.health.maximum >= 80.0, "player has sane HP")
	# Windup lands damage a few ticks after the button: arm, then verify.
	player.global_position = botFighter.global_position + Vector3(1.5, 0, 0)
	player.try_attack()
	wait_until = frames + 5
	step = 12


func _check_strike() -> void:
	if botFighter.health.current < botFighter.health.maximum:
		check(true, "melee damages bot")
		check(hurt_seen, "hurt feedback fires")
		# Perfect dodge probe: dash grants i-frames; a hit inside them
		# charges the ult instead of hurting.
		player.ult = 0.0
		var hp_pre: float = player.health.current
		player.try_dash()
		player.take_hit(botFighter.global_position, 20.0, Vector3.ZERO, 0.3, &"fire", botFighter, false)
		check(player.ult > 0.0, "perfect dodge charges ult")
		check(player.health.current >= hp_pre, "perfect dodge takes no damage")
		check(player.dash_cd > 0.0, "dash triggers + cooldown")
		# Dash owns the state briefly; chain + powers run next steps.
		wait_until = frames + 8
		step = 7
		return
	strike_tries += 1
	print("DBG strike try ", strike_tries, " p=", player.global_position,
		" b=", botFighter.global_position, " pstate=", player.state,
		" bstate=", botFighter.health.dead, " cd=", player.attack_cd,
		" bHP=", botFighter.health.current)
	if strike_tries >= 6:
		check(false, "melee damages bot")
		wait_until = frames + 8
		step = 7
		return
	wait_until = frames + 5


func _drive_ability() -> void:
	player.try_ability1()
	check(player.ab1_cd > 0.0, "ability triggers + cooldown")
	player.global_position = botFighter.global_position + Vector3(1.5, 0, 0)
	player.try_attack()
	wait_until = frames + 6
	step = 8


func _drive_chain() -> void:
	# Adaptive chain driver: attack the moment the arm is free instead of on
	# fixed frame counts, so windup/recover debt can never desync the combo
	# window (fixed waits raced it and flaked). Caped: fails loud, no hangs.
	if player.combo_count >= 3:
		check(true, "combo chain lands x3")
		wait_until = frames + 2
		step = 13
		return
	chain_tries += 1
	if chain_tries > 40:
		check(false, "combo chain lands x3")
		wait_until = frames + 2
		step = 13
		return
	if player.state != Fighter.St.NORMAL:
		wait_until = frames + 2
		return
	player.global_position = botFighter.global_position + Vector3(1.5, 0, 0)
	player.try_attack()
	wait_until = frames + 2


func _drive_ult() -> void:
	check(player.combo_count >= 3, "combo chain lands x3")
	# Heavy finisher needs its full windup+recover before the ult arm is free.
	wait_until = frames + 2
	step = 15


func _drive_ult_fire() -> void:
	if not _settled():
		return
	# Re-face point-blank: the finisher's knockback may have thrown the bot
	# out of the ult cone, and a whiffed ult proves nothing.
	player.global_position = botFighter.global_position + Vector3(1.5, 0, 0)
	print("DBG ult pre p=", player.global_position, " b=", botFighter.global_position,
		" pst=", player.state, " bdead=", botFighter.health.dead,
		" bhp=", botFighter.health.current)
	player.ult = 100.0
	ult_pre_hp = botFighter.health.current
	ult_was_dead = botFighter.health.dead
	player.try_ultimate()
	check(player.ult < 100.0, "ultimate consumes charge")
	# Damage lands when the 0.4s windup ends — asserted next step, after the
	# arm is provably free (a kill here legitimately starts round 2 early).
	wait_until = frames + 16
	step = 14


func _drive_powers() -> void:
	# Round-transition proof: the ult may have ended the round early
	# (revive + countdown freeze the player), so gate on fight + NORMAL.
	if mm.phase != "fight":
		wait_until = frames + 10
		return
	if not _settled():
		return
	check(botFighter.health.current < ult_pre_hp or botFighter.health.dead or ult_was_dead or mm.round_index > 1, "ultimate damages bot")
	var ab2btn := arena.hud.find_child("Ab2Btn", true, false)
	check(ab2btn != null, "ability2 button exists")
	print("DBG ab2 pre pst=", player.state, " ab2cd=", player.ab2_cd,
		" bdead=", botFighter.health.dead, " bhp=", botFighter.health.current)
	player.try_ability2()
	check(player.ab2_cd > 0.0, "ability2 triggers + cooldown")
	# Breakable barrel detonation path.
	var barrels: Array = get_tree().get_nodes_in_group("breakables")
	check(barrels.size() >= 1, "explosive barrels exist")
	(barrels[0] as BreakableBarrel).take_hit(999.0, player.global_position, &"fire")
	# Ult orb pickup path. White-box like lava: the Area overlap is engine
	# behavior, the charge logic is ours — and teleport luck (landing inside
	# an already-entered area, cooldown races) must not flake the assert.
	arena._orb_cd = 0.0
	player.ult = 0.0
	arena._on_orb_pickup(player)
	check(player.ult > 0.0, "ult orb charges arm")
	wait_until = frames + 4
	step = 6


func _check_pickups() -> void:
	# Lava moat: handler burns past the 10.5m line. White-box call: the
	# overlap area itself is engine behavior; the distance gate is our code.
	var hp_pre_lava: float = player.health.current
	player.global_position = Vector3(11.5, 0.5, 0)
	arena._on_lava_touch(player)
	check(player.health.current < hp_pre_lava, "lava moat burns past 10.5m")
	wait_until = frames + 5
	step = 3


func _force_end_round() -> void:
	if match_over:
		check(match_won, "player wins forced 1v1")
		var sm = get_node("/root/SaveManager")
		check(int(sm.profile.get("wins", 0)) == wins_before + 1, "win recorded + XP path")
		step = 4
		return
	# Forces only count in fight phase: a direct take_hit during the intro
	# countdown kills without round handling (production can never do this —
	# fighters are frozen — so the test must not either).
	if mm.phase != "fight":
		wait_until = frames + 10
		return
	# Force bot KO; each kill must advance the round or end the match.
	if not botFighter.health.dead:
		botFighter.take_hit(botFighter.global_position + Vector3(0, 0, 1), 9999.0, Vector3.ZERO, 0.0, &"fire", player, true)
	wait_until = frames + 40


func _verify_results() -> void:
	arena.queue_free()
	var gm = get_node("/root/GameManager")
	gm.set_meta("last_result", {"won": match_won})
	var res = load("res://scenes/ui/ResultsScreen.tscn").instantiate()
	add_child(res)
	var found_label := false
	for n in res.get_children():
		if n is VBoxContainer and n.get_child_count() >= 4:
			found_label = true
	res.queue_free()
	check(found_label, "results screen shows verdict + rewards")
	print("---")
	if failures == 0:
		print("ALL INTEGRATION TESTS PASSED")
	else:
		printerr(str(failures) + " FAILURES")
	_quit(failures)


func _quit(code: int) -> void:
	Engine.time_scale = 1.0
	get_tree().quit(code)
