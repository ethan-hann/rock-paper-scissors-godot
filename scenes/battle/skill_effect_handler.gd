class_name SkillEffectHandler
extends Node

## Emitted whenever a skill visibly activates during battle.
signal skill_triggered(skill_name: String, message: String)

# Skills active this run
var _skills: Array = []

# Per-battle tracking state
var _exchange_count: int = 0
var _consecutive_win_streak: int = 0
var _barrier_hp: int = 0
var _double_next_attack: bool = false
var _block_bonus_active: bool = false
var _comeback_threshold_crossed: bool = false
var _comeback_attacks_remaining: int = 0
var _second_wind_used: bool = false

## Set by on_exchange_start() — battle_scene checks this to skip RPS resolution.
var force_win_this_exchange: bool = false
## Set by on_player_wins_exchange() — battle_scene checks this to fire an echo attack.
var should_repeat_attack: bool = false

# ─── Setup ───────────────────────────────────────────────────────────────────

func initialize(skills: Array) -> void:
	_skills = skills.duplicate()
	_reset_battle_state()

func _reset_battle_state() -> void:
	_exchange_count = 0
	_consecutive_win_streak = 0
	_barrier_hp = 0
	_double_next_attack = false
	_block_bonus_active = false
	_comeback_threshold_crossed = false
	_comeback_attacks_remaining = 0
	_second_wind_used = false
	force_win_this_exchange = false
	should_repeat_attack = false

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _count_skill(effect_key: String) -> int:
	var n := 0
	for skill in _skills:
		if skill.effect_key == effect_key:
			n += 1
	return n

## Sum a numeric parameter across all matching skill stacks.
func _sum_param(effect_key: String, param_key: String, default_val: int) -> int:
	var total := 0
	for skill in _skills:
		if skill.effect_key == effect_key:
			total += skill.parameters.get(param_key, default_val)
	return total

## Return the first matching skill, or null.
func _get_first(effect_key: String) -> SkillData:
	for skill in _skills:
		if skill.effect_key == effect_key:
			return skill
	return null

# ─── Battle Start ─────────────────────────────────────────────────────────────

func on_battle_start() -> void:
	# Paper Shield: each stack grants barrier HP
	var shield_count := _count_skill("paper_shield")
	if shield_count > 0:
		var per_stack: int = _get_first("paper_shield").parameters.get("barrier_hp", 6)
		_barrier_hp = shield_count * per_stack
		var label := "Paper Shield ×%d" % shield_count if shield_count > 1 else "Paper Shield"
		skill_triggered.emit(label, "Barrier of %d HP active!" % _barrier_hp)

## Returns true if Gambler's Favor forces the player to always act first.
func should_player_go_first() -> bool:
	return _count_skill("gamblers_favor") > 0

# ─── Exchange Start ───────────────────────────────────────────────────────────

## Call before each exchange — increments the counter and checks Blade Dance.
func on_exchange_start() -> void:
	_exchange_count += 1
	force_win_this_exchange = false
	var bd := _get_first("blade_dance")
	if bd and _exchange_count % 3 == 0:
		force_win_this_exchange = true
		skill_triggered.emit(bd.display_name, "Exchange #%d — your move auto-wins!" % _exchange_count)

# ─── Modify Attack Damage ─────────────────────────────────────────────────────

