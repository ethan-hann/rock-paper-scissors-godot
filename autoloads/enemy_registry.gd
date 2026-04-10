extends Node

var _enemies: Dictionary = {}

func _ready() -> void:
	_register_enemies()

func _register_enemies() -> void:
	# ── Floor 0 — tutorial fight. Low HP, low damage, pure random AI. ────────────
	var goblin := EnemyData.new()
	goblin.id = "goblin"
	goblin.display_name = "Goblin Gambler"
	goblin.description = "A scrappy goblin who plays completely at random. Don't underestimate chaos!"
	goblin.max_hp = 16
	goblin.base_damage = 3
	goblin.ai_type = 0  # Random
	goblin.gold_reward = 10
	goblin.skill_reward_count = 3
	goblin.floor_min = 0
	goblin.floor_max = 0   # Only appears on the first battle
	_enemies[goblin.id] = goblin

	# ── Floor 1 — introduces a readable pattern: heavy Rock bias. ────────────────
	var knight := EnemyData.new()
	knight.id = "iron_knight"
	knight.display_name = "Iron Knight"
	knight.description = "A heavily armored knight with a near-obsessive love for Rock."
	knight.max_hp = 28
	knight.base_damage = 6
	knight.ai_type = 1  # Weighted
	knight.ai_weights = {"rock": 0.78, "paper": 0.10, "scissors": 0.12}
	knight.gold_reward = 20
	knight.skill_reward_count = 3
	knight.floor_min = 1
	knight.floor_max = 99
	_enemies[knight.id] = knight

	# ── Floor 2 — reactive AI; keeps the player on their toes. ──────────────────
	var trickster := EnemyData.new()
	trickster.id = "shadow_trickster"
	trickster.display_name = "Shadow Trickster"
	trickster.description = "A cunning rogue who mirrors your moves — or turns them against you. You can never be sure which."
	trickster.max_hp = 30
	trickster.base_damage = 5
	trickster.ai_type = 5  # Schemer
	trickster.gold_reward = 25
	trickster.skill_reward_count = 3
	trickster.floor_min = 2
	trickster.floor_max = 99
	_enemies[trickster.id] = trickster

func get_enemy(id: String) -> EnemyData:
	return _enemies.get(id, null)

## Returns a random enemy eligible for the given floor number.
## Falls back to a fully random pick if no eligible enemy is found (safety net).
func get_enemy_for_floor(floor_number: int) -> EnemyData:
	var eligible: Array = []
	for enemy in _enemies.values():
		if floor_number >= enemy.floor_min and floor_number <= enemy.floor_max:
			eligible.append(enemy)
	if eligible.is_empty():
		push_warning("EnemyRegistry: no eligible enemy for floor %d — picking randomly." % floor_number)
		var keys := _enemies.keys()
		return _enemies[keys[randi() % keys.size()]]
	return eligible[randi() % eligible.size()]

## Legacy helper — kept for any callers that don't yet pass a floor.
func get_random_enemy() -> EnemyData:
	var keys := _enemies.keys()
	return _enemies[keys[randi() % keys.size()]]
