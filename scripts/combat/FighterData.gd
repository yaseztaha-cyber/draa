class_name FighterData
extends Resource
## Data-driven fighter definition (§40). Balance lives here, not in code.

@export var fighter_id: StringName = &"fire"
@export var name_key: String = "fighter_fire"
@export var title_key: String = "fighter_fire_title"
@export var desc_key: String = "fighter_fire_desc"
@export var element: StringName = &"fire"
@export var max_hp: float = 100.0
@export var move_speed: float = 6.0
@export var damage_mult: float = 1.0
@export var defense: float = 0.0
@export var ability1_id: StringName = &"fire_dash"
@export var ability2_id: StringName = &"fire_blast"
@export var ultimate_id: StringName = &"fire_eruption"
@export var arm_color: Color = Color(1.0, 0.38, 0.08)
@export var difficulty_note: String = ""
