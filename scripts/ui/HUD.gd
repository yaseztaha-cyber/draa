class_name DraaHUD
extends CanvasLayer
## Fight HUD (§30): top HP/energy both sides, timer center, joystick left,
## action buttons right (>=110px, 16px gaps), cooldown + ult charge states,
## damage flash, countdown center, pause overlay. RTL-first, safe-area
## margins, shape+text coded (never color-only).

class Joystick:
	extends Control
	var value: Vector2 = Vector2.ZERO
	var _touch: int = -1
	var _center: Vector2
	const R := 110.0
	const KNOB := 48.0

	func _init() -> void:
		custom_minimum_size = Vector2(260, 260)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		_center = size / 2.0
		resized.connect(func(): _center = size / 2.0)

	func _draw() -> void:
		draw_circle(_center, R, Color(1, 1, 1, 0.14))
		draw_arc(_center, R, 0, TAU, 48, Color(1, 1, 1, 0.55), 5.0)
		draw_circle(_center + value * (R - KNOB), KNOB, Color(1, 0.62, 0.15, 0.9))
		draw_arc(_center + value * (R - KNOB), KNOB, 0, TAU, 32, Color(0.4, 0.13, 0.05), 4.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch = 0
				_update(event.position)
			else:
				_touch = -1
				value = Vector2.ZERO
				queue_redraw()
		elif event is InputEventMouseMotion and _touch == 0:
			_update(event.position)
		elif event is InputEventScreenTouch:
			if event.pressed:
				_touch = event.index
				_update(event.position)
			elif event.index == _touch:
				_touch = -1
				value = Vector2.ZERO
				queue_redraw()
		elif event is InputEventScreenDrag and event.index == _touch:
			_update(event.position)

	func _update(pos: Vector2) -> void:
		var d := pos - _center
		if d.length() > R:
			d = d.normalized() * R
		value = d / R
		queue_redraw()

var player: Fighter
var match_manager: MatchManager

var _hp_p: ProgressBar
var _ult_p: ProgressBar
var _hp_e: ProgressBar
var _name_p: Label
var _name_e: Label
var _timer: Label
var _round: Label
var _count: Label
var _warn: Label
var _flash: ColorRect
var _joy: Joystick
var _b_atk: Button
var _b_ab: Button
var _b_ab2: Button
var _b_dash: Button
var _b_ult: Button
var _b_block: Button
var _banner: Label
var _combo: Label
var _arrow_l: Label
var _arrow_r: Label
var _rig: CameraRig
var _combo_t: float = 0.0
var _arrow_t: float = 0.0
var _banner_tw: Tween
var _pause_panel: PanelContainer
var _ult_seconds: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS # pause menu must stay clickable
	var lm := get_node_or_null("/root/LocalizationManager")
	var rtl: bool = lm.is_rtl() if lm else true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top(root, lm)
	_build_bottom(root, lm)
	_build_center(root)
	_build_pause(root, lm)


func _t(lm: Node, key: String) -> String:
	return lm.tr_key(key) if lm else key


func _build_top(root: Control, lm: Node) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 28) # status-bar clearance
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var pp := VBoxContainer.new()
	pp.add_theme_constant_override("separation", 6)
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pp)
	_name_p = DraaTheme.make_label("…", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	pp.add_child(_name_p)
	_hp_p = DraaTheme.make_bar(DraaTheme.HP_GOOD, Color(0, 0, 0, 0.55), Vector2(340, 30))
	pp.add_child(_hp_p)
	_ult_p = DraaTheme.make_bar(DraaTheme.ACCENT, Color(0, 0, 0, 0.55), Vector2(340, 16))
	pp.add_child(_ult_p)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(220, 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mid)
	_timer = DraaTheme.make_label("01:30", 44, Color.WHITE)
	mid.add_child(_timer)
	_round = DraaTheme.make_label("", 24, Color(1, 0.9, 0.7))
	mid.add_child(_round)
	var ep := VBoxContainer.new()
	ep.add_theme_constant_override("separation", 6)
	ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ep)
	_name_e = DraaTheme.make_label("…", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	ep.add_child(_name_e)
	_hp_e = DraaTheme.make_bar(DraaTheme.HP_GOOD, Color(0, 0, 0, 0.55), Vector2(340, 30))
	_hp_e.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	ep.add_child(_hp_e)
	# Pause lives top-corner, clear of the bars.
	var pause := DraaTheme.make_button("II", "ghost")
	pause.custom_minimum_size = Vector2(96, 72)
	pause.add_theme_font_size_override("font_size", 30)
	pause.pressed.connect(_toggle_pause)
	box.add_child(pause)


func _build_bottom(root: Control, lm: Node) -> void:
	var bot := HBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.alignment = BoxContainer.ALIGNMENT_BEGIN
	bot.offset_left = 28
	bot.offset_right = -28
	bot.offset_top = -300
	bot.offset_bottom = -28
	bot.add_theme_constant_override("separation", 16)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bot)
	_joy = Joystick.new()
	bot.add_child(_joy)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.add_child(spacer)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot.add_child(grid)
	_b_block = DraaTheme.make_action_button(_t(lm, "block"), "HOLD", 110, Color(0.35, 0.4, 0.5))
	_b_block.name = "BlockBtn"
	_b_block.button_down.connect(_on_block_down)
	_b_block.button_up.connect(_on_block_up)
	grid.add_child(_b_block)
	_b_dash = DraaTheme.make_action_button(_t(lm, "dash"), "", 110, Color(0.2, 0.6, 0.9))
	_b_dash.name = "DashBtn"
	_b_dash.pressed.connect(_on_dash)
	grid.add_child(_b_dash)
	_b_ab = DraaTheme.make_action_button(_t(lm, "ability"), "1", 110, Color(0.55, 0.3, 0.9))
	_b_ab.name = "Ab1Btn"
	_b_ab.pressed.connect(_on_ability)
	grid.add_child(_b_ab)
	_b_ab2 = DraaTheme.make_action_button(_t(lm, "ability_2"), "2", 110, Color(0.45, 0.25, 0.8))
	_b_ab2.name = "Ab2Btn"
	_b_ab2.pressed.connect(_on_ability2)
	grid.add_child(_b_ab2)
	_b_ult = DraaTheme.make_action_button(_t(lm, "ultimate"), "", 130, Color(1, 0.45, 0.08))
	_b_ult.name = "UltBtn"
	_b_ult.pressed.connect(_on_ult)
	grid.add_child(_b_ult)
	_b_atk = DraaTheme.make_action_button(_t(lm, "attack"), "", 140, Color(0.85, 0.2, 0.2))
	_b_atk.name = "AtkBtn"
	_b_atk.pressed.connect(_on_attack)
	grid.add_child(_b_atk)


