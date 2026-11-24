class_name Fighter
extends CharacterBody3D
## DRAA fighter: one normal body + one MagicArm (§8). Mobile-friendly kit:
## context-aware attack, dash i-frames, block, 2 abilities, ultimate.
## Movement + combat numbers come from FighterData + AbilityDB (§40).
## Bot drivers use the same try_* API as touch buttons (no cheat paths).

signal hp_changed(current: float, maximum: float)
signal ult_changed(value: float)
signal cooldowns_changed
signal died(fighter: Fighter, killer: Node)
signal dealt_hit(victim: Fighter, heavy: bool)
## Phase-2 feedback: HUD arrow + flash point at the attacker.
signal hurt_feedback(from_pos: Vector3, blocked: bool)
## Perfect dodge (dashed clean through an attack): banner + bonus charge.
signal dodged_clean

enum St { NORMAL, DASH, STUN, DEAD, ATTACK }
## Attack phases inside St.ATTACK: windup (commit) -> active hit -> recover.
enum Ph { WINDUP, RECOVER }

var data: FighterData
var fighter_id: String = "fire"
var element: StringName = &"fire"
var team: int = 0
var is_bot: bool = false
var bot_difficulty: String = "normal"
var is_local_player: bool = true

var move_dir: Vector3 = Vector3.ZERO # world-space, set by input/bot
var touch_move: bool = false # HUD joystick owns move_dir while deflected
var block_held: bool = false
var frozen: bool = false # true during match countdown: no actions, no motion
## Surface grip set by the arena (1.0 rock, ~0.12 black ice). Knockback
## always applies instantly — only steering slides.
var traction: float = 1.0
## Ice slow debuff: movement multiplier + remaining time.
var slow_t: float = 0.0
var slow_mult: float = 1.0

var state: int = St.NORMAL
var attack_cd: float = 0.0
var ab1_cd: float = 0.0
var ab2_cd: float = 0.0
var dash_cd: float = 0.0
var dash_time: float = 0.0
var iframes: float = 0.0
var stun: float = 0.0
var ult: float = 0.0
var combo_count: int = 0
var combo_window: float = 0.0
var dashed_in_combo: bool = false
var fell: bool = false
## Phase-2 attack state.
var atk_phase: int = Ph.WINDUP
var phase_t: float = 0.0
var _pending_ab: AbilityData
var _pending_heavy: bool = false
var _pending_launcher: bool = false
var _pending_finisher: bool = false
var _pending_ult: bool = false
var _pending_clone: bool = false
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_t: float = 0.0
var _lunge_speed: float = 0.0
## Input buffer: intent pressed mid-action fires when free (feel first).
var _buffered: String = ""
var _buffer_t: float = 0.0
## Shadow clone decoy: 1 HP stand-in that splits aggro, never ends rounds.
var is_decoy: bool = false
var _decoy_t: float = 0.0

var health: CombatHealth
var arm: MagicArm
var _visual: FighterVisual
var name_label: Label3D
var display_name: String = ""
var _blink_t: float = 2.0
var _was_air: bool = false

const ULT_MAX := 100.0
const COMBO_WINDOW := 1.2
const DASH_DURATION := 0.22
const DASH_IFRAMES := 0.28
const DASH_CD := 3.0
const DASH_SPEED_MULT := 3.2
const BUFFER_WINDOW := 0.3
const FINISHER_MULT := 1.3
const DECOY_LIFETIME := 6.0
const PERFECT_DODGE_ULT := 18.0


func setup(p_data: FighterData, p_team: int, p_is_bot: bool, p_name: String) -> void:
	data = p_data
	fighter_id = String(p_data.fighter_id)
	element = p_data.element
	team = p_team
	is_bot = p_is_bot
	display_name = p_name
	add_to_group("fighters")


