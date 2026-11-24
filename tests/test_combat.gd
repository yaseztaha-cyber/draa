extends SceneTree
## DRAA headless tests: combat math + data integrity.
## Run: godot --headless --path . -s tests/test_combat.gd
## Exit code 0 = all green, 1 = failure. No scene needed.

var _failures: int = 0


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS  " + name)
	else:
		_failures += 1
		printerr("FAIL  " + name)


func _init() -> void:
	# AbilityDB math (data-driven, no tree required).
	var light: AbilityData = AbilityDB.get_ability(&"light_punch")
	_check(light.damage == 8.0, "light punch damage = 8")
	var heavy: AbilityData = AbilityDB.get_ability(&"heavy_punch")
	_check(heavy.damage > light.damage, "heavy hits harder than light")
	var ult: AbilityData = AbilityDB.get_ability(&"fire_eruption")
	_check(ult.damage > heavy.damage, "ultimate out-damages basics")
	_check(AbilityDB.get_ability(&"fire_dash").cooldown == 5.0, "fire dash cooldown = 5s")
	_check(AbilityDB.get_ability(&"volt_dash").range > AbilityDB.get_ability(&"fire_dash").range,
		"lightning dash out-ranges fire dash")
	# Element matrix (§11).
	_check(is_equal_approx(ElementMatrix.multiplier(&"fire", &"ice"), 1.25), "fire melts ice x1.25")
	_check(ElementMatrix.multiplier(&"lightning", &"ice", &"wet") > 1.3, "lightning+wet discharges")
	_check(ElementMatrix.multiplier(&"fire", &"fire") == 1.0, "mirror matchup neutral")
	_check(ElementMatrix.team_combo(&"fire", &"wind") == "fire_tornado", "fire+wind combo id")
	_check(ElementMatrix.team_combo(&"ice", &"lightning") == "storm_prison", "ice+volt combo id")
	_check(ElementMatrix.team_combo(&"fire", &"shadow") == "shadow_flame", "fire+shadow combo id")
	_check(ElementMatrix.team_combo(&"fire", &"ice") == "", "fire+ice has no combo")
	# Health unit behavior.
	var h := CombatHealth.new()
	h.setup(100.0, 0.1)
	h.apply_damage(20.0, null)
	_check(is_equal_approx(h.current, 82.0), "defense reduces 20 -> 18")
	h.heal(5.0)
	_check(is_equal_approx(h.current, 87.0), "heal adds back")
	h.apply_damage(999.0, null)
	_check(h.dead and h.current == 0.0, "lethal damage depletes")
	h.apply_damage(10.0, null)
	_check(h.current == 0.0, "dead ignores further damage")
	# Fighter resources load with sane balance.
	var speeds := {}
	for fid in ["fire", "ice", "lightning", "shadow"]:
		var d: FighterData = load("res://data/fighters/" + fid + ".tres")
		_check(d != null, "fighter loads: " + fid)
		_check(d.max_hp >= 80.0 and d.move_speed >= 5.0, "fighter sane stats: " + fid)
		speeds[fid] = d.move_speed
	_check(float(speeds["lightning"]) > float(speeds["fire"]), "lightning fastest, fire slowest-ish")
	# Network sanity gate (never trust remote damage blindly).
	_check(DraaNetwork.validate_hit(Vector3.ZERO, Vector3(0, 0, -2), Vector3(0, 0, -1), 2.6, true),
		"plausible hit validates")
	_check(not DraaNetwork.validate_hit(Vector3.ZERO, Vector3(0, 0, -20), Vector3(0, 0, -1), 2.6, true),
		"cross-map hit rejected")
	_check(not DraaNetwork.validate_hit(Vector3.ZERO, Vector3(0, 0, -2), Vector3(0, 0, -1), 2.6, false),
		"cooldown-cheat hit rejected")
	# Phase-2 attack feel data: committed windups, punishable recoveries,
	# dash-strike lunges, dramatic ult windups, honest support cooldowns.
	# (light/heavy/ult already fetched above; reuse them here.)
	_check(is_equal_approx(light.windup, 0.08), "light windup is snappy")
	var heavy2: AbilityData = AbilityDB.get_ability(&"heavy_punch")
	_check(heavy2.recover > light.recover, "heavies risk longer recovery")
	_check(heavy2.windup > light.windup, "heavies telegraph longer")
	_check(AbilityDB.get_ability(&"fire_dash").lunge > 0.0, "fire dash lunges")
	_check(AbilityDB.get_ability(&"volt_dash").lunge > AbilityDB.get_ability(&"fire_dash").lunge,
		"volt dash lunges farthest")
	_check(AbilityDB.get_ability(&"ice_wall").lunge == 0.0, "ice wall holds ground")
	for uid in [&"fire_eruption", &"ice_prison", &"volt_storm", &"shadow_realm"]:
		_check(AbilityDB.get_ability(uid).windup >= 0.35, "ult windup is dramatic: " + String(uid))
	_check(AbilityDB.get_ability(&"shadow_clone").damage == 0.0, "clone is pure utility")
	# Phase-3 surface + status: rock grips, ice slides, slows stack sanely.
	var fresh := Fighter.new()
	_check(is_equal_approx(fresh.traction, 1.0), "default traction grips")
	_check(is_equal_approx(fresh.slow_mult, 1.0), "no slow at spawn")
	fresh.apply_slow(0.65, 1.5)
	_check(is_equal_approx(fresh.slow_mult, 0.65) and fresh.slow_t > 0.0, "slow applies")
	fresh.apply_slow(0.9, 5.0)
	_check(is_equal_approx(fresh.slow_mult, 0.65), "strongest slow wins")
	_check(is_equal_approx(fresh.slow_t, 5.0), "longest slow wins")
	fresh.free()
	# v0.4 visual builder: structure integrity without a tree (no rendering
	# needed to prove the hierarchy, names, and arm wiring are correct).
	var fdata := FighterData.new()
	var vis := FighterVisual.build(fdata)
	_check(vis is FighterVisual, "builder returns FighterVisual")
	_check(vis.arm != null and vis.eye_l != null and vis.eye_r != null, "arm + eyes wired")
	for part_name in ["EyeL", "EyeR", "Torso", "Headband"]:
		_check(vis.find_child(part_name, true, false) != null, "visual part: " + part_name)
	_check(vis.get_child_count() >= 12, "visual has full body")
	vis.arm.set_form(MagicArm.Form.BLADE)
	_check(vis.arm.form == MagicArm.Form.BLADE, "arm morphs forms")
	vis.free()
	print("---")
	if _failures == 0:
		print("ALL COMBAT TESTS PASSED")
	else:
		printerr(str(_failures) + " FAILURES")
	quit(_failures)
