extends SceneTree
## DRAA headless tests: localization coverage, save round-trip, rewards.
## Run: godot --headless --path . -s tests/test_data.gd

var _failures: int = 0


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS  " + name)
	else:
		_failures += 1
		printerr("FAIL  " + name)


func _init() -> void:
	# NOTE: tree-free on purpose — these run before SceneTree.root exists.
	# Localization CSV parses and covers every gameplay key.
	var lm: Node = load("res://scripts/core/LocalizationManager.gd").new()
	lm._load_csv()
	_check(lm._table.size() > 50, "strings.csv has 50+ keys")
	for key in ["play_now", "fight", "choose_fighter", "attack", "ability", "dash",
			"ultimate", "block", "victory", "defeat", "go", "fighter_fire",
			"fighter_ice", "fighter_lightning", "fighter_shadow", "bot", "game_title",
			"health_low", "wins", "losses", "net_disconnected", "err_no_room"]:
		var v: String = lm.tr_key(key)
		_check(v != key and not v.is_empty(), "key localized: " + key)
	_check(lm.is_rtl(), "default locale is Arabic RTL")
	# Rewards table parses and titles unlock in order.
	_check(FileAccess.file_exists("res://data/rewards/rewards.json"), "rewards.json exists")
	var f := FileAccess.open("res://data/rewards/rewards.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	var titles: Array = (parsed as Dictionary).get("titles", [])
	_check(titles.size() >= 4, "4+ titles defined")
	var prev := -1
	var ordered := true
	for t in titles:
		if int(t.get("wins_needed", 0)) < prev:
			ordered = false
		prev = int(t.get("wins_needed", 0))
	_check(ordered, "titles unlock in ascending wins")
	# Arena registry (§13): both arenas resolve to real scenes.
	_check(FileAccess.file_exists("res://data/arenas/arenas.json"), "arenas.json exists")
	var ar := FileAccess.open("res://data/arenas/arenas.json", FileAccess.READ)
	var apare: Variant = JSON.parse_string(ar.get_as_text())
	ar.close()
	var amap: Dictionary = apare as Dictionary
	_check(amap.has("volcano") and amap.has("frozen"), "volcano + frozen registered")
	for aid in ["volcano", "frozen"]:
		var entry: Dictionary = amap[aid]
		_check(FileAccess.file_exists(str(entry.get("scene", ""))), "arena scene exists: " + aid)
	# Save round-trip incl. corrupted-data fallback.
	var sm: Node = load("res://scripts/save/SaveManager.gd").new()
	sm._defaults()
	sm.profile["wins"] = 7
	_check(sm.save_game(), "save writes")
	sm.profile["wins"] = 0
	_check(sm.load_game() and int(sm.profile.get("wins", 0)) == 7, "save reloads wins")
	var bad := FileAccess.open("user://draa_save.json", FileAccess.WRITE)
	bad.store_string("{not valid json!!!")
	bad.close()
	_check(not sm.load_game(), "corrupt save detected")
	_check(int(sm.profile.get("level", 0)) == 1, "corrupt save falls back to defaults")
	sm.reset_all()
	print("---")
	if _failures == 0:
		print("ALL DATA TESTS PASSED")
	else:
		printerr(str(_failures) + " FAILURES")
	quit(_failures)
