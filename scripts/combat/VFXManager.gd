class_name VFXManager
extends Node3D
## Pooled, low-count CPUParticles3D effects (§36, §37): hit, heavy, dash,
## elemental bursts, KO, victory. Readable by SHAPE + timing, never color
## alone (accessibility): each element has a distinct burst pattern.

var _pool: Dictionary = {}
var _dmg_pool: Array[Label3D] = []
var _ring_pool: Array[MeshInstance3D] = []
const POOL_PER_KIND := 4
const DMG_POOL := 10
const RING_POOL := 3


func _ready() -> void:
	add_to_group("vfx")
	for kind in ["hit", "hit_heavy", "dash", "fire", "ice", "lightning", "shadow", "ultimate", "ko", "victory"]:
		_pool[kind] = []
		for i in POOL_PER_KIND:
			var p := _make(kind)
			p.emitting = false
			add_child(p)
			(_pool[kind] as Array).append(p)
	for i in DMG_POOL:
		var l := _make_dmg_label()
		add_child(l)
		_dmg_pool.append(l)
	for i in RING_POOL:
		var r := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.85
		tor.outer_radius = 1.0
		r.mesh = tor
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = Color(1, 1, 1)
		rmat.emission_enabled = true
		rmat.emission = Color(1, 1, 1)
		rmat.emission_energy_multiplier = 1.5
		r.material_override = rmat
		r.visible = false
		add_child(r)
		_ring_pool.append(r)


func ring(pos: Vector3, color: Color, max_r: float) -> void:
	# Expanding shockwave ring for ultimates/KOs: shape + timing cue.
	for r in _ring_pool:
		if not r.visible:
			r.global_position = pos + Vector3(0, 0.3, 0)
			r.scale = Vector3(0.5, 1.0, 0.5)
			var mat := r.material_override as StandardMaterial3D
			mat.albedo_color = color
			mat.emission = color
			r.visible = true
			var tw := r.create_tween()
			tw.tween_property(r, "scale", Vector3(max_r, 1.0, max_r), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(r.hide)
			return


func _make_dmg_label() -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.pixel_size = 0.01
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.modulate = Color.WHITE
	l.visible = false
	return l


func damage_number(pos: Vector3, amount: float, big: bool, ult: bool) -> void:
	# Floating combat text: actual post-defense damage, size-coded by weight.
	for l in _dmg_pool:
		if not l.visible:
			l.global_position = pos
			l.text = str(int(amount)) + ("!" if big else "")
			if ult:
				l.modulate = Color(1, 0.85, 0.3)
				l.font_size = 120
			elif big:
				l.modulate = Color(1, 0.6, 0.25)
				l.font_size = 96
			else:
				l.modulate = Color.WHITE
				l.font_size = 64
			var c := l.modulate
			c.a = 1.0
			l.modulate = c
			l.visible = true
			var tw := l.create_tween()
			tw.set_parallel(true)
			tw.tween_property(l, "position:y", l.position.y + 1.0, 0.6)
			tw.tween_property(l, "modulate:a", 0.0, 0.6)
			tw.chain().tween_callback(l.hide)
			return


func _make(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	match kind:
		"hit":
			p.amount = 12
			p.spread = 45.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 8.0
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.16
			p.color = Color(1, 0.9, 0.6)
		"hit_heavy":
			p.amount = 22
			p.spread = 60.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 12.0
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.24
			p.color = Color(1, 0.6, 0.2)
		"dash":
			p.amount = 10
			p.lifetime = 0.35
			p.spread = 25.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.color = Color(0.8, 0.9, 1, 0.8)
		"ko":
			p.amount = 36
			p.lifetime = 0.9
			p.spread = 180.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 12.0
			p.color = Color(1, 0.85, 0.3)
		"victory":
			p.amount = 60
			p.lifetime = 1.4
			p.spread = 180.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 9.0
			p.gravity = Vector3(0, -4, 0)
			p.color = Color(1, 0.8, 0.3)
		_:
			p.amount = 20
			p.spread = 70.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 10.0
			p.color = Color(1, 0.5, 0.15)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = p.color
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	quad.material = mat
	p.mesh = quad
	return p


func burst(kind: String, pos: Vector3, element: StringName = &"fire", radius: float = 2.0) -> void:
	var gm := get_node_or_null("/root/GameManager")
	var sm := get_node_or_null("/root/SaveManager")
	var low_fx: bool = gm != null and str(sm.get_setting("quality", "medium") if sm else "medium") == "low"
	if low_fx and kind in ["hit", "dash"]:
		return # low preset skips minor puffs, keeps KO/ult readable
	var key := kind
	if kind in ["hit_heavy", "hit", "ultimate"] and String(element) in ["fire", "ice", "lightning", "shadow"]:
		# Elemental flavor rides on the generic burst for big moments.
		key = kind
	if not _pool.has(key):
		key = "hit"
	for p in (_pool[key] as Array):
		var cp := p as CPUParticles3D
		if not cp.emitting:
			cp.global_position = pos
			# Element tint + distinct scale pulse per element (shape cue).
			match String(element):
				"ice":
					cp.scale_amount_min = 0.1
					cp.scale_amount_max = 0.14
				"lightning":
					cp.scale_amount_min = 0.05
					cp.scale_amount_max = 0.3
				"shadow":
					cp.scale_amount_min = 0.14
					cp.scale_amount_max = 0.2
			cp.restart()
			return
