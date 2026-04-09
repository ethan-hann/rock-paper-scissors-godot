extends Node

var _all_skills: Dictionary = {}  # id -> SkillData

func _ready() -> void:
	_load_from_json()

func _load_from_json() -> void:
	var file := FileAccess.open("res://data/skills_db.json", FileAccess.READ)
	if not file:
		push_error("SkillRegistry: Cannot open skills_db.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SkillRegistry: JSON parse error — " + json.get_error_message())
		file.close()
		return
	file.close()
	for entry in json.get_data():
		var skill := SkillData.new()
		skill.id              = entry.get("id", "")
		skill.display_name    = entry.get("display_name", "")
		skill.description     = entry.get("description", "")
		skill.rarity          = entry.get("rarity", 0)
		skill.is_active       = entry.get("is_active", false)
		skill.effect_key      = entry.get("effect_key", "")
		skill.parameters      = entry.get("parameters", {})
		skill.locked_by_default = entry.get("locked_by_default", false)
		skill.stackable         = entry.get("stackable", true)
		skill.max_stacks        = entry.get("max_stacks", 1)
		_all_skills[skill.id] = skill

func get_skill(id: String) -> SkillData:
	return _all_skills.get(id, null)

func get_all_skills() -> Array:
	return _all_skills.values()

## Returns only the skills the player has unlocked (used for offering in skill_selection).
func get_unlocked_skills() -> Array:
	var result: Array = []
	for sid in MetaProgression.unlocked_skill_ids:
		var s := get_skill(sid)
		if s:
			result.append(s)
	return result
