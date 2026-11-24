class_name BreakableBarrel
extends Node3D
## Explosive arena prop (§14): 20 HP, detonates for AoE damage with
## respawn handled by the arena. Takes hits through the same melee
## scan as fighters (group "breakables"), so punching barrels is real.

signal exploded(barrel: BreakableBarrel, from: Vector3)

var hp: float = 20.0
var alive: bool = true
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("breakables")
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.25, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.25, 0.1)
	mat.emission_energy_multiplier = 0.4
	_mesh.material_override = mat
	add_child(_mesh)
	# Warning stripe: shape-coded danger (not color-only) — white band.
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.5
	bm.outer_radius = 0.62
	band.mesh = bm
	band.rotation.x = PI / 2.0
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(1, 0.95, 0.85)
	band.material_override = wmat
	add_child(band)


func take_hit(amount: float, from: Vector3, _element: StringName = &"fire") -> void:
	if not alive:
		return
	hp -= amount
	# Punch feedback: brief squash.
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.25, 0.75, 1.25), 0.07)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.12)
	if hp <= 0.0:
		alive = false
		exploded.emit(self, from)
