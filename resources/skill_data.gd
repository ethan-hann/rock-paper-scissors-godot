class_name SkillData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## 0 = Common  1 = Uncommon  2 = Rare
@export var rarity: int = 0
@export var is_active: bool = false
@export var effect_key: String = ""
@export var parameters: Dictionary = {}
@export var locked_by_default: bool = false
## If true, the same skill may appear in offers more than once (damage/reduction skills).
## If false, the skill is excluded from offers once the player owns it.
@export var stackable: bool = true
## Maximum number of times this skill can be stacked. Ignored when stackable = false.
@export var max_stacks: int = 1