func _ready() -> void:
	if data == null:
		data = FighterData.new()
	collision_layer = 2 if team == 0 else 4
	collision_mask = 1
	floor_snap_length = 0.4
	health = CombatHealth.new()
	add_child(health)
	health.setup(data.max_hp, data.defense)
	health.changed.connect(func(c, m): hp_changed.emit(c, m))
	health.depleted.connect(_on_depleted)
	_build_body()
	arm.configure(element, data.arm_color)


func _build_body() -> void:
	# Full cartoon body from the shared builder (menu preview identical).
	_visual = FighterVisual.build(data)
	add_child(_visual)
	arm = _visual.arm
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.5
	col.shape = shape
	col.position = Vector3(0, 0.95, 0)
	add_child(col)
	# Hurtbox for hazards/pickups (melee uses deterministic range checks).
	var hurt := Area3D.new()
	hurt.collision_layer = 0
	hurt.collision_mask = 32 + 16 # pickup + hazard layers
	var hs := CollisionShape3D.new()
	var hshape := SphereShape3D.new()
	hshape.radius = 0.7
	hs.shape = hshape
	hs.position = Vector3(0, 1.1, 0)
	hurt.add_child(hs)
	add_child(hurt)
	name_label = Label3D.new()
	name_label.text = display_name
	name_label.position = Vector3(0, 2.5, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 64
	name_label.pixel_size = 0.008
	name_label.outline_size = 12
	add_child(name_label)


func _physics_process(delta: float) -> void:
	if state == St.DEAD:
		return
	_tick_timers(delta)
	if is_decoy:
		_decoy_t -= delta
		if _decoy_t <= 0.0:
			_vfx_burst("shadow", 1.5)
			queue_free()
			return
	if state == St.ATTACK:
		_tick_attack(delta)
	if stun > 0.0:
		state = St.STUN
	elif state == St.STUN and stun <= 0.0:
		state = St.NORMAL
	if not is_bot and is_local_player:
		_poll_keyboard()
	var speed := data.move_speed
	if block_held and state == St.NORMAL:
		speed *= 0.35
	if state == St.DASH:
		speed *= DASH_SPEED_MULT
	elif state == St.STUN:
		speed = 0.0
	elif state == St.ATTACK:
		# Committed: rooted through windup/active (lunge excepted),
		# half-speed footwork in recovery (dash can cancel it).
		if atk_phase == Ph.WINDUP and _lunge_t > 0.0:
			_lunge_t -= delta
		elif atk_phase == Ph.RECOVER:
			speed *= 0.5
		else:
			speed = 0.0
	if slow_t > 0.0:
		speed *= slow_mult
	var wish := move_dir
	if state == St.ATTACK and atk_phase == Ph.WINDUP and _lunge_t > 0.0:
		wish = _lunge_dir
		speed = _lunge_speed
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	# Traction blend: rock snaps (accel 1.0 = byte-identical to direct set),
	# ice slides. Knockback always applies instantly — hits must shove.
	var accel := clampf(traction, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, wish.x * speed, accel) + _knock.x
	velocity.z = lerpf(velocity.z, wish.z * speed, accel) + _knock.z
	var fall_v := 0.0
	if not is_on_floor():
		velocity.y -= 19.6 * delta
		fall_v = velocity.y
	else:
		velocity.y = minf(velocity.y, 0.0)
	_knock = _knock.move_toward(Vector3.ZERO, delta * 30.0)
	move_and_slide()
	if _was_air and is_on_floor() and state != St.DEAD:
		if fall_v < -8.0:
			_land_juice()
	_was_air = not is_on_floor()
	if wish.length() > 0.05 and state == St.NORMAL:
		var target_yaw := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 12.0))
	if global_position.y < -6.0:
		fell = true
		health.apply_damage(health.maximum + 999.0, null)


