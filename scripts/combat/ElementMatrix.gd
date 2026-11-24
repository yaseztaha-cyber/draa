class_name ElementMatrix
extends RefCounted
## Elemental interactions (§11). Returns damage multiplier for
## attacker element vs defender element / ground state.

static func multiplier(attacker: StringName, defender: StringName, defender_state: StringName = &"") -> float:
	if attacker == defender:
		return 1.0
	# Lightning + water: area discharge. Checked before the matchup table
	# so the wet condition overrides (design: discharge beats base rates).
	if attacker == &"lightning" and defender_state == &"wet":
		return 1.35
	match [String(attacker), String(defender)]:
		["fire", "ice"]:
			return 1.25 # Fire melts ice.
		["ice", "fire"]:
			return 0.85 # Ice struggles into fire.
		["lightning", "ice"]:
			return 1.15
		["wind", "fire"]:
			return 1.2 # Wind spreads fire (also enlarges radius; see Arena).
		["shadow", "light"]:
			return 0.7 # Shadow exposed by light.
		["light", "shadow"]:
			return 1.3
		_:
			pass
	return 1.0


## Team combo table (§12). Both partners must be alive, within 6m, and
## cast within 1.2s of each other. Returns combo id or "".
## Display names (Arabic/English) live in data/abilities/team_combos.json.
static func team_combo(a: StringName, b: StringName) -> String:
	var pair: Array[String] = [String(a), String(b)]
	pair.sort()
	match pair:
		["fire", "wind"]:
			return "fire_tornado"
		["ice", "lightning"]:
			return "storm_prison"
		["fire", "shadow"]:
			return "shadow_flame"
	return ""