func modify_attack_damage(base_damage: int, player_move: int) -> int:
	var dmg := base_damage

	# --- Stackable flat bonuses (all moves) ---
	var whetstone_count := _count_skill("whetstone")
	if whetstone_count > 0:
		var bonus := _sum_param("whetstone", "bonus_damage", 2)
		dmg += bonus
		var label := "Whetstone ×%d" % whetstone_count if whetstone_count > 1 else "Whetstone"
		skill_triggered.emit(label, "+%d to all attacks!" % bonus)

	var gc_count := _count_skill("glass_cannon")
	if gc_count > 0:
		var bonus := _sum_param("glass_cannon", "bonus_damage", 5)
		dmg += bonus
		var label := "Glass Cannon ×%d" % gc_count if gc_count > 1 else "Glass Cannon"
		skill_triggered.emit(label, "+%d damage!" % bonus)

	# --- Stackable move-specific bonuses ---
	match player_move:
		RPS.Move.ROCK:
			var iron_count := _count_skill("iron_fist")
			if iron_count > 0:
				var bonus := _sum_param("iron_fist", "bonus_damage", 4)
				dmg += bonus
				var label := "Iron Fist ×%d" % iron_count if iron_count > 1 else "Iron Fist"
				skill_triggered.emit(label, "+%d Rock damage!" % bonus)
		RPS.Move.PAPER:
			var hp_count := _count_skill("heavy_paper")
			if hp_count > 0:
				var bonus := _sum_param("heavy_paper", "bonus_damage", 4)
				dmg += bonus
				var label := "Heavy Paper ×%d" % hp_count if hp_count > 1 else "Heavy Paper"
				skill_triggered.emit(label, "+%d Paper damage!" % bonus)
		RPS.Move.SCISSORS:
			var sc_count := _count_skill("scissor_strike")
			if sc_count > 0:
				var bonus := _sum_param("scissor_strike", "bonus_damage", 5)
				dmg += bonus
				var label := "Scissor Strike ×%d" % sc_count if sc_count > 1 else "Scissor Strike"
				skill_triggered.emit(label, "+%d Scissors damage!" % bonus)

	# --- Non-stackable conditional bonuses ---
	var momentum := _get_first("momentum")
	if momentum:
		var needed: int = momentum.parameters.get("required_streak", 2)
		if _consecutive_win_streak >= needed:
			var bonus: int = momentum.parameters.get("bonus_damage", 8)
			dmg += bonus
			skill_triggered.emit(momentum.display_name, "+%d (win streak ×%d)!" % [bonus, _consecutive_win_streak])

	var cf := _get_first("counterflow")
	if cf and _block_bonus_active:
		var bonus: int = cf.parameters.get("bonus_damage", 6)
		dmg += bonus
		_block_bonus_active = false
		skill_triggered.emit(cf.display_name, "+%d after-block bonus!" % bonus)

	var ft := _get_first("fortune_turn")
	if ft and _double_next_attack:
		dmg *= 2
		_double_next_attack = false
		skill_triggered.emit(ft.display_name, "Double damage triggered!")

	var ck := _get_first("comeback_kid")
	if ck and _comeback_attacks_remaining > 0:
		var bonus: int = ck.parameters.get("bonus_damage", 10)
		dmg += bonus
		_comeback_attacks_remaining -= 1
		skill_triggered.emit(ck.display_name, "+%d! (%d charges left)" % [bonus, _comeback_attacks_remaining])

	return dmg

# ─── Modify Damage Taken ──────────────────────────────────────────────────────

func modify_damage_taken(base_damage: int) -> int:
	var dmg := base_damage

	# Glass Cannon: +penalty per stack (silently applied — penalty was shown at equip)
	var gc_penalty := _count_skill("glass_cannon") * 2
	dmg += gc_penalty

	# Flat reductions (stone_skin + thick_hide stacked together)
	var stone_red := _sum_param("stone_skin", "reduction", 2)
	var hide_red  := _sum_param("thick_hide", "reduction", 3)
	var total_red := stone_red + hide_red
	if total_red > 0:
		dmg = maxi(1, dmg - total_red)
		var parts: Array[String] = []
		if stone_red > 0:
			var n := _count_skill("stone_skin")
			parts.append("Stone Skin%s −%d" % [" ×%d" % n if n > 1 else "", stone_red])
		if hide_red > 0:
			var n := _count_skill("thick_hide")
			parts.append("Thick Hide%s −%d" % [" ×%d" % n if n > 1 else "", hide_red])
		skill_triggered.emit("Defense", "%s" % ", ".join(parts))

	# Barrier absorption (paper_shield)
	if _barrier_hp > 0 and dmg > 0:
		var absorbed := mini(dmg, _barrier_hp)
		_barrier_hp -= absorbed
		dmg -= absorbed
		var s := _get_first("paper_shield")
		if s:
			if dmg == 0:
				skill_triggered.emit(s.display_name, "Barrier absorbed all damage! (%d HP remaining)" % _barrier_hp)
			else:
				skill_triggered.emit(s.display_name, "Barrier absorbed %d! %d damage passes through." % [absorbed, dmg])

	return dmg

## Returns counter-damage dealt back to the attacker when the player fails a block (Eye for an Eye).
## 0 if skill not held.
func get_counter_damage(enemy_base_damage: int) -> int:
	var s := _get_first("eye_for_eye")
	if s == null:
		return 0
	var counter := enemy_base_damage / 2
	if counter > 0:
		skill_triggered.emit(s.display_name, "Counter-attack for %d damage!" % counter)
	return counter

# ─── On Enemy Defeated ────────────────────────────────────────────────────────

## Returns HP healed to the player when an enemy is killed (Predator). 0 if not held.
func on_enemy_defeated() -> int:
	var s := _get_first("predator")
	if s == null:
		return 0
	var heal: int = s.parameters.get("heal", 8)
	skill_triggered.emit(s.display_name, "Healed %d HP from the kill!" % heal)
	return heal

## Returns splash damage to deal to a random living enemy (Parting Blow). 0 if not held.
func get_parting_blow_damage() -> int:
	var s := _get_first("parting_blow")
	if s == null:
		return 0
	var splash: int = s.parameters.get("splash_damage", 8)
	skill_triggered.emit(s.display_name, "%d splash damage!" % splash)
	return splash

# ─── Exchange Outcome Hooks ───────────────────────────────────────────────────

