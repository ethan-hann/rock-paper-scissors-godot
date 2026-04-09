extends Node

const SAVE_PATH := "user://meta_save.json"

var meta_currency_total: int = 0
var meta_currency_spent: int = 0
var unlocked_skill_ids: Array[String] = []
var permanent_upgrades: Dictionary = {
	"starting_hp_bonus": 0,
	"bonus_damage_flat": 0,
	"starting_gold_bonus": 0
}
var run_history: Array = []
var total_runs: int = 0

func _ready() -> void:
	load_data()
	if unlocked_skill_ids.is_empty():
		_unlock_all_for_testing()

## Phase 2: all skills unlocked for testing.
## Phase 4 will gate these behind meta-currency purchases.
func _unlock_all_for_testing() -> void:
	unlocked_skill_ids = [
		"iron_fist", "scissor_strike", "stone_skin",
		"paper_shield", "momentum", "counterflow",
		"fortune_turn", "blade_dance"
	]
	save_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Dictionary = json.get_data()
	meta_currency_total = data.get("meta_currency_total", 0)
	meta_currency_spent = data.get("meta_currency_spent", 0)
	unlocked_skill_ids.clear()
	for sid in data.get("unlocked_skill_ids", []):
		unlocked_skill_ids.append(sid)
	permanent_upgrades = data.get("permanent_upgrades", permanent_upgrades)
	run_history = data.get("run_history", [])
	total_runs = data.get("total_runs", 0)

func save_data() -> void:
	var data := {
		"meta_currency_total": meta_currency_total,
		"meta_currency_spent": meta_currency_spent,
		"unlocked_skill_ids": Array(unlocked_skill_ids),
		"permanent_upgrades": permanent_upgrades,
		"run_history": run_history,
		"total_runs": total_runs
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("MetaProgression: Cannot write save file.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func record_run(floors_cleared: int, victory: bool, currency_earned: int) -> void:
	total_runs += 1
	meta_currency_total += currency_earned
	run_history.append({
		"floors_cleared": floors_cleared,
		"victory": victory,
		"currency_earned": currency_earned
	})
	save_data()

func unlock_skill(id: String) -> void:
	if id not in unlocked_skill_ids:
		unlocked_skill_ids.append(id)
		save_data()
