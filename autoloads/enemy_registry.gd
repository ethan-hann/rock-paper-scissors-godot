extends Node

var _enemies: Dictionary = {}

func _ready() -> void:
	_register_enemies()

func _register_enemies() -> void:
	var goblin := EnemyData.new()
	goblin.id = "goblin"
	goblin.display_name = "Goblin Gambler"
	goblin.description = "A scrappy goblin who plays completely at random."
	goblin.max_hp = 20
	goblin.base_damage = 4
	goblin.rounds_to_win = 2
	goblin.ai_type = 0  # Random
	goblin.gold_reward = 10
	goblin.skill_reward_count = 3
	_enemies[goblin.id] = goblin

	var knight := EnemyData.new()
	knight.id = "iron_knight"
	knight.display_name = "Iron Knight"
	knight.description = "A heavily armored knight with a deep love for Rock."
	knight.max_hp = 30
	knight.base_damage = 6
	knight.rounds_to_win = 2
	knight.ai_type = 1  # Weighted
	knight.ai_weights = {"rock": 0.82, "paper": 0.06, "scissors": 0.12}
	knight.gold_reward = 20
	knight.skill_reward_count = 3
	_enemies[knight.id] = knight

	var trickster := EnemyData.new()
	trickster.id = "shadow_trickster"
	trickster.display_name = "Shadow Trickster"
	trickster.description = "A cunning rogue who mirrors your moves — or turns them against you. You can never be sure which."
	trickster.max_hp = 25
	trickster.base_damage = 5
	trickster.rounds_to_win = 2
	trickster.ai_type = 5  # Schemer
	trickster.gold_reward = 15
	trickster.skill_reward_count = 3
	_enemies[trickster.id] = trickster

func get_enemy(id: String) -> EnemyData:
	return _enemies.get(id, null)

func get_random_enemy() -> EnemyData:
	var keys := _enemies.keys()
	return _enemies[keys[randi() % keys.size()]]
