class_name ArenaFrozen
extends ArenaBase
## Frozen Ruins (§13 arena 2): black-ice floor (traction 0.12 — positioning
## matters), ice pillars, falling-ice hazard with fair telegraphs, pale orb.
## Ice rewards control over damage: shards slow as well as hurt.

const SHARD_COUNT := 3
const SHARD_DAMAGE := 15.0
const SHARD_RADIUS := 2.5
const SHARD_FALL_TIME := 0.25
const SHARD_MIN_GAP := 4.0
const SHARD_MAX_GAP := 7.0

var _shard_root: Array[Node3D] = []
var _shard_ring: Array[MeshInstance3D] = []
var _shard_ice: Array[MeshInstance3D] = []
var _shard_state: Array[int] = [] # 0 idle, 1 telegraph, 2 falling
var _shard_t: Array[float] = []
var _shard_target: Array[Vector3] = []
var _spawn_t: float = 3.0


func ground_traction() -> float:
	return 0.12


func orb_tint() -> Color:
	return Color(0.75, 0.95, 1.0)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(0.85, 0.92, 1.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = _sky(Color(0.02, 0.05, 0.12), Color(0.5, 0.75, 0.95), Color(0.02, 0.04, 0.08), Color(0.2, 0.35, 0.5))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.75, 1.0)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)


func _build_environment() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 1, 24)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "IceFloor"
	var bm := BoxMesh.new()
	bm.size = Vector3(24, 1, 24)
	mesh.mesh = bm
	mesh.position = Vector3(0, -0.5, 0)
	var gmat := _flat(Color.WHITE)
	gmat.albedo_texture = _noise_tex(Color(0.72, 0.83, 0.93), Color(0.95, 0.99, 1.0), 0.2)
	gmat.roughness = 0.25
	gmat.metallic = 0.1
	mesh.material_override = gmat
	add_child(mesh)
	# Frost rim: pale ring marking the playable edge (no lava here).
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 11.0
	ring.outer_radius = 12.0
	rim.mesh = ring
	rim.position = Vector3(0, -0.3, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.85, 0.95, 1.0)
	rmat.emission_enabled = true
	rmat.emission = Color(0.6, 0.85, 1.0)
	rmat.emission_energy_multiplier = 0.6
	rim.material_override = rmat
	add_child(rim)


func _build_props() -> void:
	var spots: Array[Vector3] = [Vector3(6, 0, 6), Vector3(-6, 0, 6), Vector3(6, 0, -6), Vector3(-6, 0, -6)]
	for s in spots:
		var st := StaticBody3D.new()
		st.collision_layer = 1
		st.position = s
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 3.4, 1.4)
		col.shape = box
		col.position = Vector3(0, 1.7, 0)
		st.add_child(col)
		add_child(st)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 3.4, 1.4)
		m.mesh = bm
		m.position = s + Vector3(0, 1.7, 0)
		var imat := StandardMaterial3D.new()
		imat.albedo_color = Color(0.55, 0.8, 1.0)
		imat.emission_enabled = true
		imat.emission = Color(0.4, 0.7, 1.0)
		imat.emission_energy_multiplier = 0.35
		m.material_override = imat
		add_child(m)
	for i in SHARD_COUNT:
		_build_shard()
	_build_spikes()
	_build_snowfall()


func _build_spikes() -> void:
	# Frozen fangs around the rim: pure decor, no collision.
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.6
		var spike := MeshInstance3D.new()
		spike.name = "IceSpike"
		spike.add_to_group("ice_spikes")
		var prism := PrismMesh.new()
		prism.size = Vector3(0.9, randf_range(2.0, 3.6), 0.9)
		spike.mesh = prism
		spike.material_override = _flat(Color(0.6, 0.82, 1.0))
		spike.position = Vector3(cos(a) * 13.5, 0.6, sin(a) * 13.5)
		spike.rotation.y = randf() * TAU
		add_child(spike)


