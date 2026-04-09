class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var max_hp: int = 30
@export var base_damage: int = 5
@export var rounds_to_win: int = 2
## 0=Random  1=Weighted  2=Pattern  3=Adaptive  4=Mirror  5=Schemer
@export var ai_type: int = 0
@export var ai_weights: Dictionary = {}
@export var ai_pattern: Array[int] = []
@export var gold_reward: int = 10
@export var skill_reward_count: int = 3
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var floor_min: int = 0
@export var floor_max: int = 14
## Modifiers rolled at battle start — populated by ModifierRoller, not set in registry.
var modifiers: Array = []
