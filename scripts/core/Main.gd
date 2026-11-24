extends Node
## DRAA bootstrap (res://scenes/main/Main.tscn). Hands control to
## GameManager on first frame — all flow lives there.

var _booted: bool = false


func _ready() -> void:
	# Deferred so autoloads finish their _ready first.
	call_deferred("_boot")


func _boot() -> void:
	if _booted:
		return
	_booted = true
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.goto_menu()
	else:
		push_error("Main: GameManager autoload missing.")