var _knock: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
	if state == St.DEAD or _visual == null:
		return
	var gm := get_node_or_null("/root/GameManager")
	var calm: bool = gm != null and gm.reduced_motion()
	if not calm:
		# Idle hover bob, speed lean, squash/stretch spring-back.
		var spd := Vector3(velocity.x, 0.0, velocity.z).length()
		_visual.position.y = absf(sin(Time.get_ticks_msec() / 1000.0 * 6.0)) * 0.04 * minf(spd / 6.0 + 0.4, 1.0)
		_visual.rotation.x = lerpf(_visual.rotation.x, clampf(spd / 7.0, 0.0, 1.0) * 0.12, minf(1.0, delta * 8.0))
		_visual.scale = _visual.scale.lerp(Vector3.ONE, minf(1.0, delta * 10.0))
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.2, 4.2)
			_visual.eye_l.scale.y = 0.12
			_visual.eye_r.scale.y = 0.12
			await get_tree().create_timer(0.12).timeout
			if is_instance_valid(_visual):
				_visual.eye_l.scale.y = 1.0
				_visual.eye_r.scale.y = 1.0


func _land_juice() -> void:
	_visual.scale = Vector3(1.15, 0.8, 1.15)
	var vm := get_tree().get_first_node_in_group("vfx")
	if vm and vm.has_method("burst"):
		vm.burst("dash", global_position + Vector3(0, 0.15, 0), element, 1.5)
	_audio().play_land()


