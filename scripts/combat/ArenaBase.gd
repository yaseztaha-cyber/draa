class_name ArenaBase
extends Node3D
## Shared arena framework (§13–16): subclasses build their own environment
## (lighting, floor, props, hazards); everything else — fighters, HUD,
## match flow, ult orb — is common and lives here. Keeps every .tscn tiny
## and every arena mobile-friendly (1 dir light + ambient, no realtime GI).

var rig: CameraRig
var vfx: VFXManager
var match_manager: MatchManager
var hud: DraaHUD
## When false, match end stays in the arena (integration tests drive the
## flow themselves). Production leaves this true: results screen auto-shows.
var auto_show_results: bool = true

var _orb: Area3D
var _orb_mesh: MeshInstance3D
var _orb_cd: float = 0.0
var _tick: float = 0.0


## --- Subclass contract (override what differs) ---

func ground_traction() -> float:
	return 1.0


func spawn_points() -> Array[Vector3]:
	return [Vector3(-6, 0.5, 0), Vector3(6, 0.5, 0)]


func orb_tint() -> Color:
	return Color(0.4, 0.8, 1)


func _build_lighting() -> void:
	pass


func _build_environment() -> void:
	pass


func _build_props() -> void:
	pass


func _arena_tick(_delta: float) -> void:
	pass


## --- Shared flow ---

func _ready() -> void:
	_build_lighting()
	_build_environment()
	_build_props()
	_build_orb()
	rig = CameraRig.new()
	add_child(rig)
	vfx = VFXManager.new()
	add_child(vfx)
	match_manager = MatchManager.new()
	add_child(match_manager)
	_spawn_fighters()
	_spawn_hud()
	_wire()
	match_manager.start_match()


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _noise_tex(base: Color, glow: Color, freq: float) -> NoiseTexture2D:
	# Procedural surface detail with zero shipped assets: simplex noise
	# through a two-stop ramp. Generates async; pops in within a second.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = freq
	noise.fractal_octaves = 3
	var grad := Gradient.new()
	grad.set_color(0, base)
	grad.set_color(1, glow)
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = noise
	nt.color_ramp = grad
	return nt


func _sky(sky_top: Color, sky_horizon: Color, ground_bottom: Color, ground_horizon: Color) -> Sky:
	var skym := ProceduralSkyMaterial.new()
	skym.sky_top_color = sky_top
	skym.sky_horizon_color = sky_horizon
	skym.ground_bottom_color = ground_bottom
	skym.ground_horizon_color = ground_horizon
	var sky := Sky.new()
	sky.sky_material = skym
	return sky


func _build_orb() -> void:
	_orb = Area3D.new()
	_orb.collision_layer = 0
	_orb.collision_mask = 6
	_orb.position = Vector3(0, 1.0, 0)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 1.0
	cs.shape = ss
	_orb.add_child(cs)
	_orb_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	_orb_mesh.mesh = sm
	var tint := orb_tint()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.5
	_orb_mesh.material_override = mat
	_orb.add_child(_orb_mesh)
	_orb.body_entered.connect(_on_orb_pickup)
	add_child(_orb)


func _on_orb_pickup(body: Node3D) -> void:
	if _orb_cd > 0.0 or not (body is Fighter):
		return
	var f := body as Fighter
	if f.state == Fighter.St.DEAD:
		return
	_orb_cd = 20.0
	_orb_mesh.visible = false
	f._gain_ult(40.0)


func _process(delta: float) -> void:
	_tick += delta
	if _orb_mesh:
		_orb_mesh.rotation.y += delta * 2.0
		_orb.position.y = 1.0 + sin(_tick * 2.0) * 0.15
	if _orb_cd > 0.0:
		_orb_cd -= delta
		if _orb_cd <= 0.0 and _orb_mesh:
			_orb_mesh.visible = true
	_arena_tick(delta)


func _spawn_fighters() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var player_id := str(gm.selected_fighter if gm else "fire")
	var bot_id := "fire"
	var opts: Array[String] = ["ice", "lightning", "shadow", "fire"]
	bot_id = opts[randi() % opts.size()]
	var spawns := spawn_points()
	var f1 := _make_fighter(player_id, 0, false, _profile_name(), spawns[0])
	var diff := str(gm.difficulty if gm else "normal")
	var lm := get_node_or_null("/root/LocalizationManager")
	var bot_name: String = lm.tr_key("bot") if lm else "Bot"
	var f2 := _make_fighter(bot_id, 1, true, bot_name, spawns[1])
	var bot := BotController.new()
	bot.setup(f2, diff)
	f2.add_child(bot)
	var team: Array[Fighter] = [f1, f2]
	var nodes: Array[Node3D] = [f1, f2]
	match_manager.configure(team, spawns)
	rig.track(nodes)


func _profile_name() -> String:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		return str(sm.profile.get("name", "Player"))
	return "Player"


func _make_fighter(fid: String, team: int, is_bot: bool, pname: String, at: Vector3) -> Fighter:
	var data: FighterData = load("res://data/fighters/" + fid + ".tres")
	var f := Fighter.new()
	f.setup(data, team, is_bot, pname)
	f.traction = ground_traction()
	f.position = at
	add_child(f)
	return f


func _spawn_hud() -> void:
	hud = DraaHUD.new()
	add_child(hud)


func _wire() -> void:
	if match_manager.fighters.size() < 2:
		push_error("Arena: match has no fighters, HUD not bound.")
		return
	var player := match_manager.fighters[0]
	hud.bind(player, match_manager, rig)
	match_manager.match_ended.connect(_on_match_end)


func _on_match_end(player_won: bool) -> void:
	if not auto_show_results:
		return
	await get_tree().create_timer(1.2).timeout
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.show_results(player_won)
