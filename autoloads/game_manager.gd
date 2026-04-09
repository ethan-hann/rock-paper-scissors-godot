extends Node

enum State { MAIN_MENU, BATTLE, GAME_OVER }

var current_state: State = State.MAIN_MENU
var last_victory: bool = false

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over/game_over.tscn"

func go_to_main_menu() -> void:
	current_state = State.MAIN_MENU
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func start_new_run() -> void:
	RunState.reset_for_new_run()
	# Phase 1: single enemy. Phase 3 map will pass multi-enemy encounters.
	_go_to_battle([EnemyRegistry.get_random_enemy()])

func _go_to_battle(enemies: Array[EnemyData]) -> void:
	RunState.current_enemies = enemies
	RunState.reset_battle_state()
	current_state = State.BATTLE
	get_tree().change_scene_to_file(BATTLE_SCENE)

func battle_won() -> void:
	last_victory = true
	RunState.meta_currency_earned += 10 + RunState.floor_number * 5
	current_state = State.GAME_OVER
	get_tree().change_scene_to_file(GAME_OVER_SCENE)

func battle_lost() -> void:
	last_victory = false
	current_state = State.GAME_OVER
	get_tree().change_scene_to_file(GAME_OVER_SCENE)
