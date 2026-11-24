class_name DraaMainMenu
extends Control
## Arabic-first 3D main menu (§6): live fighter preview (idle MagicArm),
## primary CTA "العب دلوقتي", fighter select, profile, settings.
## Only shipped systems are shown — no dead buttons.

var _preview_arm: MagicArm
var _preview: FighterVisual
var _pivot: Node3D
var _t: float = 0.0
var _panel_host: CenterContainer


func _ready() -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	if lm:
		lm.apply_to_root(self)
	_build_preview()
	_build_ui(lm)


func _build_preview() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.2, 5.2)
	cam.rotation = Vector3(-0.25, 0, 0)
	sv.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	sun.light_energy = 1.2
	sv.add_child(sun)
	var gm := get_node_or_null("/root/GameManager")
	var fid := str(gm.selected_fighter if gm else "fire")
	var data: FighterData = load("res://data/fighters/" + fid + ".tres")
	# Pedestal: stepped stone + glowing rune ring in the fighter's element.
	_pivot = Node3D.new()
	sv.add_child(_pivot)
	for step_i in [0, 1]:
		var step_m := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		var r := 1.9 - 0.3 * float(step_i)
		disc.top_radius = r
		disc.bottom_radius = r + 0.3
		disc.height = 0.3
		step_m.mesh = disc
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.25, 0.16, 0.2).darkened(0.15 * float(step_i))
		step_m.material_override = fm
		step_m.position = Vector3(0, 0.15 + 0.3 * float(step_i), 0)
		_pivot.add_child(step_m)
	# Full cartoon fighter — identical builder to the arena (menu = game).
	_preview = FighterVisual.build(data if data else FighterData.new())
	_preview.position = Vector3(0, 0.6, 0)
	_pivot.add_child(_preview)
	_preview_arm = _preview.arm
	if data:
		var rune := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 2.0
		tor.outer_radius = 2.2
		rune.mesh = tor
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = data.arm_color
		rmat.emission_enabled = true
		rmat.emission = data.arm_color
		rmat.emission_energy_multiplier = 0.9
		rune.material_override = rmat
		rune.position = Vector3(0, 0.62, 0)
		_pivot.add_child(rune)
	# Warm rim light in the fighter's element color.
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 2.5, -2)
	rim.light_energy = 0.8
	rim.omni_range = 8.0
	if data:
		rim.light_color = data.arm_color
	_pivot.add_child(rim)


func _build_ui(lm: Node) -> void:
	var dim := ColorRect.new() # legibility scrim over 3D (measured, not decorative)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.02, 0.05, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var title := DraaTheme.make_label(lm.tr_key("game_title") if lm else "DRAA", 110, Color(1, 0.75, 0.3))
	root.add_child(title)
	var sub := DraaTheme.make_label("DRAA • " + (lm.tr_key("reaction_start") if lm else ""), 30, Color.WHITE)
	root.add_child(sub)
	var cta := DraaTheme.make_button(lm.tr_key("play_now") if lm else "Play", "primary")
	cta.custom_minimum_size = Vector2(460, 110)
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cta.add_theme_font_size_override("font_size", 44)
	cta.pressed.connect(_on_play)
	root.add_child(cta)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	var b_sel := DraaTheme.make_button(lm.tr_key("choose_fighter") if lm else "Fighters", "ghost")
	b_sel.custom_minimum_size = Vector2(300, 96)
	b_sel.pressed.connect(_on_select)
	row.add_child(b_sel)
	var b_prof := DraaTheme.make_button(lm.tr_key("profile") if lm else "Profile", "ghost")
	b_prof.custom_minimum_size = Vector2(240, 96)
	b_prof.pressed.connect(func(): _show_profile(lm))
	row.add_child(b_prof)
	var b_set := DraaTheme.make_button(lm.tr_key("settings") if lm else "Settings", "ghost")
	b_set.custom_minimum_size = Vector2(240, 96)
	b_set.pressed.connect(func(): _show_settings(lm))
	row.add_child(b_set)
	_panel_host = CenterContainer.new()
	_panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_host.visible = false
	add_child(_panel_host)


func _process(delta: float) -> void:
	_t += delta
	if _pivot and is_instance_valid(_pivot):
		var gm := get_node_or_null("/root/GameManager")
		if not (gm and gm.reduced_motion()):
			_pivot.rotation.y += delta * 0.5


