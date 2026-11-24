extends Node
## DRAA GameManager (autoload).
## Owns top-level flow: MENU -> SELECT -> ARENA -> RESULTS.
## Applies graphics quality presets + reduced-motion + shake settings.

signal state_changed(new_state: StringName)
signal quality_changed(preset: String)

enum State { MENU, SELECT, ARENA, RESULTS }

var state: int = State.MENU
var selected_fighter: String = "fire"
var selected_arena: String = "volcano"
var difficulty: String = "normal"
var is_2v2: bool = false


func _ready() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		selected_fighter = str(sm.profile.get("selected_fighter", "fire"))
		selected_arena = str(sm.profile.get("selected_arena", "volcano"))
		apply_quality(str(sm.get_setting("quality", "medium")))


func goto_menu() -> void:
	_set_state(State.MENU, "res://scenes/menu/MainMenu.tscn")


func goto_select() -> void:
	_set_state(State.SELECT, "res://scenes/menu/FighterSelect.tscn")


func start_1v1_vs_bot() -> void:
	is_2v2 = false
	_set_state(State.ARENA, arena_scene_path(selected_arena))


func show_results(won: bool) -> void:
	_set_state(State.RESULTS, "res://scenes/ui/ResultsScreen.tscn", {"won": won})


func _set_state(s: int, scene_path: String, extra: Dictionary = {}) -> void:
	state = s
	set_meta("last_result", extra)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("GameManager: cannot load scene " + scene_path + " err=" + str(err))
		return
	state_changed.emit(StringName(["MENU", "SELECT", "ARENA", "RESULTS"][s]))


func set_fighter(fighter_id: String) -> void:
	selected_fighter = fighter_id
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		sm.profile["selected_fighter"] = fighter_id
		sm.save_game()


func set_arena(arena_id: String) -> void:
	selected_arena = arena_id
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		sm.profile["selected_arena"] = arena_id
		sm.save_game()


func arena_scene_path(arena_id: String) -> String:
	var fallback := "res://scenes/arenas/Arena_Volcano.tscn"
	var p := "res://data/arenas/arenas.json"
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has(arena_id):
				var e: Dictionary = (parsed as Dictionary)[arena_id]
				var scene := str(e.get("scene", fallback))
				if FileAccess.file_exists(scene):
					return scene
	push_warning("GameManager: unknown arena " + arena_id + ", using volcano.")
	return fallback


func shake_allowed() -> bool:
	var sm := get_node_or_null("/root/SaveManager")
	return sm == null or not bool(sm.get_setting("reduce_shake", false))


func reduced_motion() -> bool:
	# No OS-level reduced-motion API on Android via Godot; the in-game
	# toggle (reduce_shake) + quality=low together mean "calm mode".
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return false
	return bool(sm.get_setting("reduce_shake", false)) and str(sm.get_setting("quality", "medium")) == "low"


func apply_quality(preset: String) -> void:
	# Low/Medium/High tuned for mid-range Android (draw calls, MSAA, particles).
	match preset:
		"low":
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().scaling_3d_scale = 0.75
			Engine.max_fps = 30
		"high":
			get_viewport().msaa_3d = Viewport.MSAA_4X
			get_viewport().scaling_3d_scale = 1.0
			Engine.max_fps = 60
		_:
			get_viewport().msaa_3d = Viewport.MSAA_2X
			get_viewport().scaling_3d_scale = 0.9
			Engine.max_fps = 60
	quality_changed.emit(preset)
