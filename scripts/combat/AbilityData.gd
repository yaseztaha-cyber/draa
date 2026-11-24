class_name AbilityData
extends Resource
## Data-driven ability definition. All numbers tunable without touching code.

@export var ability_id: StringName = &"fire_dash"
@export var element: StringName = &"fire"
@export var damage: float = 12.0
@export var cooldown: float = 6.0
@export var range: float = 4.0
@export var radius: float = 2.2
@export var knockback: float = 8.0
@export var stun_time: float = 0.35
@export var ult_charge_gain: float = 20.0
## Phase-2 feel timings: windup (commit, arm pulls back, can lunge),
## active hit lands at windup end, recover (vulnerable, dash-cancellable).
@export var windup: float = 0.12
@export var recover: float = 0.3
## Forward lunge distance covered during windup (dash-strikes). 0 = in place.
@export var lunge: float = 0.0
