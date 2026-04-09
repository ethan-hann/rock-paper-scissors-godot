extends Node

# Player stats
var current_hp: int = 30
var max_hp: int = 30
var player_base_damage: int = 8
var gold: int = 0
var floor_number: int = 0
var meta_currency_earned: int = 0

# Battle state
var current_enemies: Array[EnemyData] = []
var player_move_history: Array[int] = []

# Skills (Phase 2)
var active_skills: Array = []

## Set to true the first time Undying Will saves the player; prevents a second save this run.
var undying_will_used: bool = false

func reset_for_new_run() -> void:
	current_hp = 30
	max_hp = 30
	player_base_damage = 8
	gold = 0
	floor_number = 0
	meta_currency_earned = 0
	current_enemies = []
	active_skills = []
	undying_will_used = false
	reset_battle_state()

func reset_battle_state() -> void:
	player_move_history = []

func has_skill(id: String) -> bool:
	for skill in active_skills:
		if skill.id == id:
			return true
	return false

## Returns how many copies of this skill the player currently holds.
func skill_stack_count(id: String) -> int:
	var n := 0
	for skill in active_skills:
		if skill.id == id:
			n += 1
	return n

## Inject all legendary skills from MetaProgression and apply their run-start stat effects.
## Call this at the start of every new run, after reset_for_new_run().
func apply_legendary_run_effects() -> void:
	for id in MetaProgression.legendary_skill_ids:
		var skill := SkillRegistry.get_skill(id)
		if skill:
			active_skills.append(skill)
			_apply_legendary_stat_effect(skill)

## Apply the run-start stat change for a single legendary skill.
## Called both by apply_legendary_run_effects() and when a legendary is picked mid-run.
func apply_single_legendary_effect(skill: SkillData) -> void:
	_apply_legendary_stat_effect(skill)

func _apply_legendary_stat_effect(skill: SkillData) -> void:
	match skill.effect_key:
		"blood_pact":
			var penalty: int = skill.parameters.get("hp_penalty", 5)
			var bonus: int   = skill.parameters.get("bonus_damage", 8)
			max_hp             = maxi(1, max_hp - penalty)
			current_hp         = mini(current_hp, max_hp)
			player_base_damage += bonus
