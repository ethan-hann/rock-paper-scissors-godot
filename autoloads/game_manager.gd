extends Node

enum State { MAIN_MENU, SAVE_SLOT, BATTLE, SKILL_SELECT, GAME_OVER }

var current_state: State = State.MAIN_MENU
var last_victory: bool = false

## Phase 2: a run is 3 battles. Phase 3 will replace this with map floors.
const BATTLES_PER_RUN := 3

const MAIN_MENU_SCENE    := "res://scenes/main_menu/main_menu.tscn"
const SAVE_SLOT_SCENE    := "res://scenes/save_slot/save_slot_screen.tscn"
const BATTLE_SCENE       := "res://scenes/battle/battle_scene.tscn"
const SKILL_SELECT_SCENE := "res://scenes/skill_selection/skill_selection.tscn"
const GAME_OVER_SCENE    := "res://scenes/game_over/game_over.tscn"

# ─── Scene transitions ────────────────────────────────────────────────────────

func go_to_main_menu() -> void:
	current_state = State.MAIN_MENU
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func go_to_save_slot() -> void:
	current_state = State.SAVE_SLOT
	get_tree().change_scene_to_file(SAVE_SLOT_SCENE)

# ─── Run lifecycle ────────────────────────────────────────────────────────────

## Start a brand-new run on the already-loaded active slot.
func start_new_run() -> void:
	RunState.reset_for_new_run()
	RunState.apply_legendary_run_effects()   # injects legendaries + applies stat changes
	_go_to_battle([EnemyRegistry.get_enemy_for_floor(RunState.floor_number)])

## Restore a previously saved mid-run state and jump back into battle.
func continue_run() -> void:
	# Run state (HP, floor, skills) was already loaded by MetaProgression.load_run_state()
	# before this is called. Delete the save now — it lives in memory from here on.
	MetaProgression.delete_run_save(MetaProgression.active_slot)
	_go_to_battle([EnemyRegistry.get_enemy_for_floor(RunState.floor_number)])

func _go_to_battle(enemies: Array[EnemyData]) -> void:
	# Duplicate each enemy so modifiers don't persist on the shared registry object.
	var battle_enemies: Array[EnemyData] = []
	for e in enemies:
		var copy := e.duplicate() as EnemyData
		copy.modifiers = ModifierRoller.roll(RunState.floor_number)
		battle_enemies.append(copy)
	RunState.current_enemies = battle_enemies
	RunState.reset_battle_state()
	current_state = State.BATTLE
	get_tree().change_scene_to_file(BATTLE_SCENE)

func battle_won() -> void:
	last_victory = true
	RunState.floor_number += 1
	RunState.meta_currency_earned += 10 + (RunState.floor_number - 1) * 5

	if RunState.floor_number >= BATTLES_PER_RUN:
		# Run complete — record result, delete run save, go to game over.
		MetaProgression.record_run(RunState.floor_number, true, RunState.meta_currency_earned)
		MetaProgression.delete_run_save(MetaProgression.active_slot)
		current_state = State.GAME_OVER
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
	else:
		# More battles remain — offer a skill first.
		current_state = State.SKILL_SELECT
		get_tree().change_scene_to_file(SKILL_SELECT_SCENE)

func after_skill_select() -> void:
	_go_to_battle([EnemyRegistry.get_enemy_for_floor(RunState.floor_number)])

func battle_lost() -> void:
	last_victory = false
	# Record the failed run, then delete the run save so the player cannot
	# reload and retry. The meta progression (unlocked skills etc.) is kept.
	MetaProgression.record_run(RunState.floor_number, false, RunState.meta_currency_earned)
	MetaProgression.delete_run_save(MetaProgression.active_slot)
	current_state = State.GAME_OVER
	get_tree().change_scene_to_file(GAME_OVER_SCENE)
