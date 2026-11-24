class_name DraaFighterSelect
extends Control
## Fighter select (§7): 4 data-driven cards (stats bars from FighterData,
## element color + name coded, never color-only), difficulty picker,
## start 1v1 vs bot. RTL-first.

const IDS := ["fire", "ice", "lightning", "shadow"]
## Presentation chips per arena (colors only; names/descs come from data).
const ARENA_CHIPS := {"volcano": Color(1.0, 0.38, 0.08), "frozen": Color(0.45, 0.85, 1.0)}
var _chosen: String = "fire"
var _diff: String = "normal"
var _arena: String = "volcano"
var _cards: Dictionary = {}
var _diff_btns: Dictionary = {}
var _arena_btns: Dictionary = {}


func _ready() -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	var gm := get_node_or_null("/root/GameManager")
	if lm:
		lm.apply_to_root(self)
	_chosen = str(gm.selected_fighter if gm else "fire")
	_diff = str(gm.difficulty if gm else "normal")
	_arena = str(gm.selected_arena if gm else "volcano")
	_build(lm, gm)


func _build(lm: Node, gm: Node) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.05, 0.09)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	margin.add_child(vb)
	vb.add_child(DraaTheme.make_label(lm.tr_key("choose_fighter"), 52, Color.WHITE))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	for fid in IDS:
		grid.add_child(_make_card(fid, lm))
	_refresh_cards()
	# Difficulty row.
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 14)
	vb.add_child(drow)
	drow.add_child(DraaTheme.make_label(lm.tr_key("difficulty"), 32, Color.WHITE))
	for d in ["easy", "normal", "hard"]:
		var b := DraaTheme.make_button(lm.tr_key("diff_" + d), "primary" if d == _diff else "ghost")
		b.custom_minimum_size = Vector2(220, 88)
		b.pressed.connect(func(): _set_diff(d, gm))
		drow.add_child(b)
		_diff_btns[d] = b
	# Arena row (data-driven ids, presentation chips local).
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_theme_constant_override("separation", 14)
	vb.add_child(arow)
	for aid in _arena_ids():
		var info: Dictionary = _arena_info(aid)
		var chip: Color = ARENA_CHIPS.get(aid, Color.WHITE)
		var ab := DraaTheme.make_button(lm.tr_key(str(info.get("name_key", aid))), "primary" if aid == _arena else "ghost")
		ab.custom_minimum_size = Vector2(300, 88)
		ab.tooltip_text = lm.tr_key(str(info.get("desc_key", "")))
		ab.pressed.connect(func(): _set_arena(aid, gm))
		ab.name = "ArenaCard_" + aid
		arow.add_child(ab)
		_arena_btns[aid] = {"btn": ab, "color": chip}
	# Bottom actions.
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 16)
	vb.add_child(brow)
	var back := DraaTheme.make_button(lm.tr_key("back"), "ghost")
	back.custom_minimum_size = Vector2(280, 100)
	back.pressed.connect(func(): gm.goto_menu())
	brow.add_child(back)
	var start := DraaTheme.make_button(lm.tr_key("play_now"), "primary")
	start.custom_minimum_size = Vector2(420, 104)
	start.add_theme_font_size_override("font_size", 40)
	start.pressed.connect(func():
		gm.set_fighter(_chosen)
		gm.difficulty = _diff
		gm.set_arena(_arena)
		gm.start_1v1_vs_bot())
	brow.add_child(start)


func _arena_registry() -> Dictionary:
	var out: Dictionary = {}
	var p := "res://data/arenas/arenas.json"
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				out = parsed as Dictionary
	if out.is_empty():
		out = {"volcano": {}}
	return out


func _arena_ids() -> Array:
	return _arena_registry().keys()


func _arena_info(aid: String) -> Dictionary:
	var reg: Dictionary = _arena_registry()
	var e: Variant = reg.get(aid, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


func _make_card(fid: String, lm: Node) -> PanelContainer:
	var data: FighterData = load("res://data/fighters/" + fid + ".tres")
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", DraaTheme.panel_style(Color.WHITE, data.arm_color, 20))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	# Element chip: color bar + text name (not color-only).
	var chip := ColorRect.new()
	chip.color = data.arm_color
	chip.custom_minimum_size = Vector2(0, 14)
	vb.add_child(chip)
	vb.add_child(DraaTheme.make_label(lm.tr_key(data.name_key), 40))
	vb.add_child(DraaTheme.make_label(lm.tr_key(data.title_key), 26, Color(0.3, 0.3, 0.35)))
	var desc := DraaTheme.make_label(lm.tr_key(data.desc_key), 24, Color(0.25, 0.25, 0.3))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 120)
	vb.add_child(desc)
	for stat in [["HP", data.max_hp / 110.0], ["SPD", data.move_speed / 7.2], ["DMG", data.damage_mult / 1.25]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		var lab := DraaTheme.make_label(str(stat[0]), 22, Color(0.3, 0.3, 0.35), HORIZONTAL_ALIGNMENT_LEFT)
		lab.custom_minimum_size = Vector2(64, 0)
		row.add_child(lab)
		var bar := DraaTheme.make_bar(data.arm_color, Color(0, 0, 0, 0.12), Vector2(0, 20))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = 1.0
		bar.value = clampf(float(stat[1]), 0.05, 1.0)
		bar.show_percentage = false
		row.add_child(bar)
	var pick := DraaTheme.make_button("✓", "primary" if fid == _chosen else "ghost")
	pick.custom_minimum_size = Vector2(0, 80)
	pick.pressed.connect(func(): _set_fighter(fid, lm))
	vb.add_child(pick)
	_cards[fid] = {"panel": p, "btn": pick, "color": data.arm_color}
	return p


func _set_fighter(fid: String, _lm: Node) -> void:
	_chosen = fid
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_ui()
	_refresh_cards()


func _set_diff(d: String, gm: Node) -> void:
	_diff = d
	gm.difficulty = d
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_ui()
	_refresh_cards()


func _set_arena(aid: String, gm: Node) -> void:
	_arena = aid
	gm.set_arena(aid)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_ui()
	_refresh_cards()


func _refresh_cards() -> void:
	for fid in _cards.keys():
		var e: Dictionary = _cards[fid]
		var selected: bool = fid == _chosen
		var btn := e["btn"] as Button
		btn.text = "✓ " if selected else "○"
		(btn.get_theme_stylebox("normal") as StyleBoxFlat).border_color = Color.WHITE if selected else (e["color"] as Color).darkened(0.2)
	for d in _diff_btns.keys():
		var db := _diff_btns[d] as Button
		var on: bool = d == _diff
		var bg := DraaTheme.PRIMARY if on else Color(1, 1, 1, 0.12)
		var border := DraaTheme.INK if on else Color(1, 1, 1, 0.5)
		db.add_theme_stylebox_override("normal", DraaTheme.button_style(bg, border))
		db.add_theme_color_override("font_color", DraaTheme.ON_PRIMARY if on else Color.WHITE)
	for aid in _arena_btns.keys():
		var e2: Dictionary = _arena_btns[aid]
		var ab := e2["btn"] as Button
		var aon: bool = aid == _arena
		var abg := DraaTheme.PRIMARY if aon else Color(1, 1, 1, 0.12)
		var aborder := (e2["color"] as Color) if aon else Color(1, 1, 1, 0.5)
		ab.add_theme_stylebox_override("normal", DraaTheme.button_style(abg, aborder))
		ab.add_theme_color_override("font_color", DraaTheme.ON_PRIMARY if aon else Color.WHITE)
