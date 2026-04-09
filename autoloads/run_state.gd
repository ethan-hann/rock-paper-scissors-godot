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

func reset_for_new_run() -> void:
	current_hp = 30
	max_hp = 30
	player_base_damage = 8
	gold = 0
	floor_number = 0
	meta_currency_earned = 0
	current_enemies = []
	active_skills = []
	reset_battle_state()

func reset_battle_state() -> void:
	player_move_history = []
