class_name AbilityDB
extends RefCounted
## Loads data/abilities/abilities.json into AbilityData resources.
## Single source of truth for all combat numbers.

static var _cache: Dictionary = {}


static func get_ability(ability_id: StringName) -> AbilityData:
	var id := String(ability_id)
	if _cache.has(id):
		return _cache[id]
	var a := AbilityData.new()
	a.ability_id = ability_id
	var path := "res://data/abilities/abilities.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has(id):
				var d: Dictionary = (parsed as Dictionary)[id]
				a.element = StringName(str(d.get("element", "none")))
				a.damage = float(d.get("damage", 8.0))
				a.cooldown = float(d.get("cooldown", 1.0))
				a.range = float(d.get("range", 2.6))
				a.radius = float(d.get("radius", 1.4))
				a.knockback = float(d.get("knockback", 5.0))
				a.stun_time = float(d.get("stun_time", 0.2))
				a.ult_charge_gain = float(d.get("ult_charge_gain", 8.0))
				a.windup = float(d.get("windup", 0.12))
				a.recover = float(d.get("recover", 0.3))
				a.lunge = float(d.get("lunge", 0.0))
				_cache[id] = a
				return a
	push_warning("AbilityDB: unknown ability " + id + ", using punch fallback.")
	_cache[id] = a
	return a


static func clear_cache() -> void:
	_cache.clear()
