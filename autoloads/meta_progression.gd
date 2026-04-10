extends Node

## Encryption password for save files.
## Stored in the compiled binary — deters casual file editing.
const SAVE_PASS := "f4t3sH4nd_sv_k3y_2025"
const SLOT_COUNT := 3
const SCHEMA_VERSION := 1

## Which slot is currently active. -1 = none loaded yet.
var active_slot: int = -1

# ── Per-slot runtime data ─────────────────────────────────────────────────────
var meta_currency_total: int = 0
var meta_currency_spent: int = 0
var unlocked_skill_ids: Array[String] = []
var permanent_upgrades: Dictionary = {
	"starting_hp_bonus": 0,
	"bonus_damage_flat": 0,
	"starting_gold_bonus": 0,
}
var run_history: Array = []
var total_runs: int = 0

## Skills that permanently carry over every run on this slot (rarity 3).
var legendary_skill_ids: Array[String] = []

## Bump this whenever the skill pool expands so older saves get re-unlocked.
const TESTING_SKILL_COUNT := 24

func _ready() -> void:
	pass  # No auto-load — slot selection happens on the save-slot screen.

# ─── Slot paths ───────────────────────────────────────────────────────────────

func _slot_path(slot: int) -> String:
	return "user://slot_%d.sav" % slot

# ─── Slot summaries (for the picker UI) ──────────────────────────────────────

