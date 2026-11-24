class_name FighterVisual
extends Node3D
## Shared cartoon-fighter builder (game + menu preview stay identical).
## Chibi proportions, expressive face (eyes/brows/headband), normal left arm,
## legs + boots, team-dark cloth with element accents, big MagicArm right.
## Collision stays the engine capsule — visuals may overhang slightly.
## Node names (EyeL/EyeR/ArmCore/...) are asserted by tests; keep them.

var arm: MagicArm
var eye_l: MeshInstance3D
var eye_r: MeshInstance3D


static func skin_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.98, 0.8, 0.62)
	m.roughness = 0.6
	return m


static func cloth_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.13, 0.22)
	m.roughness = 0.9
	return m


static func metal_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.22, 0.3)
	m.metallic = 0.7
	m.roughness = 0.4
	return m


static func glow_mat(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


static func part(mesh: Mesh, mat: Material, pos: Vector3, pname: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not pname.is_empty():
		mi.name = pname
	return mi


static func ball(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = 16
	s.rings = 8
	return s


static func limb(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	return c


static func build(data: FighterData) -> FighterVisual:
	var v := FighterVisual.new()
	var skin := skin_mat()
	var cloth := cloth_mat()
	var metal := metal_mat()
	var accent := glow_mat(data.arm_color, 0.8)
	# Torso: cloth capsule + glowing belly band (element readable at a glance).
	var torso := limb(0.34, 1.0)
	v.add_child(part(torso, cloth, Vector3(0, 1.15, 0), "Torso"))
	var bandm := CylinderMesh.new()
	bandm.top_radius = 0.35
	bandm.bottom_radius = 0.35
	bandm.height = 0.12
	v.add_child(part(bandm, accent, Vector3(0, 1.0, 0), "Band"))
	# Legs + boots.
	for sx in [-1.0, 1.0]:
		var leg := limb(0.13, 0.55)
		v.add_child(part(leg, cloth, Vector3(0.18 * sx, 0.55, 0)))
		var foot := BoxMesh.new()
		foot.size = Vector3(0.22, 0.14, 0.34)
		v.add_child(part(foot, metal, Vector3(0.18 * sx, 0.07, -0.04)))
	# Normal left arm: small capsule + fist.
	var upper := limb(0.11, 0.5)
	var ua := part(upper, skin, Vector3(-0.5, 1.3, 0))
	ua.rotation.z = 0.12
	v.add_child(ua)
	v.add_child(part(ball(0.14, 0.28), skin, Vector3(-0.54, 0.98, 0), "FistL"))
	# Shoulder pads: dark metal, chunky silhouette.
	for sx in [-1.0, 1.0]:
		var pad := part(ball(0.2, 0.24), metal, Vector3(0.44 * sx, 1.62, 0))
		pad.scale = Vector3(1.0, 0.6, 1.0)
		v.add_child(pad)
	# Head: skin sphere + eyes/pupils/brows + element headband.
	v.add_child(part(ball(0.3, 0.58), skin, Vector3(0, 1.98, 0), "Head"))
	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	white.roughness = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.1)
	var eye_geo := ball(0.09, 0.18)
	var pup_geo := ball(0.045, 0.09)
	v.eye_l = part(eye_geo, white, Vector3(-0.11, 2.02, -0.22), "EyeL")
	v.eye_r = part(eye_geo, white, Vector3(0.11, 2.02, -0.22), "EyeR")
	v.add_child(v.eye_l)
	v.add_child(v.eye_r)
	v.add_child(part(pup_geo, dark, Vector3(-0.11, 2.02, -0.29)))
	v.add_child(part(pup_geo, dark, Vector3(0.11, 2.02, -0.29)))
	for sx in [-1.0, 1.0]:
		var browm := BoxMesh.new()
		browm.size = Vector3(0.14, 0.04, 0.05)
		var brow := part(browm, dark, Vector3(0.12 * sx, 2.16, -0.24))
		brow.rotation.z = -0.3 * sx
		v.add_child(brow)
	var band := TorusMesh.new()
	band.inner_radius = 0.26
	band.outer_radius = 0.33
	var band_mi := part(band, glow_mat(data.arm_color, 0.6), Vector3(0, 2.1, 0), "Headband")
	band_mi.rotation.x = PI / 2.0 + 0.15
	v.add_child(band_mi)
	# THE arm: big, right side, element-charged (detail in MagicArm).
	v.arm = MagicArm.new()
	v.arm.position = Vector3(0.55, 1.25, -0.1)
	v.arm.configure(data.element, data.arm_color)
	v.add_child(v.arm)
	return v