func _build_center(root: Control) -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_count = DraaTheme.make_label("", 120, Color.WHITE)
	_count.set_anchors_preset(Control.PRESET_CENTER)
	_count.offset_left = -300
	_count.offset_right = 300
	_count.offset_top = -140
	_count.offset_bottom = 40
	root.add_child(_count)
	_banner = DraaTheme.make_label("", 64, Color(1, 0.85, 0.4))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = 200
	_banner.offset_bottom = 300
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_combo = DraaTheme.make_label("", 56, Color(1, 0.75, 0.2))
	_combo.set_anchors_preset(Control.PRESET_CENTER)
	_combo.offset_left = -200
	_combo.offset_right = 200
	_combo.offset_top = 60
	_combo.offset_bottom = 140
	_combo.visible = false
	root.add_child(_combo)
	# Damage-direction edge markers: ASCII chevrons (every font has them),
	# side-coded + flashed, never color-only.
	_arrow_l = DraaTheme.make_label("<<<", 72, Color(1, 0.4, 0.3))
	_arrow_l.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_arrow_l.offset_left = 30
	_arrow_l.offset_right = 230
	_arrow_l.offset_top = -60
	_arrow_l.offset_bottom = 60
	_arrow_l.visible = false
	root.add_child(_arrow_l)
	_arrow_r = DraaTheme.make_label(">>>", 72, Color(1, 0.4, 0.3))
	_arrow_r.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_arrow_r.offset_left = -230
	_arrow_r.offset_right = -30
	_arrow_r.offset_top = -60
	_arrow_r.offset_bottom = 60
	_arrow_r.visible = false
	root.add_child(_arrow_r)
	_warn = DraaTheme.make_label("", 30, Color(1, 0.5, 0.4))
	_warn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warn.offset_left = -400
	_warn.offset_right = 400
	_warn.offset_top = 130
	_warn.offset_bottom = 180
	root.add_child(_warn)


