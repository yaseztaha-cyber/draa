class_name CameraRig
extends Node3D
## Dynamic arena camera (§33): frames all alive fighters, wider for 2v2,
## impact shake (trauma, gated by reduce_shake) + ultimate slow-push.
## Never leaves a living player off-screen: midpoint + distance fit.

var targets: Array[Node3D] = []
var camera: Camera3D
var trauma: float = 0.0
var base_offset := Vector3(0, 11.0, 10.5)
var impact_zoom: float = 0.0

const SHAKE_DECAY := 1.6
const MIN_DIST := 9.0


func _ready() -> void:
	add_to_group("camera_rig")
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 200.0
	add_child(camera)


func track(nodes: Array[Node3D]) -> void:
	targets = nodes


func add_trauma(amount: float) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and not gm.shake_allowed():
		return
	trauma = clampf(trauma + amount * 0.5, 0.0, 1.0)


func punch_zoom() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.reduced_motion():
		return
	impact_zoom = 1.0


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * SHAKE_DECAY)
	impact_zoom = maxf(0.0, impact_zoom - delta * 3.0)
	if targets.is_empty():
		return
	var mid := Vector3.ZERO
	var alive := 0
	var max_sep := 0.0
	for t in targets:
		if not is_instance_valid(t):
			continue
		var f := t as Fighter
		if f and f.state == Fighter.St.DEAD:
			continue
		mid += t.global_position
		alive += 1
	if alive == 0:
		return
	mid /= float(alive)
	for t in targets:
		if is_instance_valid(t):
			max_sep = maxf(max_sep, mid.distance_to(t.global_position))
	var dist := clampf(MIN_DIST + max_sep * 1.15, MIN_DIST, 26.0)
	var want := mid + base_offset.normalized() * dist
	# Impact zoom: dolly slightly toward mid on big hits.
	want = want.lerp(mid + Vector3(0, 6, 6), impact_zoom * 0.12)
	global_position = global_position.lerp(want, minf(1.0, delta * 5.0))
	# Shake: rotational noise scaled by trauma^2 (feels strong, stays readable).
	var s := trauma * trauma
	var rng := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * s * 1.2
	look_at(mid, Vector3.UP)
	rotation += rng * 0.05
