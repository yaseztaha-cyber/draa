class_name DraaResults
extends Control
## Results (§15/§23): victory/defeat in Egyptian voice, XP + rank progress,
## title unlocks from data/rewards/rewards.json, rematch + menu.
## Cosmetics never touch stats — titles are pure flavor.

var _won: bool = false


func _ready() -> void:
	var lm := get_node_or_null("/root/LocalizationManager")
	var gm := get_node_or_null("/root/GameManager")
	var sm := get_node_or_null("/root/SaveManager")
	if lm:
		lm.apply_to_root(self)
	_won = bool(gm.get_meta("last_result", {"won": true}).get("won", true))
	_build(lm, gm, sm)


func _titles_for(wins: int, locale: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists("res://data/rewards/rewards.json"):
		return out
	var f := FileAccess.open("res://data/rewards/rewards.json", FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for t in (parsed as Dictionary).get("titles", []):
		if int(t.get("wins_needed", 9999)) <= wins:
			out.append(str(t.get(locale, t.get("en", ""))))
	return out


func _build(lm: Node, gm: Node, sm: Node) -> void:
	var locale := str(lm.current_locale) if lm else "ar"
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.09, 0.4, 0.16) if _won else Color(0.32, 0.1, 0.12)
	add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -340
	vb.offset_right = 340
	vb.offset_top = -300
	vb.offset_bottom = 300
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	add_child(vb)
	vb.add_child(DraaTheme.make_label(lm.tr_key("victory") if _won else lm.tr_key("defeat"), 90, Color.WHITE))
	var flavor: String = lm.tr_key("reaction_win") if _won else lm.tr_key("reaction_lose")
	vb.add_child(DraaTheme.make_label(flavor, 32, Color(1, 0.95, 0.8)))
	var wins := int(sm.profile.get("wins", 0))
	var titles := _titles_for(wins, locale)
	if not titles.is_empty():
		vb.add_child(DraaTheme.make_label("★ " + str(titles[titles.size() - 1]), 36, Color(1, 0.85, 0.4)))
	vb.add_child(DraaTheme.make_label(
		"%s %d • %s   |   %s %d" % [
			lm.tr_key("xp_level"), int(sm.profile.get("level", 1)), sm.rank_name(),
			lm.tr_key("wins"), wins],
		28, Color.WHITE))
	var again := DraaTheme.make_button(lm.tr_key("rematch"), "primary")
	again.custom_minimum_size = Vector2(420, 104)
	again.pressed.connect(func():
		var am := get_node_or_null("/root/AudioManager")
		if am: am.play_ui()
		gm.start_1v1_vs_bot())
	vb.add_child(again)
	var menu := DraaTheme.make_button(lm.tr_key("main_menu"), "ghost")
	menu.custom_minimum_size = Vector2(420, 96)
	menu.pressed.connect(func(): gm.goto_menu())
	vb.add_child(menu)