func _build_snowfall() -> void:
	# One ambient snow system (40 motes, looping): cheap winter air.
	var snow := CPUParticles3D.new()
	snow.name = "SnowFall"
	snow.amount = 40
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.explosiveness = 0.0
	snow.randomness = 0.6
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(12, 1, 12)
	snow.direction = Vector3(0, -1, 0)
	snow.spread = 8.0
	snow.initial_velocity_min = 0.8
	snow.initial_velocity_max = 1.6
	snow.gravity = Vector3.ZERO
	snow.scale_amount_min = 0.04
	snow.scale_amount_max = 0.09
	snow.color = Color(0.95, 0.98, 1.0, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.95, 0.98, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	quad.material = mat
	snow.mesh = quad
	snow.position = Vector3(0, 8, 0)
	add_child(snow)


func _build_shard() -> void:
	var root := Node3D.new()
	root.visible = false
	add_child(root)
	var ring_mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = SHARD_RADIUS - 0.4
	tor.outer_radius = SHARD_RADIUS
	ring_mi.mesh = tor
	ring_mi.position = Vector3(0, 0.06, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1, 1, 1)
	rmat.emission_enabled = true
	rmat.emission = Color(0.7, 0.95, 1.0)
	rmat.emission_energy_multiplier = 1.2
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mi.material_override = rmat
	root.add_child(ring_mi)
	var ice := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 1.6, 0.5)
	ice.mesh = prism
	ice.position = Vector3(0, 6.0, 0)
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color(0.8, 0.95, 1.0)
	imat.emission_enabled = true
	imat.emission = Color(0.6, 0.85, 1.0)
	imat.emission_energy_multiplier = 0.8
	ice.material_override = imat
	root.add_child(ice)
	_shard_root.append(root)
	_shard_ring.append(ring_mi)
	_shard_ice.append(ice)
	_shard_state.append(0)
	_shard_t.append(0.0)
	_shard_target.append(Vector3.ZERO)


func _arena_tick(delta: float) -> void:
	if match_manager.phase == "fight":
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = randf_range(SHARD_MIN_GAP, SHARD_MAX_GAP)
			_try_telegraph()
	for i in _shard_root.size():
		_tick_shard(i, delta)


func _tick_shard(i: int, delta: float) -> void:
	if _shard_state[i] == 1:
		_shard_t[i] -= delta
		var pulse := 1.0 + 0.15 * sin(_tick * 10.0)
		_shard_ring[i].scale = Vector3(pulse, 1.0, pulse)
		if _shard_t[i] <= 0.0:
			_shard_state[i] = 2
			_shard_t[i] = SHARD_FALL_TIME
			_shard_ice[i].visible = true
	elif _shard_state[i] == 2:
		_shard_t[i] -= delta
		var k := 1.0 - maxf(_shard_t[i], 0.0) / SHARD_FALL_TIME
		_shard_ice[i].position.y = lerpf(6.0, 0.4, k)
		if _shard_t[i] <= 0.0:
			_land_shard(i)


func _try_telegraph() -> void:
	var foes := _living_foes()
	if foes.is_empty():
		return
	var pick: Fighter = foes[randi() % foes.size()]
	_drop_shard_at(pick.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), 1.2)


func _living_foes() -> Array[Fighter]:
	var out: Array[Fighter] = []
	for n in get_tree().get_nodes_in_group("fighters"):
		if n is Fighter:
			var f := n as Fighter
			if f.state != Fighter.St.DEAD and not f.is_decoy:
				out.append(f)
	return out


func _drop_shard_at(pos: Vector3, telegraph: float = 1.2) -> void:
	pos.y = 0.0
	if absf(pos.x) > 10.0 or absf(pos.z) > 10.0:
		return # keep impacts inside the playable floor
	for i in _shard_root.size():
		if _shard_state[i] == 0:
			_shard_state[i] = 1
			_shard_t[i] = telegraph
			_shard_target[i] = pos
			_shard_root[i].position = pos
			_shard_root[i].visible = true
			_shard_ice[i].visible = false
			_shard_ice[i].position.y = 6.0
			var am := get_node_or_null("/root/AudioManager")
			if am:
				am.play_telegraph()
			if telegraph <= 0.0:
				_shard_state[i] = 2
				_shard_t[i] = SHARD_FALL_TIME
				_shard_ice[i].visible = true
			return


func _land_shard(i: int) -> void:
	var pos: Vector3 = _shard_target[i]
	_shard_state[i] = 0
	_shard_root[i].visible = false
	vfx.burst("ice", pos + Vector3(0, 0.8, 0), &"ice", SHARD_RADIUS)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_hit(true)
	for n in get_tree().get_nodes_in_group("fighters"):
		if not (n is Fighter):
			continue
		var f := n as Fighter
		if f.state == Fighter.St.DEAD:
			continue
		var to: Vector3 = f.global_position - pos
		to.y = 0.0
		if to.length() < SHARD_RADIUS:
			var dir := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
			f.take_hit(pos, SHARD_DAMAGE, dir * 7.0, 0.5, &"ice", self, false)
			f.apply_slow(0.55, 2.0)
