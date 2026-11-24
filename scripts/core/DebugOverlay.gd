extends CanvasLayer
## Developer overlay (§37): FPS, memory, object count, physics cost.
## Disabled in production via Settings? Always available, hidden by default:
## toggle with F3 (desktop) or tapping the version label 5x (mobile).
## Never shown in release builds unless explicitly enabled.

var _label: Label
var _taps: int = 0
var _tap_window: float = 0.0
var enabled: bool = false


func _ready() -> void:
	layer = 100
	var tag := Label.new()
	tag.text = "DRAA v0.1"
	tag.add_theme_font_size_override("font_size", 20)
	tag.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tag.offset_left = 12
	tag.offset_top = -44
	tag.offset_right = 200
	tag.offset_bottom = -12
	tag.mouse_filter = Control.MOUSE_FILTER_STOP
	tag.gui_input.connect(_on_tag_input)
	add_child(tag)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.offset_left = 12
	_label.offset_top = 100
	_label.offset_right = 600
	_label.offset_bottom = 260
	_label.visible = false
	add_child(_label)


func _on_tag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_taps += 1
		_tap_window = 2.0
		if _taps >= 5:
			_taps = 0
			enabled = not enabled
			_label.visible = enabled
	elif event is InputEventScreenTouch and event.pressed:
		_taps += 1
		_tap_window = 2.0
		if _taps >= 5:
			_taps = 0
			enabled = not enabled
			_label.visible = enabled


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		enabled = not enabled
		_label.visible = enabled


func _process(delta: float) -> void:
	_tap_window -= delta
	if _tap_window <= 0.0:
		_taps = 0
	if not enabled:
		return
	var fps := Engine.get_frames_per_second()
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var draw := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_label.text = "FPS %.0f | MEM %.0fMB | OBJ %.0f | PHYS %.2fms | DRAW %.0f" % [fps, mem, objs, phys * 1000.0, draw]