func _tick_timers(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	ab1_cd = maxf(0.0, ab1_cd - delta)
	ab2_cd = maxf(0.0, ab2_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	iframes = maxf(0.0, iframes - delta)
	stun = maxf(0.0, stun - delta)
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0
	if dash_time > 0.0:
		dash_time -= delta
		if dash_time <= 0.0 and state == St.DASH:
			state = St.NORMAL
	if combo_window > 0.0:
		combo_window -= delta
		if combo_window <= 0.0:
			combo_count = 0
			dashed_in_combo = false
	if _buffer_t > 0.0:
		_buffer_t -= delta
		if _buffer_t <= 0.0:
			_buffered = ""
	if state == St.NORMAL and not _buffered.is_empty():
		var action := _buffered
		_buffered = ""
		_buffer_t = 0.0
		match action:
			"attack":
				try_attack()
			"dash":
				try_dash()
			"ab1":
				try_ability1()
			"ab2":
				try_ability2()
			"ult":
				try_ultimate()
	cooldowns_changed.emit()


func _buffer(action: String) -> void:
	_buffered = action
	_buffer_t = BUFFER_WINDOW


func _cancel_attack() -> void:
	state = St.NORMAL
	arm.set_form(MagicArm.Form.FIST)


func _tick_attack(delta: float) -> void:
	phase_t -= delta
	if atk_phase == Ph.WINDUP:
		if phase_t <= 0.0:
			_fire_active()
	elif phase_t <= 0.0:
		state = St.NORMAL
		arm.set_form(MagicArm.Form.FIST)


func _poll_keyboard() -> void:
	if not touch_move:
		var v := Vector2.ZERO
		if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
			v.x -= 1.0
		if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
			v.x += 1.0
		if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
			v.y -= 1.0
		if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
			v.y += 1.0
		if v != Vector2.ZERO:
			# Camera looks -Z; keyboard maps directly to world XZ.
			move_dir = Vector3(v.x, 0, v.y).normalized()
		else:
			move_dir = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_J):
		try_attack()
	if Input.is_physical_key_pressed(KEY_K):
		try_ability1()
	if Input.is_physical_key_pressed(KEY_I):
		try_ability2()
	if Input.is_physical_key_pressed(KEY_L) or Input.is_physical_key_pressed(KEY_SHIFT):
		try_dash()
	if Input.is_physical_key_pressed(KEY_U):
		try_ultimate()
	var want_block := Input.is_physical_key_pressed(KEY_H)
	if want_block != block_held:
		set_block(want_block)


# --- Actions (shared by touch buttons + bots) ---

func _nearest_enemy(max_dist: float) -> Fighter:
	var best: Fighter = null
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("fighters"):
		if n == self or not (n is Fighter):
			continue
		var f := n as Fighter
		if f.team == team or f.state == St.DEAD:
			continue
		var d := global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


func _face(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func set_frozen(v: bool) -> void:
	# Match countdown freeze: no physics integration here or in drivers,
	# and try_* refuse input (no corpse rounds from intro falls).
	frozen = v
	set_physics_process(not v)
	for c in get_children():
		c.set_physics_process(not v)


func try_attack() -> bool:
	if frozen or is_decoy or state == St.DEAD or state == St.STUN:
		return false
	if state == St.ATTACK or state == St.DASH:
		_buffer("attack")
		return false
	if state != St.NORMAL or attack_cd > 0.0:
		return false
	# Chain: light, light, then heavy finisher. Dash in the window instead
	# routes into a launcher via dashed_in_combo.
	var heavy := combo_count >= 2
	var ab := AbilityDB.get_ability(&"heavy_punch" if heavy else &"light_punch")
	_begin_strike(ab, heavy, dashed_in_combo, heavy, false)
	return true


func _begin_strike(ab: AbilityData, heavy: bool, launcher: bool, finisher: bool, is_ult: bool) -> void:
	# All commitment happens here: cooldowns start at the windup so whiffs
	# are punishable, and the hit lands exactly when windup ends.
	state = St.ATTACK
	atk_phase = Ph.WINDUP
	phase_t = ab.windup
	_pending_ab = ab
	_pending_heavy = heavy
	_pending_launcher = launcher
	_pending_finisher = finisher
	_pending_ult = is_ult
	_pending_clone = ab.ability_id == &"shadow_clone"
	attack_cd = maxf(attack_cd, ab.windup + ab.recover + 0.12)
	arm.set_form(MagicArm.Form.BLADE if heavy else MagicArm.Form.FIST)
	arm.play_windup()
	var foe := _nearest_enemy(ab.range + ab.radius + 1.5)
	if foe:
		_face(foe.global_position)
	if ab.lunge > 0.0:
		_lunge_dir = -global_transform.basis.z
		_lunge_dir.y = 0.0
		if _lunge_dir.length() < 0.01:
			_lunge_dir = Vector3.FORWARD
		else:
			_lunge_dir = _lunge_dir.normalized()
		_lunge_speed = minf(ab.lunge / maxf(ab.windup, 0.05), 20.0)
		_lunge_t = ab.windup
	else:
		_lunge_t = 0.0
	combo_window = COMBO_WINDOW
	cooldowns_changed.emit()


func _fire_active() -> void:
	var ab := _pending_ab
	arm.play_attack()
	_audio().play_attack(String(ab.element if ab.element != &"none" else element))
	if _pending_clone:
		spawn_decoy()
	if _pending_ult:
		arm.set_charge(0.0)
		_vfx_burst("ultimate", ab.radius)
		_vfx_ring(ab.radius * 1.5)
	_apply_melee(ab, _pending_heavy, _pending_launcher, _pending_finisher, _pending_ult)
	if not ab.ability_id == &"light_punch" and not ab.ability_id == &"heavy_punch":
		_gain_ult(ab.ult_charge_gain * 0.5)
	atk_phase = Ph.RECOVER
	phase_t = ab.recover


func try_dash() -> bool:
	if frozen or is_decoy or state == St.DEAD or state == St.STUN:
		return false
	if state == St.ATTACK:
		if atk_phase == Ph.RECOVER:
			_cancel_attack() # dash-cancel: cut recovery, keep the combo
		else:
			_buffer("dash")
			return false
	elif state != St.NORMAL:
		if state == St.DASH:
			_buffer("dash")
		return false
	if dash_cd > 0.0:
		return false
	state = St.DASH
	dash_time = DASH_DURATION
	iframes = DASH_IFRAMES
	dash_cd = DASH_CD
	if combo_window > 0.0:
		dashed_in_combo = true
	if move_dir.length() < 0.05:
		move_dir = -global_transform.basis.z
		move_dir.y = 0.0
	_face(global_position + move_dir)
	_audio().play_dash()
	_visual.scale = Vector3(0.9, 0.9, 1.18)
	var vmd := get_tree().get_first_node_in_group("vfx")
	if vmd and vmd.has_method("burst"):
		vmd.burst("dash", global_position + Vector3(0, 0.15, 0), element, 1.5)
	combo_window = COMBO_WINDOW
	return true


func try_ability1() -> bool:
	return _cast_ability(data.ability1_id, true)


func try_ability2() -> bool:
	return _cast_ability(data.ability2_id, false)


func _cast_ability(ability_id: StringName, is_first: bool) -> bool:
	if frozen or is_decoy or state == St.DEAD or state == St.STUN:
		return false
	if state == St.ATTACK or state == St.DASH:
		_buffer("ab1" if is_first else "ab2")
		return false
	if state != St.NORMAL:
		return false
	if (is_first and ab1_cd > 0.0) or (not is_first and ab2_cd > 0.0):
		return false
	var ab := AbilityDB.get_ability(ability_id)
	if is_first:
		ab1_cd = ab.cooldown
	else:
		ab2_cd = ab.cooldown
	_begin_strike(ab, true, false, false, false)
	return true


func try_ultimate() -> bool:
	if frozen or is_decoy or state == St.DEAD or state == St.STUN:
		return false
	if state == St.ATTACK or state == St.DASH:
		_buffer("ult")
		return false
	if state != St.NORMAL or ult < ULT_MAX:
		return false
	var ab := AbilityDB.get_ability(data.ultimate_id)
	ult = 0.0
	ult_changed.emit(ult)
	arm.set_form(MagicArm.Form.FIST)
	arm.set_charge(1.0) # full glow through the dramatic windup
	_audio().play_voice("ult")
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("punch_zoom"):
		rig.punch_zoom()
	_begin_strike(ab, true, true, false, true)
	return true


func set_block(held: bool) -> void:
	if is_decoy:
		return
	block_held = held
	if held:
		arm.set_form(MagicArm.Form.SHIELD)
	elif arm.form == MagicArm.Form.SHIELD:
		arm.set_form(MagicArm.Form.FIST)


func _apply_melee(ab: AbilityData, heavy: bool, launcher: bool, finisher: bool = false, is_ult: bool = false) -> void:
	var hit_any := false
	var first_victim: Fighter = null
	for n in get_tree().get_nodes_in_group("fighters"):
		if n == self or not (n is Fighter):
			continue
		var f := n as Fighter
		if f.team == team or f.state == St.DEAD:
			continue
		var to: Vector3 = f.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > ab.range + ab.radius:
			continue
		var fwd := -global_transform.basis.z
		fwd.y = 0.0
		if fwd.normalized().dot(to.normalized()) < 0.35 and dist > 1.2:
			continue # whiffed behind us
		var mult := ElementMatrix.multiplier(ab.element, f.element)
		var raw := ab.damage * data.damage_mult * mult
		var kb := ab.knockback * (1.5 if launcher else 1.0)
		if finisher:
			raw *= FINISHER_MULT
			kb *= 1.3
		var dir := to.normalized()
		if launcher or finisher:
			dir = (dir + Vector3.UP * (0.9 if launcher else 0.6)).normalized()
		var dealt := f.take_hit(global_position, raw, dir * kb, ab.stun_time, ab.element, self, heavy or finisher)
		if dealt > 0.0:
			_vfx_number(f.global_position + Vector3(0, 2.1, 0), dealt, heavy or finisher, is_ult)
			if ab.element == &"ice":
				f.apply_slow(0.65, 1.5) # ice controls space, not just HP
			hit_any = true
			combo_count += 1
			dealt_hit.emit(f, heavy)
			_gain_ult(ab.ult_charge_gain)
		if first_victim == null:
			first_victim = f
	# Volt chain arcs from the first victim to one more nearby enemy.
	if ab.ability_id == &"volt_chain" and first_victim != null:
		var second := _nearest_enemy_to(first_victim.global_position, 4.5, first_victim)
		if second != null:
			var sraw := ab.damage * 0.5 * data.damage_mult
			var sdealt := second.take_hit(first_victim.global_position, sraw, Vector3.ZERO, 0.2, ab.element, self, false)
			if sdealt > 0.0:
				_vfx_number(second.global_position + Vector3(0, 2.1, 0), sdealt, false, false)
				combo_count += 1
				dealt_hit.emit(second, false)
				_gain_ult(ab.ult_charge_gain * 0.5)
				hit_any = true
	# Breakables share the same deterministic melee scan (real interaction).
	for b in get_tree().get_nodes_in_group("breakables"):
		if not (b is Node3D):
			continue
		var prop := b as Node3D
		var to_p: Vector3 = prop.global_position - global_position
		to_p.y = 0.0
		if to_p.length() > ab.range + ab.radius + 0.6:
			continue
		if b.has_method("take_hit"):
			b.take_hit(ab.damage * data.damage_mult, global_position, ab.element)
			hit_any = true
	if hit_any:
		_hitstop(0.05 if not heavy and not finisher else 0.09)
	else:
		_gain_ult(2.0) # whiff still builds a trickle


func _nearest_enemy_to(pos: Vector3, max_dist: float, exclude: Fighter) -> Fighter:
	var best: Fighter = null
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("fighters"):
		if n == self or n == exclude or not (n is Fighter):
			continue
		var f := n as Fighter
		if f.team == team or f.state == St.DEAD:
			continue
		var d := pos.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


func take_hit(from_pos: Vector3, raw: float, knockback: Vector3, stun_time: float, attack_element: StringName, attacker: Node, heavy: bool = false) -> float:
	if state == St.DEAD:
		return 0.0
	if iframes > 0.0:
		_on_perfect_dodge(attacker, from_pos)
		return 0.0
	var blocked := false
	var final := raw
	if block_held and state == St.NORMAL:
		var to_attacker: Vector3 = (from_pos - global_position)
		to_attacker.y = 0.0
		var fwd := -global_transform.basis.z
		if fwd.dot(to_attacker.normalized()) > -0.2:
			final = raw * 0.3 # successful block
			blocked = true
			stun_time *= 0.4
			arm.set_form(MagicArm.Form.SHIELD)
	if state == St.ATTACK and _pending_ult:
		# Ult hyper-armor: damage applies, but nothing interrupts the boom.
		stun_time = 0.0
		knockback = Vector3.ZERO
	health.apply_damage(final, attacker)
	_knock = knockback
	stun = maxf(stun, stun_time)
	arm.play_hit_react()
	_visual.scale = Vector3(0.9, 0.9, 0.9)
	_gain_ult(6.0)
	_audio().play_hit(heavy)
	_vfx_burst("hit_heavy" if heavy else "hit", 1.5)
	_coach_shake(0.35 if not heavy else 0.6)
	hurt_feedback.emit(from_pos, blocked)
	return final


func _on_perfect_dodge(attacker: Node, from_pos: Vector3) -> void:
	# Dashed clean through a real attack: bonus charge + fanfare. Lava and
	# hazards don't count — only enemy fighters.
	if attacker is Fighter:
		var f := attacker as Fighter
		if f.state != St.DEAD and global_position.distance_to(from_pos) < 8.0:
			_gain_ult(PERFECT_DODGE_ULT)
			dodged_clean.emit()
			_audio().play_perfect()


func spawn_decoy() -> void:
	var decoy_data: FighterData = load("res://data/fighters/shadow_decoy.tres")
	var lm := get_node_or_null("/root/LocalizationManager")
	var dname: String = lm.tr_key("decoy_name") if lm else "Shade"
	var d := Fighter.new()
	d.is_decoy = true
	d.setup(decoy_data, team, true, dname)
	d.global_position = global_position + global_transform.basis.z * 1.5
	d.global_position.y = 0.5
	d.rotation.y = rotation.y
	get_parent().add_child(d)
	d._decoy_t = DECOY_LIFETIME
	_vfx_burst("shadow", 2.0)
	_audio().play_dash()


func _gain_ult(amount: float) -> void:
	ult = clampf(ult + amount, 0.0, ULT_MAX)
	ult_changed.emit(ult)
	arm.set_charge(ult / ULT_MAX)


func apply_slow(mult: float, duration: float) -> void:
	# Ice identity: strongest slow wins, duration refreshes to longest.
	if slow_t <= 0.0:
		slow_mult = 1.0
	slow_mult = minf(mult, slow_mult)
	slow_t = maxf(slow_t, duration)


func _on_depleted(_attacker: Node) -> void:
	if state == St.DEAD:
		return
	state = St.DEAD
	_knock = Vector3.ZERO
	_audio().play_hit(true)
	_vfx_burst("ko", 3.0)
	_vfx_ring(4.0)
	# Fall + sink (readable KO, no ragdoll instability on mobile).
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "rotation:z", 1.35, 0.45).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:y", position.y - 0.6, 0.6)
	died.emit(self, _attacker)


func revive_full(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	rotation.y = 0.0
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3.ONE
	fell = false
	ult = maxf(ult, 30.0) # keep some momentum between rounds
	health.reset_full()
	attack_cd = 0.0
	ab1_cd = 0.0
	ab2_cd = 0.0
	dash_cd = 0.0
	dash_time = 0.0
	iframes = 0.0
	stun = 0.0
	slow_t = 0.0
	slow_mult = 1.0
	combo_count = 0
	atk_phase = Ph.WINDUP
	phase_t = 0.0
	_pending_ab = null
	_pending_heavy = false
	_pending_launcher = false
	_pending_finisher = false
	_pending_ult = false
	_pending_clone = false
	_lunge_t = 0.0
	_buffered = ""
	_buffer_t = 0.0
	arm.set_form(MagicArm.Form.FIST)
	state = St.NORMAL


static var _hitstop_depth: int = 0
static var _hitstop_prev: float = 1.0


func _hitstop(duration: float) -> void:
	# Nesting-safe: overlapping hitstops (two fighters landing hits on the
	# same frames) must not corrupt Engine.time_scale on restore. Only the
	# outermost hitstop owns the clock.
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.reduced_motion():
		return
	if _hitstop_depth == 0:
		_hitstop_prev = Engine.time_scale
		Engine.time_scale = 0.05
	_hitstop_depth += 1
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_depth -= 1
	if _hitstop_depth <= 0:
		_hitstop_depth = 0
		Engine.time_scale = _hitstop_prev


func _coach_shake(amount: float) -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("add_trauma"):
		rig.add_trauma(amount)


func _audio() -> Node:
	return get_node_or_null("/root/AudioManager")


func _vfx_burst(kind: String, radius: float) -> void:
	var vm := get_tree().get_first_node_in_group("vfx")
	if vm and vm.has_method("burst"):
		vm.burst(kind, global_position + Vector3(0, 1.2, 0), element, radius)


func _vfx_number(pos: Vector3, amount: float, big: bool, ult: bool) -> void:
	var vm := get_tree().get_first_node_in_group("vfx")
	if vm and vm.has_method("damage_number"):
		vm.damage_number(pos, amount, big, ult)


func _vfx_ring(radius: float) -> void:
	var vm := get_tree().get_first_node_in_group("vfx")
	if vm and vm.has_method("ring"):
		vm.ring(global_position, data.arm_color, radius)