func _on_play() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_ui()
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.start_1v1_vs_bot()


func _on_select() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_ui()
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.goto_select()


func _dim_panel() -> PanelContainer:
	for c in _panel_host.get_children():
		c.queue_free()
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(640, 0)
	p.add_theme_stylebox_override("panel", DraaTheme.panel_style())
	_panel_host.add_child(p)
	_panel_host.visible = true
	return p


func _close_panel() -> void:
	_panel_host.visible = false
	for c in _panel_host.get_children():
		c.queue_free()


func _show_profile(lm: Node) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var p := _dim_panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(vb)
	vb.add_child(DraaTheme.make_label(lm.tr_key("profile"), 44))
	var name_edit := LineEdit.new()
	name_edit.text = str(sm.profile.get("name", ""))
	name_edit.custom_minimum_size = Vector2(0, 80)
	name_edit.add_theme_font_override("font", DraaTheme.font())
	name_edit.add_theme_font_size_override("font_size", 32)
	vb.add_child(name_edit)
	var stats := DraaTheme.make_label(
		"%s %d • %s\n%s %d • %s %d" % [
			lm.tr_key("xp_level"), int(sm.profile.get("level", 1)), sm.rank_name(),
			lm.tr_key("wins"), int(sm.profile.get("wins", 0)),
			lm.tr_key("losses"), int(sm.profile.get("losses", 0))],
		30)
	vb.add_child(stats)
	var save := DraaTheme.make_button("✓", "primary")
	save.pressed.connect(func():
		sm.profile["name"] = name_edit.text.strip_edges() if not name_edit.text.strip_edges().is_empty() else "مقاتل"
		sm.save_game()
		sm.profile_changed.emit()
		_close_panel())
	vb.add_child(save)
	var back := DraaTheme.make_button(lm.tr_key("back"), "ghost")
	back.pressed.connect(_close_panel)
	vb.add_child(back)


func _show_settings(lm: Node) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	var gm := get_node_or_null("/root/GameManager")
	var p := _dim_panel()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	vb.add_child(DraaTheme.make_label(lm.tr_key("settings"), 44))
	# Language.
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	vb.add_child(lang_row)
	lang_row.add_child(DraaTheme.make_label(lm.tr_key("language"), 30))
	var b_ar := DraaTheme.make_button("عربي", "primary" if str(sm.get_setting("language", "ar")) == "ar" else "ghost")
	var b_en := DraaTheme.make_button("EN", "primary" if str(sm.get_setting("language", "ar")) == "en" else "ghost")
	b_ar.pressed.connect(func():
		lm.set_locale(&"ar")
		lm.apply_to_root(self)
		_close_panel()
		_show_settings(lm))
	b_en.pressed.connect(func():
		lm.set_locale(&"en")
		lm.apply_to_root(self)
		_close_panel()
		_show_settings(lm))
	lang_row.add_child(b_ar)
	lang_row.add_child(b_en)
	# Toggles.
	for key in ["music_enabled", "sfx_enabled", "vibration", "reduce_shake"]:
		var t := CheckButton.new()
		t.text = lm.tr_key({"music_enabled": "music", "sfx_enabled": "sfx", "vibration": "vibration", "reduce_shake": "reduce_shake"}[key])
		t.button_pressed = bool(sm.get_setting(key, true))
		t.add_theme_font_override("font", DraaTheme.font())
		t.add_theme_font_size_override("font_size", 30)
		t.toggled.connect(func(on: bool): sm.set_setting(key, on))
		vb.add_child(t)
	# Quality.
	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 12)
	vb.add_child(q_row)
	q_row.add_child(DraaTheme.make_label(lm.tr_key("quality"), 30))
	for q in ["low", "medium", "high"]:
		var b := DraaTheme.make_button(lm.tr_key("quality_" + q), "primary" if str(sm.get_setting("quality", "medium")) == q else "ghost")
		b.custom_minimum_size = Vector2(0, 80)
		b.pressed.connect(func():
			sm.set_setting("quality", q)
			if gm: gm.apply_quality(q))
		q_row.add_child(b)
	var back := DraaTheme.make_button(lm.tr_key("back"), "ghost")
	back.pressed.connect(_close_panel)
	vb.add_child(back)
