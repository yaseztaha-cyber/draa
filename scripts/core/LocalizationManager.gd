extends Node
## DRAA LocalizationManager (autoload).
## Arabic-first, RTL-aware, data-driven. No UI strings are hard-coded in
## gameplay scripts — everything goes through tr_key().
## Source of truth: res://data/localization/strings.csv (key,ar,en).

signal locale_changed(new_locale: StringName)

const STRINGS_PATH := "res://data/localization/strings.csv"
const SUPPORTED := ["ar", "en"]

var _table: Dictionary = {}
var current_locale: StringName = &"ar"


func _ready() -> void:
	var saved: String = ""
	if has_node("/root/SaveManager"):
		saved = str(get_node("/root/SaveManager").get_setting("language", "ar"))
	if saved in SUPPORTED:
		current_locale = StringName(saved)
	_load_csv()


func _load_csv() -> void:
	_table.clear()
	if not FileAccess.file_exists(STRINGS_PATH):
		push_error("Localization CSV missing: " + STRINGS_PATH)
		return
	var f := FileAccess.open(STRINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open localization CSV.")
		return
	var first := true
	while not f.eof_reached():
		var line := f.get_line()
		if first:
			first = false
			continue
		if line.strip_edges().is_empty():
			continue
		# Keys never contain commas; values may, so split max 3 parts.
		var parts := line.split(",", true, 2)
		if parts.size() < 3:
			continue
		_table[parts[0].strip_edges()] = {
			"ar": parts[1].strip_edges(),
			"en": parts[2].strip_edges(),
		}
	f.close()


func set_locale(locale: StringName) -> void:
	var l := String(locale)
	if not (l in SUPPORTED):
		push_warning("Unsupported locale: " + l)
		return
	current_locale = StringName(l)
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").set_setting("language", l)
	locale_changed.emit(current_locale)


func tr_key(key: String, fallback_locale: String = "en") -> String:
	if _table.has(key):
		var entry: Dictionary = _table[key]
		var v := str(entry.get(String(current_locale), ""))
		if not v.is_empty():
			return v
		return str(entry.get(fallback_locale, key))
	return key


func is_rtl() -> bool:
	return current_locale == &"ar"


func apply_to_root(control: Control) -> void:
	control.layout_direction = Control.LAYOUT_DIRECTION_RTL if is_rtl() else Control.LAYOUT_DIRECTION_LTR


func eastern_arabic_numerals(text: String) -> String:
	# Keep gameplay numbers Latin-readable per UX rule (tabular, no layout
	# shift), so this helper is opt-in for flavor text only.
	var western := "0123456789"
	var eastern := "٠١٢٣٤٥٦٧٨٩"
	var out := text
	for i in western.length():
		out = out.replace(western[i], eastern[i])
	return out
