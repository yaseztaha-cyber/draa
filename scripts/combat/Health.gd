class_name CombatHealth
extends Node
## HP container with defense + signals. Owner (Fighter/MatchManager)
## decides death/round consequences.

signal changed(current: float, maximum: float)
signal damaged(amount: float, attacker: Node)
signal healed(amount: float)
signal depleted(attacker: Node)

@export var maximum: float = 100.0
var current: float = 100.0
var defense: float = 0.0
var dead: bool = false


func setup(max_hp: float, def: float = 0.0) -> void:
	maximum = max_hp
	defense = clampf(def, 0.0, 0.75)
	current = maximum
	dead = false
	changed.emit(current, maximum)


func reset_full() -> void:
	current = maximum
	dead = false
	changed.emit(current, maximum)


func apply_damage(raw: float, attacker: Node = null) -> float:
	if dead:
		return 0.0
	var final := raw * (1.0 - defense)
	final = maxf(1.0, final)
	current = maxf(0.0, current - final)
	changed.emit(current, maximum)
	damaged.emit(final, attacker)
	if current <= 0.0:
		dead = true
		depleted.emit(attacker)
	return final


func heal(amount: float) -> void:
	if dead:
		return
	current = minf(maximum, current + amount)
	changed.emit(current, maximum)
	healed.emit(amount)


func fraction() -> float:
	return current / maxf(1.0, maximum)
