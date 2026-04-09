extends Node

enum State { MAIN_MENU, BATTLE, SKILL_SELECT, GAME_OVER }

var current_state: State = State.MAIN_MENU
var last_victory: bool = false

## Phase 2: a run is 3 battles. Phase 3 will replace this with map floors.
const BATTLES_PER_RUN := 3

const MAIN_MENU_SCENE    := "res://scenes/main_menu/main_menu.tscn"
const BATTLE_SCENE       := "res://scenes/battle/battle_scene.tscn"
const SKILL_SELECT_SCENE := "res://scenes/skill_selection/skill_selection.tscn"
const GAME_OVER_SCENE    := "res://scenes/game_over/game_over.tscn"

func go_to_main_menu() -> void:
	current_state = State.MAIN_MENU
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func start_new_run() -> void:
	RunState.reset_for_new_run()
	_go_to_battle([EnemyRegistry.get_random_enemy()])

func _go_to_battle(enemies: Array[EnemyData]) -> void:
	RunState.current_enemies = enemies
	RunState.reset_battle_state()
	current_state = State.BATTLE
	get_tree().change_scene_to_file(BATTLE_SCENE)

func battle_won() -> void:
	last_victory = true
	RunState.floor_number += 1
	RunState.meta_currency_earned += 10 + (RunState.floor_number - 1) * 5

	if RunState.floor_number >= BATTLES_PER_RUN:
		# Run complete — record and go to game over
		MetaProgression.record_run(RunState.floor_number, true, RunState.meta_currency_earned)
		current_state = State.GAME_OVER
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
	else:
		# More battles remain — offer a skill first
		current_state = State.SKILL_SELECT
		get_tree().change_scene_to_file(SKILL_SELECT_SCENE)

func after_skill_select() -> void:
	_go_to_battle([EnemyRegistry.get_random_enemy()])

func battle_lost() -> void:
	last_victory = false
	MetaProgression.record_run(RunState.floor_number, false, RunState.meta_currency_earned)
	current_state = State.GAME_OVER
	get_tree().change_scene_to_file(GAME_OVER_SCENE)
