extends Node
## DRAA SaveManager (autoload).
## Single owner of persistence: profile, unlocks, settings, cosmetics.
## Format: JSON at user://draa_save.json. Corruption -> safe fallback + backup.

signal profile_changed
signal settings_changed

const SAVE_PATH := "user://draa_save.json"
const BACKUP_PATH := "user://draa_save.bak.json"
const SAVE_VERSION := 1

var profile: Dictionary = {}
var settings: Dictionary = {}


func _ready() -> void:
	_defaults()
	load_game()


func _defaults() -> void:
	profile = {
		"version": SAVE_VERSION,
		# Seed user data (editable in Profile), not UI chrome.
		"name": "مقاتل جديد",
		"selected_arena": "volcano",
		"xp": 0,
		"level": 1,
		"wins": 0,
		"losses": 0,
		"selected_fighter": "fire",
		"unlocked_fighters": ["fire", "ice", "lightning", "shadow"],
		"cosmetics": {},
	}
	settings = {
		"language": "ar",
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.9,
		"music_enabled": true,
		"sfx_enabled": true,
		"vibration": true,
		"reduce_shake": false,
		"quality": "medium",
	}


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()
	save_game()


func add_xp(amount: int) -> int:
	profile["xp"] = int(profile.get("xp", 0)) + amount
	var new_level := 1 + int(profile["xp"]) / 500
	if new_level != int(profile.get("level", 1)):
		profile["level"] = new_level
	profile_changed.emit()
	save_game()
	return new_level


func rank_name() -> String:
	var lvl := int(profile.get("level", 1))
	var lm := get_node_or_null("/root/LocalizationManager")
	if lvl >= 20:
		return lm.tr_key("rank_champion") if lm else "Champion"
	if lvl >= 10:
		return lm.tr_key("rank_challenger") if lm else "Challenger"
	if lvl >= 5:
		return lm.tr_key("rank_fighter") if lm else "Fighter"
	return lm.tr_key("rank_rookie") if lm else "Rookie"


func record_result(won: bool) -> void:
	if won:
		profile["wins"] = int(profile.get("wins", 0)) + 1
		add_xp(120)
	else:
		profile["losses"] = int(profile.get("losses", 0)) + 1
		add_xp(30)


func save_game() -> bool:
	var data := {"version": SAVE_VERSION, "profile": profile, "settings": settings}
	var json := JSON.stringify(data)
	if FileAccess.file_exists(SAVE_PATH):
		# Keep one backup generation before overwriting.
		var old := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old:
			var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bak:
				bak.store_string(old.get_as_text())
				bak.close()
			old.close()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save file.")
		return false
	f.store_string(json)
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true # First run: defaults are the save.
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_recover_corrupted()
		return false
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != SAVE_VERSION:
		_recover_corrupted()
		return false
	var p: Variant = d.get("profile", {})
	var s: Variant = d.get("settings", {})
	if typeof(p) != TYPE_DICTIONARY or typeof(s) != TYPE_DICTIONARY:
		_recover_corrupted()
		return false
	# Merge over defaults so missing keys from older saves still work.
	var dp := profile.duplicate()
	for k in (p as Dictionary).keys():
		dp[k] = (p as Dictionary)[k]
	profile = dp
	var ds := settings.duplicate()
	for k in (s as Dictionary).keys():
		ds[k] = (s as Dictionary)[k]
	settings = ds
	return true


func _recover_corrupted() -> void:
	push_warning("SaveManager: save corrupted, restoring defaults (backup kept).")
	if FileAccess.file_exists(SAVE_PATH):
		var bad := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if bad:
			var dump := FileAccess.open("user://draa_save.corrupt.json", FileAccess.WRITE)
			if dump:
				dump.store_string(bad.get_as_text())
				dump.close()
			bad.close()
	_defaults()
	save_game()


func reset_all() -> void:
	_defaults()
	save_game()
	profile_changed.emit()
	settings_changed.emit()