func _build_pause(root: Control, lm: Node) -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -260
	_pause_panel.offset_right = 260
	_pause_panel.offset_top = -220
	_pause_panel.offset_bottom = 220
	_pause_panel.add_theme_stylebox_override("panel", DraaTheme.panel_style())
	_pause_panel.visible = false
	root.add_child(_pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(vb)
	vb.add_child(DraaTheme.make_label(_t(lm, "paused"), 44))
	var resume := DraaTheme.make_button(_t(lm, "resume"), "primary")
	resume.pressed.connect(_toggle_pause)
	vb.add_child(resume)
	var quit := DraaTheme.make_button(_t(lm, "quit"), "danger")
	quit.pressed.connect(func():
		get_tree().paused = false
		var gm := get_node_or_null("/root/GameManager")
		if gm: gm.goto_menu())
	vb.add_child(quit)


func _on_block_down() -> void:
	if player:
		player.set_block(true)


func _on_block_up() -> void:
	if player:
		player.set_block(false)


func _on_dash() -> void:
	if player:
		player.try_dash()


func _on_ability() -> void:
	if player:
		player.try_ability1()


func _on_ability2() -> void:
	if player:
		player.try_ability2()


func _on_ult() -> void:
	if player:
		player.try_ultimate()


func _on_attack() -> void:
	if player:
		player.try_attack()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_pause_panel.visible = get_tree().paused
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_ui()


func bind(p: Fighter, mm: MatchManager, rig: CameraRig) -> void:
	player = p
	match_manager = mm
	_rig = rig
	var lm := get_node_or_null("/root/LocalizationManager")
	_name_p.text = p.display_name
	var foe_name := ""
	for n in get_tree().get_nodes_in_group("fighters"):
		if n != p and n is Fighter and not (n as Fighter).is_decoy:
			foe_name = (n as Fighter).display_name
	_name_e.text = foe_name
	p.hp_changed.connect(_on_hp)
	p.ult_changed.connect(func(_v): pass)
	p.died.connect(func(_f, _k): _pulse_flash(0.45))
	p.dealt_hit.connect(_on_dealt)
	p.hurt_feedback.connect(_on_hurt)
	p.dodged_clean.connect(_on_dodge)
	for n in get_tree().get_nodes_in_group("fighters"):
		if n != p and n is Fighter:
			(n as Fighter).died.connect(_on_foe_died)
	mm.countdown_tick.connect(_on_countdown)
	mm.timer_changed.connect(_on_timer)
	mm.round_changed.connect(_on_round)
	if lm:
		_warn.text = ""
		_on_round(mm.round_index, 0, 0)


func _on_countdown(txt: String, _final: bool) -> void:
	_count.text = txt
	_count_tick_fade()


func _count_tick_fade() -> void:
	_count.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(_count, "modulate:a", 0.25, 0.65)
	tw.tween_callback(func(): _count.text = "")


func _pulse_flash(a: float) -> void:
	_flash.color.a = a
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.4)


func show_banner(text: String, color: Color = Color(1, 0.85, 0.4)) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner.modulate.a = 1.0
	_banner_tw = create_tween()
	_banner_tw.tween_interval(0.9)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _on_dealt(_victim: Fighter, heavy: bool) -> void:
	if player == null:
		return
	if player.combo_count >= 2:
		_combo.text = "x%d%s" % [player.combo_count, "!" if heavy else ""]
		_combo.visible = true
		_combo_t = 1.2


