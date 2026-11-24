class_name DraaArena
extends ArenaBase
## Volcano Temple (§13 arena 1): compact 24m floor, lava-moat hazard,
## 4 pillars, 3 explosive barrels. Everything shared (fighters, HUD,
## match flow, orb) lives in ArenaBase.

var _barrels: Array[Node3D] = []
var _lava_mat: StandardMaterial3D
var _torch_lights: Array[OmniLight3D] = []
var _torch_flames: Array[MeshInstance3D] = []


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1, 0.9, 0.8)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = _sky(Color(0.08, 0.04, 0.12), Color(0.9, 0.35, 0.1), Color(0.05, 0.02, 0.03), Color(0.4, 0.1, 0.05))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 0.55, 0.35)
	e.ambient_light_energy = 0.5
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
	var bm := BoxMesh.new()
	bm.size = Vector3(24, 1, 24)
	mesh.mesh = bm
	mesh.position = Vector3(0, -0.5, 0)
	var gmat := _flat(Color.WHITE)
	gmat.albedo_texture = _noise_tex(Color(0.23, 0.15, 0.17), Color(0.45, 0.26, 0.2), 0.15)
	mesh.material_override = gmat
	add_child(mesh)
	# Lava moat ring: flowing emission texture + hazard (edge pressure).
	var lava := MeshInstance3D.new()
	lava.name = "LavaFlow"
	var ring := TorusMesh.new()
	ring.inner_radius = 11.0
	ring.outer_radius = 15.0
	lava.mesh = ring
	lava.position = Vector3(0, -0.35, 0)
	_lava_mat = StandardMaterial3D.new()
	_lava_mat.albedo_color = Color(0.4, 0.05, 0.02)
	_lava_mat.emission_enabled = true
	_lava_mat.emission = Color(1, 1, 1)
	_lava_mat.emission_texture = _noise_tex(Color(0.9, 0.2, 0.02), Color(1.0, 0.85, 0.2), 0.25)
	_lava_mat.emission_energy_multiplier = 2.0
	lava.material_override = _lava_mat
	add_child(lava)
	var hz := Area3D.new()
	hz.collision_layer = 0
	hz.collision_mask = 6 # player layers 2|4
	var hs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 15.0
	cyl.height = 1.0
	hs.shape = cyl
	hz.add_child(hs)
	hz.body_entered.connect(_on_lava_touch)
	add_child(hz)


func _on_lava_touch(body: Node3D) -> void:
	if body is Fighter:
		var f := body as Fighter
		if f.global_position.distance_to(Vector3.ZERO) > 10.5:
			f.take_hit(f.global_position + Vector3(0, 0, 1), 12.0, Vector3.ZERO, 0.3, &"fire", self)


func _build_props() -> void:
	_build_pillars()
	_build_barrels()
	_build_rim_rocks()
	_build_torches()


func _arena_tick(delta: float) -> void:
	# Lava flow scroll + torch flicker (cheap trig, no textures redrawn).
	if _lava_mat:
		var off: Vector3 = _lava_mat.uv1_offset
		off.x += delta * 0.04
		_lava_mat.uv1_offset = off
	for i in _torch_lights.size():
		var li := _torch_lights[i]
		li.light_energy = 1.1 + 0.3 * sin(_tick * 13.0 + float(i) * 2.1) + 0.15 * sin(_tick * 29.0)
		_torch_flames[i].scale = Vector3.ONE * (1.0 + 0.12 * sin(_tick * 17.0 + float(i) * 3.0))


func _build_rim_rocks() -> void:
	# Basalt rim outside the playable edge: pure decor, no collision.
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.3
		var r := randf_range(13.0, 15.5)
		var rock := MeshInstance3D.new()
		rock.name = "RimRock"
		rock.add_to_group("rim_rocks")
		var sm := SphereMesh.new()
		sm.radial_segments = 7
		sm.rings = 4
		sm.radius = 1.0
		sm.height = 2.0
		rock.mesh = sm
		rock.material_override = _flat(Color(0.14, 0.1, 0.12))
		rock.position = Vector3(cos(a) * r, randf_range(-0.4, 0.6), sin(a) * r)
		rock.scale = Vector3(randf_range(0.8, 1.6), randf_range(1.0, 2.4), randf_range(0.8, 1.6))
		rock.rotation.y = randf() * TAU
		add_child(rock)


func _build_torches() -> void:
	for s in [Vector3(8, 0, -8), Vector3(-8, 0, 8)]:
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.12
		pm.height = 2.0
		pole.mesh = pm
		pole.material_override = _flat(Color(0.2, 0.14, 0.1))
		pole.position = s + Vector3(0, 1.0, 0)
		add_child(pole)
		var flame := MeshInstance3D.new()
		flame.name = "TorchFlame"
		flame.add_to_group("torch_flames")
		var fm := SphereMesh.new()
		fm.radius = 0.28
		fm.height = 0.6
		flame.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(1, 0.6, 0.15)
		fmat.emission_enabled = true
		fmat.emission = Color(1, 0.45, 0.08)
		fmat.emission_energy_multiplier = 2.5
		flame.material_override = fmat
		flame.position = s + Vector3(0, 2.3, 0)
		add_child(flame)
		_torch_flames.append(flame)
		var li := OmniLight3D.new()
		li.light_color = Color(1, 0.55, 0.2)
		li.light_energy = 1.1
		li.omni_range = 7.0
		li.position = s + Vector3(0, 2.5, 0)
		add_child(li)
		_torch_lights.append(li)


func _build_pillars() -> void:
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
		m.material_override = _flat(Color(0.35, 0.22, 0.28))
		add_child(m)


func _build_barrels() -> void:
	var spots: Array[Vector3] = [Vector3(0, 0, 5), Vector3(4, 0, -4), Vector3(-4, 0, -4)]
	for s in spots:
		_spawn_barrel(s)


func _spawn_barrel(pos: Vector3) -> void:
	var barrel := BreakableBarrel.new()
	barrel.position = pos + Vector3(0, 0.6, 0)
	add_child(barrel)
	barrel.exploded.connect(_on_barrel_exploded)
	_barrels.append(barrel)


func _on_barrel_exploded(barrel: BreakableBarrel, from: Vector3) -> void:
	_explode_barrel(barrel, from)


func _explode_barrel(root: Node3D, _from: Vector3) -> void:
	var pos: Vector3 = root.global_position
	_barrels.erase(root)
	root.queue_free()
	vfx.burst("fire", pos, &"fire", 4.0)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_hit(true)
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or f.state == Fighter.St.DEAD:
			continue
		var d := pos.distance_to(f.global_position)
		if d < 4.5:
			var dir: Vector3 = (f.global_position - pos)
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
			f.take_hit(pos, 25.0 * (1.0 - d / 6.0), dir * 12.0, 0.4, &"fire", self, true)
	await get_tree().create_timer(15.0).timeout
	if is_inside_tree():
		_spawn_barrel(Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