## Call after the player wins any exchange.
## was_attacking = true  → player initiated the attack.
## was_attacking = false → player was defending.
func on_player_wins_exchange(was_attacking: bool) -> void:
	_consecutive_win_streak += 1
	should_repeat_attack = false
	if was_attacking:
		# Echo Strike: 33% chance to repeat
		var es := _get_first("echo_strike")
		if es:
			var chance: float = es.parameters.get("chance", 0.333)
			if randf() < chance:
				should_repeat_attack = true
				skill_triggered.emit(es.display_name, "Echo Strike — follow-up attack!")
	else:
		# Successful block → Counterflow bonus primed
		var cf := _get_first("counterflow")
		if cf:
			_block_bonus_active = true
			skill_triggered.emit(cf.display_name, "Next attack gets +%d!" % cf.parameters.get("bonus_damage", 6))

## Call after the player loses any exchange (takes damage).
func on_player_loses_exchange(was_attacking: bool) -> void:
	_consecutive_win_streak = 0
	if not was_attacking:
		# Failed to block → Fortune's Turn activates
		var ft := _get_first("fortune_turn")
		if ft:
			_double_next_attack = true
			skill_triggered.emit(ft.display_name, "Next attack deals double damage!")

func on_tie_exchange() -> void:
	# Eternal Momentum: ties count as wins for the streak.
	var em := _get_first("eternal_momentum")
	if em:
		_consecutive_win_streak += 1
		skill_triggered.emit(em.display_name, "Tie counts as a win! Streak: %d" % _consecutive_win_streak)

## Call whenever player HP changes.
## Returns the amount of HP that should be healed (> 0 when Second Wind triggers).
func on_player_hp_changed(current_hp: int, max_hp: int) -> int:
	var healed := 0

	# Second Wind: heal once per battle when HP first drops to ≤ 25%.
	if not _second_wind_used:
		var sw := _get_first("second_wind")
		if sw:
			var threshold: float = sw.parameters.get("threshold", 0.25)
			if current_hp > 0 and current_hp <= int(max_hp * threshold):
				_second_wind_used = true
				var heal: int = sw.parameters.get("heal", 12)
				healed = heal
				skill_triggered.emit(sw.display_name, "Second Wind! Healing %d HP!" % heal)

	# Comeback Kid: triggers once per run when HP first drops to ≤ 30%.
	if not _comeback_threshold_crossed:
		var ck := _get_first("comeback_kid")
		if ck:
			var threshold: float = ck.parameters.get("threshold", 0.3)
			if current_hp > 0 and current_hp <= int(max_hp * threshold):
				_comeback_threshold_crossed = true
				_comeback_attacks_remaining = ck.parameters.get("attack_count", 3)
				skill_triggered.emit(ck.display_name, "Triggered! Next %d attacks +%d damage!" % [
					_comeback_attacks_remaining,
					ck.parameters.get("bonus_damage", 10)
				])

	return healed

## Call when the player's HP would reach 0 before ending the battle.
## Returns 1 (HP to restore to) if Undying Will saves the player, or 0 if no save is available.
func try_death_save() -> int:
	if RunState.undying_will_used:
		return 0
	var s := _get_first("undying_will")
	if s == null:
		return 0
	RunState.undying_will_used = true
	skill_triggered.emit(s.display_name, "Survived lethal damage! You live with 1 HP!")
	return 1

## Apply legendary outcome modifications before the match statement in battle_scene.
## Currently handles Titan's Grip: Rock losses become Ties.
## Returns the (possibly modified) outcome.
func modify_player_outcome(player_move: int, outcome: int) -> int:
	if outcome == RPS.Outcome.LOSS and player_move == RPS.Move.ROCK:
		var s := _get_first("titans_grip")
		if s:
			skill_triggered.emit(s.display_name, "Rock cannot lose — Loss converted to Tie!")
			return RPS.Outcome.TIE
	return outcome

func on_battle_end() -> void:
	_reset_battle_state()

# ─── Stats Snapshot (for Pause Menu) ─────────────────────────────────────────

## Returns a Dictionary of computed stats for display in the pause menu.
func get_stats_snapshot(current_hp: int) -> Dictionary:
	var base   := RunState.player_base_damage
	var bonus_all := _sum_param("whetstone", "bonus_damage", 2) \
		+ _sum_param("glass_cannon", "bonus_damage", 5)
	return {
		"current_hp":    current_hp,
		"max_hp":        RunState.max_hp,
		"barrier_hp":    _barrier_hp,
		"base_damage":   base,
		"dmg_rock":      base + bonus_all + _sum_param("iron_fist",      "bonus_damage", 4),
		"dmg_paper":     base + bonus_all + _sum_param("heavy_paper",    "bonus_damage", 4),
		"dmg_scissors":  base + bonus_all + _sum_param("scissor_strike", "bonus_damage", 5),
		"flat_reduction": _sum_param("stone_skin", "reduction", 2) \
			+ _sum_param("thick_hide", "reduction", 3),
		"glass_penalty": _count_skill("glass_cannon") * 2,
		"skills":        _skills
	}
