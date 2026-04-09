class_name SkillEffectHandler
extends Node

## Emitted whenever a skill visibly activates during battle.
signal skill_triggered(skill_name: String, message: String)

# Skills active this run
var _skills: Array = []

# Per-battle tracking state
var _exchange_count: int = 0
var _consecutive_win_streak: int = 0
var _first_damage_taken: bool = false
var _double_next_attack: bool = false
var _block_bonus_active: bool = false

## Context flag: set to true by on_exchange_start() when Blade Dance activates.
## battle_scene reads this after calling on_exchange_start() to skip RPS resolution.
var force_win_this_exchange: bool = false

# ─── Setup ───────────────────────────────────────────────────────────────────

func initialize(skills: Array) -> void:
	_skills = skills.duplicate()
	_reset_battle_state()

func _reset_battle_state() -> void:
	_exchange_count = 0
	_consecutive_win_streak = 0
	_first_damage_taken = false
	_double_next_attack = false
	_block_bonus_active = false
	force_win_this_exchange = false

# ─── Hooks ───────────────────────────────────────────────────────────────────

## Call before each exchange (attack or defense) — before moves are chosen.
func on_exchange_start() -> void:
	_exchange_count += 1
	force_win_this_exchange = false
	for skill in _skills:
		if skill.effect_key == "blade_dance" and _exchange_count % 3 == 0:
			force_win_this_exchange = true
			skill_triggered.emit(skill.display_name, "Exchange #%d — your move auto-wins!" % _exchange_count)

## Modify damage dealt when the player wins an offensive attack.
func modify_attack_damage(base_damage: int, player_move: int) -> int:
	var dmg := base_damage
	for skill in _skills:
		match skill.effect_key:
			"iron_fist":
				if player_move == RPS.Move.ROCK:
					var bonus: int = skill.parameters.get("bonus_damage", 4)
					dmg += bonus
					skill_triggered.emit(skill.display_name, "+%d Rock damage!" % bonus)
			"scissor_strike":
				if player_move == RPS.Move.SCISSORS:
					var bonus: int = skill.parameters.get("bonus_damage", 5)
					dmg += bonus
					skill_triggered.emit(skill.display_name, "+%d Scissors damage!" % bonus)
			"momentum":
				var needed: int = skill.parameters.get("required_streak", 2)
				if _consecutive_win_streak >= needed:
					var bonus: int = skill.parameters.get("bonus_damage", 8)
					dmg += bonus
					skill_triggered.emit(skill.display_name, "+%d (win streak ×%d)!" % [bonus, _consecutive_win_streak])
			"fortune_turn":
				if _double_next_attack:
					dmg *= 2
					_double_next_attack = false
					skill_triggered.emit(skill.display_name, "Double damage triggered!")
			"counterflow":
				if _block_bonus_active:
					var bonus: int = skill.parameters.get("bonus_damage", 6)
					dmg += bonus
					_block_bonus_active = false
					skill_triggered.emit(skill.display_name, "+%d after-block bonus!" % bonus)
	return dmg

## Modify damage taken by the player from any source.
func modify_damage_taken(base_damage: int) -> int:
	var dmg := base_damage
	for skill in _skills:
		match skill.effect_key:
			"paper_shield":
				if not _first_damage_taken:
					var reduction: int = skill.parameters.get("reduction", 4)
					dmg = maxi(0, dmg - reduction)
					_first_damage_taken = true
					skill_triggered.emit(skill.display_name, "First hit reduced by %d!" % reduction)
			"stone_skin":
				var reduction: int = skill.parameters.get("reduction", 2)
				dmg = maxi(1, dmg - reduction)
	return dmg

## Call after the player wins any exchange.
## was_attacking = true  → player initiated the attack
## was_attacking = false → player was defending against an enemy attack
func on_player_wins_exchange(was_attacking: bool) -> void:
	_consecutive_win_streak += 1
	if not was_attacking:
		# Successful block — activate counterflow bonus for next attack
		for skill in _skills:
			if skill.effect_key == "counterflow":
				_block_bonus_active = true
				skill_triggered.emit(skill.display_name, "Next attack gets a bonus!")

## Call after the player loses any exchange (takes damage).
func on_player_loses_exchange(was_attacking: bool) -> void:
	_consecutive_win_streak = 0
	if not was_attacking:
		# Failed to block an enemy attack — activate fortune_turn
		for skill in _skills:
			if skill.effect_key == "fortune_turn":
				_double_next_attack = true
				skill_triggered.emit(skill.display_name, "Next attack will deal double damage!")

func on_tie_exchange() -> void:
	pass  # Ties don't break the win streak

func on_battle_end() -> void:
	_reset_battle_state()