func _on_hurt(from_pos: Vector3, _blocked: bool) -> void:
	_pulse_flash(0.4)
	if _rig == null or _rig.camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var sp := _rig.camera.unproject_position(from_pos)
	_arrow_l.visible = sp.x < vp.x * 0.5
	_arrow_r.visible = not _arrow_l.visible
	_arrow_t = 0.6


func _on_dodge() -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	show_banner(lm.tr_key("perfect_dodge") if lm else "PERFECT!", Color(0.5, 1, 0.6))


func _on_foe_died(f: Fighter, _killer: Node) -> void:
	if f.team == player.team or f.is_decoy:
		return
	var lm := get_node_or_null("/root/LocalizationManager")
	show_banner(lm.tr_key("ko") if lm else "K.O.", Color(1, 0.5, 0.25))


func _on_hp(cur: float, mx: float) -> void:
	_hp_p.max_value = mx
	_hp_p.value = cur
	var frac := cur / maxf(1.0, mx)
	var fill := _hp_p.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = DraaTheme.HP_LOW if frac < 0.3 else DraaTheme.HP_GOOD
	if frac < 0.3:
		var lm := get_node_or_null("/root/LocalizationManager")
		_warn.text = lm.tr_key("health_low") if lm else "LOW HP!"
	else:
		_warn.text = ""


func _on_timer(sec: float) -> void:
	var s := maxf(0.0, sec)
	_timer.text = "%02d:%02d" % [int(s) / 60, int(s) % 60]


func _on_round(idx: int, w0: int, w1: int) -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	var r: String = lm.tr_key("round") if lm else "Round"
	_round.text = "%s %d   %d - %d" % [r, idx, w0, w1]
	if idx >= 1:
		show_banner("%s %d" % [r, idx])


func _process(_delta: float) -> void:
	if player == null or player.state == Fighter.St.DEAD:
		return
	# Joystick owns movement only while deflected — otherwise the keyboard
	# test path (or bot handoff) keeps authority over move_dir.
	var jv: Vector2 = _joy.value
	player.touch_move = jv.length() > 0.08
	if player.touch_move:
		player.move_dir = Vector3(jv.x, 0, jv.y)
	if _combo_t > 0.0:
		_combo_t -= _delta
		if _combo_t <= 0.0:
			_combo.visible = false
	if _arrow_t > 0.0:
		_arrow_t -= _delta
		if _arrow_t <= 0.0:
			_arrow_l.visible = false
			_arrow_r.visible = false
	if player.ult >= Fighter.ULT_MAX and _b_ult.size.x > 0.0:
		_b_ult.pivot_offset = _b_ult.size / 2.0
		var pulse := 1.0 + 0.05 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		_b_ult.scale = Vector2(pulse, pulse)
	elif _b_ult.scale != Vector2.ONE:
		_b_ult.scale = Vector2.ONE
	_refresh_buttons()


func _refresh_buttons() -> void:
	_set_cd(_b_atk, player.attack_cd)
	_set_cd(_b_ab, player.ab1_cd)
	_set_cd(_b_ab2, player.ab2_cd)
	_set_cd(_b_dash, player.dash_cd)
	_b_ult.disabled = player.ult < Fighter.ULT_MAX
	_ult_seconds += get_process_delta_time()
	if _ult_seconds > 0.2:
		_ult_seconds = 0.0
		var lm := get_node_or_null("/root/LocalizationManager")
		var base: String = lm.tr_key("ultimate") if lm else "ULT"
		if player.ult < Fighter.ULT_MAX:
			_b_ult.text = base + "\n%d%%" % int(player.ult)
		else:
			_b_ult.text = base + "\nREADY"
		_ult_p.max_value = 100.0
		_ult_p.value = player.ult
	for n in get_tree().get_nodes_in_group("fighters"):
		if n != player and n is Fighter and not (n as Fighter).is_decoy:
			var f := n as Fighter
			_hp_e.max_value = f.health.maximum
			_hp_e.value = f.health.current
			break


func _set_cd(b: Button, cd: float) -> void:
	b.disabled = cd > 0.02
	b.modulate = Color(1, 1, 1, 0.55 if cd > 0.02 else 1.0)
