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
