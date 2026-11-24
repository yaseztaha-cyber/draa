class_name MagicArm
extends Node3D
## The one supernatural combat arm (§8). Procedurally built (no binary
## assets): shoulder block + morphing forearm + fist/blade/shield heads,
## emissive element material, idle bob, charge glow, attack lunge.
## Forms unlock more later; system is data-driven via set_form().

enum Form { FIST, BLADE, SHIELD }

var form: int = Form.FIST
var element: StringName = &"fire"
var arm_color: Color = Color(1.0, 0.38, 0.08)
var charge: float = 0.0 # 0..1 ultimate charge glow

var _root: MeshInstance3D
var _head: MeshInstance3D
var _glow: OmniLight3D
var _mat: StandardMaterial3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _extra: MeshInstance3D
var _extra_mat: StandardMaterial3D
var _t: float = 0.0
var _lunge: float = 0.0
var _base_pos: Vector3


func _ready() -> void:
	_base_pos = position
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = arm_color
	_mat.emission_enabled = true
	_mat.emission = arm_color
	_mat.emission_energy_multiplier = 0.8
	_mat.roughness = 0.35
	# Shoulder block: big dark-metal pad anchoring the supernatural limb.
	var padm := StandardMaterial3D.new()
	padm.albedo_color = Color(0.22, 0.19, 0.27)
	padm.metallic = 0.7
	padm.roughness = 0.4
	var pad := MeshInstance3D.new()
	var psm := SphereMesh.new()
	psm.radius = 0.26
	psm.height = 0.4
	pad.mesh = psm
	pad.material_override = padm
	pad.position = Vector3(0, 0.28, 0.25)
	pad.scale = Vector3(1.0, 0.7, 1.0)
	pad.name = "ShoulderPad"
	add_child(pad)
	_root = MeshInstance3D.new()
	var upper := BoxMesh.new()
	upper.size = Vector3(0.34, 0.34, 0.7)
	_root.mesh = upper
	_root.material_override = _mat
	add_child(_root)
	# Elbow core: the element heart. Pulses harder as the ult charges.
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = arm_color
	_core_mat.emission_enabled = true
	_core_mat.emission = arm_color
	_core_mat.emission_energy_multiplier = 1.2
	_core = MeshInstance3D.new()
	var csm := SphereMesh.new()
	csm.radius = 0.12
	csm.height = 0.24
	_core.mesh = csm
	_core.material_override = _core_mat
	_core.position = Vector3(0, -0.18, -0.25)
	_core.name = "ArmCore"
	add_child(_core)
	_head = MeshInstance3D.new()
	_head.position = Vector3(0, 0, -0.55)
	_head.material_override = _mat
	add_child(_head)
	# Per-form garnish (knuckles / edge / boss), rebuilt with the head.
	_extra_mat = StandardMaterial3D.new()
	_extra_mat.albedo_color = Color(1, 1, 1)
	_extra_mat.emission_enabled = true
	_extra_mat.emission = arm_color
	_extra_mat.emission_energy_multiplier = 1.6
	_extra = MeshInstance3D.new()
	_extra.material_override = _extra_mat
	_extra.name = "FormExtra"
	_head.add_child(_extra) # rides the head so garnish follows the lunge
	_glow = OmniLight3D.new()
	_glow.light_color = arm_color
	_glow.light_energy = 0.6
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 0.2, -0.4)
	add_child(_glow)
	_rebuild_head()


func configure(p_element: StringName, p_color: Color) -> void:
	element = p_element
	arm_color = p_color
	if _mat:
		_mat.albedo_color = arm_color
		_mat.emission = arm_color
	if _core_mat:
		_core_mat.albedo_color = arm_color
		_core_mat.emission = arm_color
	if _extra_mat:
		_extra_mat.emission = arm_color
	if _glow:
		_glow.light_color = arm_color


func set_form(f: int) -> void:
	form = f
	_rebuild_head()


func _rebuild_head() -> void:
	if _head == null:
		return
	match form:
		Form.FIST:
			var m := SphereMesh.new()
			m.radius = 0.30
			m.height = 0.55
			_head.mesh = m
			_head.scale = Vector3.ONE
			_head.rotation = Vector3.ZERO
			# Knuckle trio: reads as a fist even mid-lunge.
			var k := BoxMesh.new()
			k.size = Vector3(0.5, 0.16, 0.2)
			_extra.mesh = k
			_extra.position = Vector3(0, 0.12, -0.18)
			_extra.rotation = Vector3.ZERO
			_extra.scale = Vector3.ONE
			_extra.visible = true
		Form.BLADE:
			var m := PrismMesh.new()
			m.size = Vector3(0.22, 0.9, 0.22)
			_head.mesh = m
			_head.rotation = Vector3(PI / 2.0, 0, 0)
			# Hot edge strip along the blade.
			var e := BoxMesh.new()
			e.size = Vector3(0.06, 0.9, 0.06)
			_extra.mesh = e
			_extra.position = Vector3(0, 0, -0.3)
			_extra.rotation = Vector3.ZERO
			_extra.scale = Vector3.ONE
			_extra.visible = true
		Form.SHIELD:
			var m := BoxMesh.new()
			m.size = Vector3(0.7, 0.9, 0.14)
			_head.mesh = m
			_head.rotation = Vector3.ZERO
			_head.scale = Vector3.ONE
			# Shield boss: bright rivet that sells the block.
			var b := SphereMesh.new()
			b.radius = 0.12
			b.height = 0.2
			_extra.mesh = b
			_extra.position = Vector3(0, 0, -0.14)
			_extra.rotation = Vector3.ZERO
			_extra.scale = Vector3.ONE
			_extra.visible = true


func set_charge(v: float) -> void:
	charge = clampf(v, 0.0, 1.0)


func play_attack() -> void:
	_lunge = 1.0


func play_windup() -> void:
	_lunge = -0.45 # arm coils back during windup, springs on active


func play_hit_react() -> void:
	_lunge = -0.6


func _process(delta: float) -> void:
	_t += delta
	# Idle: subtle hover bob + slow rotation sway (calmed by reduced motion).
	var gm := get_node_or_null("/root/GameManager")
	var calm: bool = gm != null and gm.reduced_motion()
	var amp := 0.03 if calm else 0.06
	position = _base_pos + Vector3(0, sin(_t * 2.2) * amp, 0)
	rotation.y = sin(_t * 1.3) * (0.05 if calm else 0.12)
	# Lunge spring back.
	if _lunge != 0.0:
		_lunge = move_toward(_lunge, 0.0, delta * 6.0)
		_head.position.z = -0.55 - _lunge * 0.5
	# Charge glow.
	if _mat:
		_mat.emission_energy_multiplier = 0.8 + charge * 2.2 + (0.15 * sin(_t * 5.0) if charge > 0.05 else 0.0)
	if _core_mat:
		_core_mat.emission_energy_multiplier = 1.2 + charge * 2.5 + 0.25 * sin(_t * 3.0)
	if _glow:
		_glow.light_energy = 0.6 + charge * 1.6