## Returns lightweight display info for one slot without changing active state.
func get_slot_summary(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return { "exists": false }
	var data := _read_encrypted(path)
	if data.is_empty():
		return { "exists": false }
	var best_floor := 0
	var victories  := 0
	for run in data.get("run_history", []):
		best_floor = maxi(best_floor, run.get("floors_cleared", 0))
		if run.get("victory", false):
			victories += 1
	return {
		"exists":     true,
		"total_runs": data.get("total_runs", 0),
		"best_floor": best_floor,
		"victories":  victories,
	}

# ─── Load / Save / Delete ────────────────────────────────────────────────────

## Load a slot into the active state. Must be called before starting a run.
func load_slot(slot: int) -> void:
	active_slot = slot
	var path    := _slot_path(slot)
	if not FileAccess.file_exists(path):
		_reset_to_defaults()
		_unlock_all_for_testing()   # also calls save_data()
		return
	var data := _read_encrypted(path)
	if data.is_empty():
		_reset_to_defaults()
		_unlock_all_for_testing()
		return
	meta_currency_total = data.get("meta_currency_total", 0)
	meta_currency_spent = data.get("meta_currency_spent", 0)
	unlocked_skill_ids.clear()
	for sid in data.get("unlocked_skill_ids", []):
		unlocked_skill_ids.append(sid as String)
	permanent_upgrades = data.get("permanent_upgrades", _default_upgrades())
	run_history        = data.get("run_history",        [])
	total_runs         = data.get("total_runs",          0)
	legendary_skill_ids.clear()
	for sid in data.get("legendary_skill_ids", []):
		legendary_skill_ids.append(sid as String)
	# Re-unlock if the skill pool has grown since this save was written.
	if unlocked_skill_ids.size() < TESTING_SKILL_COUNT:
		_unlock_all_for_testing()

func save_data() -> void:
	if active_slot < 0:
		push_warning("MetaProgression: save_data() called with no active slot — skipped.")
		return
	_write_encrypted(_slot_path(active_slot), {
		"schema_version":      SCHEMA_VERSION,
		"meta_currency_total": meta_currency_total,
		"meta_currency_spent": meta_currency_spent,
		"unlocked_skill_ids":  Array(unlocked_skill_ids),
		"permanent_upgrades":  permanent_upgrades,
		"run_history":         run_history,
		"total_runs":          total_runs,
		"legendary_skill_ids": Array(legendary_skill_ids),
	})

func delete_slot(slot: int) -> void:
	delete_run_save(slot)   # also wipe any in-progress run for this slot
	if FileAccess.file_exists(_slot_path(slot)):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("slot_%d.sav" % slot)
	if active_slot == slot:
		active_slot = -1
		_reset_to_defaults()

# ─── Mid-run save (separate file per slot) ───────────────────────────────────

func _run_path(slot: int) -> String:
	return "user://run_slot_%d.sav" % slot

## True if this slot has a run that was saved mid-progress.
func has_saved_run(slot: int) -> bool:
	return FileAccess.file_exists(_run_path(slot))

## Lightweight summary of a saved run for the slot picker UI.
func get_run_summary(slot: int) -> Dictionary:
	var path := _run_path(slot)
	if not FileAccess.file_exists(path):
		return { "exists": false }
	var data := _read_encrypted(path)
	if data.is_empty():
		return { "exists": false }
	return {
		"exists":       true,
		"floor_number": data.get("floor_number", 0),
		"current_hp":   data.get("current_hp",   0),
		"max_hp":       data.get("max_hp",        30),
	}

## Save the current RunState to a run file so it can be continued later.
func save_run_state() -> void:
	if active_slot < 0:
		push_warning("MetaProgression: save_run_state() called with no active slot — skipped.")
		return
	var skill_ids: Array = []
	for skill in RunState.active_skills:
		skill_ids.append(skill.id)
	_write_encrypted(_run_path(active_slot), {
		"floor_number":      RunState.floor_number,
		"current_hp":        RunState.current_hp,
		"max_hp":            RunState.max_hp,
		"gold":              RunState.gold,
		"player_base_damage": RunState.player_base_damage,
		"active_skill_ids":  skill_ids,
	})

## Restore RunState from a saved run file. Returns false if no save exists.
func load_run_state() -> bool:
	if active_slot < 0:
		return false
	var path := _run_path(active_slot)
	if not FileAccess.file_exists(path):
		return false
	var data := _read_encrypted(path)
	if data.is_empty():
		return false
	RunState.floor_number        = data.get("floor_number",       0)
	RunState.current_hp          = data.get("current_hp",         30)
	RunState.max_hp              = data.get("max_hp",             30)
	RunState.gold                = data.get("gold",                0)
	RunState.player_base_damage  = data.get("player_base_damage",  8)
	RunState.active_skills.clear()
	for sid in data.get("active_skill_ids", []):
		var skill := SkillRegistry.get_skill(sid as String)
		if skill:
			RunState.active_skills.append(skill)
	return true

## Delete the run save for this slot (call on death or run completion).
func delete_run_save(slot: int) -> void:
	if FileAccess.file_exists(_run_path(slot)):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("run_slot_%d.sav" % slot)

# ─── Encrypted I/O ───────────────────────────────────────────────────────────

func _write_encrypted(path: String, data: Dictionary) -> void:
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, SAVE_PASS)
	if not file:
		push_error("MetaProgression: Cannot write '%s' (err %d)." % [
			path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()

func _read_encrypted(path: String) -> Dictionary:
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, SAVE_PASS)
	if not file:
		push_error("MetaProgression: Cannot read '%s' (err %d)." % [
			path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("MetaProgression: JSON parse error in '%s': %s" % [
			path, json.get_error_message()])
		return {}
	var result = json.get_data()
	return result if result is Dictionary else {}

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _default_upgrades() -> Dictionary:
	return { "starting_hp_bonus": 0, "bonus_damage_flat": 0, "starting_gold_bonus": 0 }

func _reset_to_defaults() -> void:
	meta_currency_total = 0
	meta_currency_spent = 0
	unlocked_skill_ids.clear()
	permanent_upgrades = _default_upgrades()
	run_history        = []
	total_runs         = 0
	legendary_skill_ids.clear()

## Phase 2: all skills unlocked for testing.
## Phase 4 will gate these behind meta-currency purchases.
func _unlock_all_for_testing() -> void:
	unlocked_skill_ids = [
		# Stackable — Common
		"iron_fist", "heavy_paper", "scissor_strike", "whetstone", "stone_skin",
		# Stackable — Uncommon
		"paper_shield", "thick_hide", "glass_cannon",
		# Non-stackable — Uncommon
		"momentum", "counterflow", "predator", "eye_for_eye", "parting_blow",
		# Non-stackable — Rare
		"fortune_turn", "blade_dance", "gamblers_favor", "comeback_kid", "echo_strike", "riposte",
		# Legendary (offered as 4th card in skill selection; stored in legendary_skill_ids when taken)
		"undying_will", "blood_pact", "second_wind", "titans_grip", "eternal_momentum",
	]
	save_data()

# ─── Public API ───────────────────────────────────────────────────────────────

func record_run(floors_cleared: int, victory: bool, currency_earned: int) -> void:
	total_runs          += 1
	meta_currency_total += currency_earned
	run_history.append({
		"floors_cleared":   floors_cleared,
		"victory":          victory,
		"currency_earned":  currency_earned,
	})
	save_data()

func unlock_skill(id: String) -> void:
	if id not in unlocked_skill_ids:
		unlocked_skill_ids.append(id)
		save_data()

## Permanently store a legendary skill for this save slot.
func add_legendary(id: String) -> void:
	if id not in legendary_skill_ids:
		legendary_skill_ids.append(id)
		save_data()

## Returns true if the player already owns this legendary on this slot.
func has_legendary(id: String) -> bool:
	return id in legendary_skill_ids
