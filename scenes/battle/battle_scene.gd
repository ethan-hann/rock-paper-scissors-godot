extends Control

enum Phase { DICE_ROLL, PLAYER_PICK_TARGET, PLAYER_PICK_MOVE, ENEMY_ATTACKS, DONE }

const COMBATANT_SCENE = preload("res://scenes/battle/components/combatant_display.tscn")

@onready var player_display: CombatantDisplay = $Layout/TopRow/PlayerDisplay
@onready var dice_label: Label = $Layout/TopRow/DiceLabel
@onready var enemies_area: HBoxContainer = $Layout/EnemiesArea
@onready var status_label: Label = $Layout/StatusLabel
@onready var target_selector: HBoxContainer = $Layout/TargetSelector
@onready var move_selector: MoveSelector = $Layout/MoveSelector
@onready var battle_log: RichTextLabel = $Layout/BattleLog
@onready var result_overlay: Panel = $ResultOverlay
@onready var result_label: Label = $ResultOverlay/Content/ResultLabel
@onready var continue_button: Button = $ResultOverlay/Content/ContinueButton

var _player_hp: int = 0
var _enemy_hps: Array[int] = []
var _enemy_displays: Array[CombatantDisplay] = []
var _current_phase: Phase = Phase.DICE_ROLL
var _player_goes_first: bool = false
var _current_target_idx: int = -1
var _current_attacker_idx: int = -1
var _enemy_attack_queue: Array[int] = []
var _battle_won: bool = false

var skill_handler: SkillEffectHandler

func _ready() -> void:
	# Skill handler — instantiated in code so the .tscn stays clean
	skill_handler = SkillEffectHandler.new()
	add_child(skill_handler)
	skill_handler.initialize(RunState.active_skills)
	skill_handler.skill_triggered.connect(_on_skill_triggered)

	_player_hp = RunState.current_hp
	player_display.setup("You", _player_hp, _player_hp)

	for enemy in RunState.current_enemies:
		_enemy_hps.append(enemy.max_hp)
		var display: CombatantDisplay = COMBATANT_SCENE.instantiate()
		enemies_area.add_child(display)
		display.setup(enemy.display_name, enemy.max_hp, enemy.max_hp)
		_enemy_displays.append(display)

	move_selector.move_chosen.connect(_on_move_chosen)
	continue_button.pressed.connect(_on_continue_pressed)
	move_selector.disable()
	target_selector.visible = false
	result_overlay.visible = false

	_log("[color=cyan]Battle begins![/color]")
	for enemy in RunState.current_enemies:
		_log("  [color=yellow]%s[/color] — %s" % [enemy.display_name, enemy.description])
	if not RunState.active_skills.is_empty():
		_log("")
		_log("[color=purple]Active skills:[/color]")
		for skill in RunState.active_skills:
			_log("  ✦ [b]%s[/b] — %s" % [skill.display_name, skill.description])
	_log("")
	await get_tree().create_timer(0.5).timeout
	_do_dice_roll()

# ─── Turn Order ──────────────────────────────────────────────────────────────

func _do_dice_roll() -> void:
	_current_phase = Phase.DICE_ROLL
	var p_roll := randi_range(1, 6)
	var e_roll := randi_range(1, 6)
	while p_roll == e_roll:
		p_roll = randi_range(1, 6)
		e_roll = randi_range(1, 6)
	_player_goes_first = p_roll > e_roll
	dice_label.text = "🎲 You %d  |  Enemy %d" % [p_roll, e_roll]
	var who := "You go first!" if _player_goes_first else "Enemies go first!"
	_log("[color=yellow]🎲 Dice: %d vs %d — %s[/color]" % [p_roll, e_roll, who])
	await get_tree().create_timer(0.7).timeout
	dice_label.text = ""
	if _player_goes_first:
		_begin_player_attack_phase()
	else:
		_begin_enemy_attack_phase()

# ─── Player Turn ─────────────────────────────────────────────────────────────

func _begin_player_attack_phase() -> void:
	_current_phase = Phase.PLAYER_PICK_TARGET
	var living := _get_living_enemy_indices()
	if living.size() == 1:
		_on_target_chosen(living[0])
		return
	status_label.text = "Choose an enemy to attack:"
	_show_target_buttons()

func _show_target_buttons() -> void:
	for child in target_selector.get_children():
		child.queue_free()
	for i in _get_living_enemy_indices():
		var btn := Button.new()
		btn.text = RunState.current_enemies[i].display_name
		btn.custom_minimum_size = Vector2(130, 48)
		var idx := i
		btn.pressed.connect(func(): _on_target_chosen(idx))
		target_selector.add_child(btn)
	target_selector.visible = true

func _on_target_chosen(enemy_idx: int) -> void:
	target_selector.visible = false
	_current_target_idx = enemy_idx
	_current_phase = Phase.PLAYER_PICK_MOVE

	# ── Skill hook: on_exchange_start ──
	skill_handler.on_exchange_start()

	var enemy_name := RunState.current_enemies[enemy_idx].display_name
	if skill_handler.force_win_this_exchange:
		status_label.text = "✨ Attacking %s [Blade Dance — auto-win!]" % enemy_name
	else:
		status_label.text = "Attacking %s — Choose your move!" % enemy_name
	move_selector.enable()

# ─── Enemy Turn ───────────────────────────────────────────────────────────────

func _begin_enemy_attack_phase() -> void:
	_enemy_attack_queue = _get_living_enemy_indices()
	if not _player_goes_first:
		_enemy_attack_queue.shuffle()
	_process_next_enemy_attack()

func _process_next_enemy_attack() -> void:
	if _enemy_attack_queue.is_empty():
		_log("")
		await get_tree().create_timer(0.4).timeout
		if _player_goes_first:
			_do_dice_roll()
		else:
			_begin_player_attack_phase()
		return

	_current_attacker_idx = _enemy_attack_queue.pop_front()
	var enemy := RunState.current_enemies[_current_attacker_idx]
	_current_phase = Phase.ENEMY_ATTACKS

	# ── Skill hook: on_exchange_start ──
	skill_handler.on_exchange_start()

	if skill_handler.force_win_this_exchange:
		status_label.text = "✨ %s attacks! [Blade Dance — auto-block!]" % enemy.display_name
	else:
		status_label.text = "%s attacks! Choose your defense:" % enemy.display_name
	move_selector.enable()

# ─── Move Resolution ─────────────────────────────────────────────────────────

func _on_move_chosen(move: int) -> void:
	move_selector.disable()
	match _current_phase:
		Phase.PLAYER_PICK_MOVE:
			_resolve_player_attack(move)
		Phase.ENEMY_ATTACKS:
			_resolve_player_defense(move)

func _resolve_player_attack(player_move: int) -> void:
	var enemy_idx := _current_target_idx
	var enemy := RunState.current_enemies[enemy_idx]
	var enemy_move := _choose_enemy_move(enemy)
	RunState.player_move_history.append(player_move)

	var outcome := RPS.Outcome.WIN if skill_handler.force_win_this_exchange \
		else RPS.resolve(player_move, enemy_move)

	_log_exchange("You", player_move, enemy.display_name, enemy_move)
	if skill_handler.force_win_this_exchange:
		_log("  ✨ [color=purple][Blade Dance][/color] Exchange auto-won!")

	match outcome:
		RPS.Outcome.WIN:
			# ── Skill hook: modify attack damage ──
			var dmg := skill_handler.modify_attack_damage(RunState.player_base_damage, player_move)
			_enemy_hps[enemy_idx] = maxi(0, _enemy_hps[enemy_idx] - dmg)
			_enemy_displays[enemy_idx].update_hp(_enemy_hps[enemy_idx])
			_log("  → [color=green]Hit![/color] %s takes %d damage." % [enemy.display_name, dmg])
			if _enemy_hps[enemy_idx] == 0:
				_log("  → [color=green]%s is defeated![/color]" % enemy.display_name)
			skill_handler.on_player_wins_exchange(true)
		RPS.Outcome.LOSS:
			# ── Skill hook: modify damage taken ──
			var dmg := skill_handler.modify_damage_taken(enemy.base_damage)
			_player_hp = maxi(0, _player_hp - dmg)
			player_display.update_hp(_player_hp)
			_log("  → [color=red]%s counters![/color] You take %d damage." % [enemy.display_name, dmg])
			skill_handler.on_player_loses_exchange(true)
		RPS.Outcome.TIE:
			_log("  → [color=yellow]Tie![/color] No damage.")
			skill_handler.on_tie_exchange()

	await get_tree().create_timer(0.7).timeout
	if _check_battle_over():
		return
	_begin_enemy_attack_phase()

func _resolve_player_defense(defense_move: int) -> void:
	var enemy_idx := _current_attacker_idx
	var enemy := RunState.current_enemies[enemy_idx]
	var enemy_move := _choose_enemy_move(enemy)
	RunState.player_move_history.append(defense_move)

	var outcome := RPS.Outcome.WIN if skill_handler.force_win_this_exchange \
		else RPS.resolve(defense_move, enemy_move)

	_log_exchange("You (defense)", defense_move, enemy.display_name, enemy_move)
	if skill_handler.force_win_this_exchange:
		_log("  ✨ [color=purple][Blade Dance][/color] Exchange auto-blocked!")

	match outcome:
		RPS.Outcome.WIN:
			_log("  → [color=green]Blocked![/color] You deflect %s's attack." % enemy.display_name)
			skill_handler.on_player_wins_exchange(false)
		RPS.Outcome.LOSS:
			# ── Skill hook: modify damage taken ──
			var dmg := skill_handler.modify_damage_taken(enemy.base_damage)
			_player_hp = maxi(0, _player_hp - dmg)
			player_display.update_hp(_player_hp)
			_log("  → [color=red]Hit![/color] %s deals %d damage." % [enemy.display_name, dmg])
			skill_handler.on_player_loses_exchange(false)
		RPS.Outcome.TIE:
			_log("  → [color=yellow]Tie![/color] No damage.")
			skill_handler.on_tie_exchange()

	await get_tree().create_timer(0.7).timeout
	if _check_battle_over():
		return
	_process_next_enemy_attack()

# ─── Enemy AI ─────────────────────────────────────────────────────────────────

func _choose_enemy_move(enemy: EnemyData) -> int:
	match enemy.ai_type:
		0:  return RPS.Move.values().pick_random()
		1:  return _weighted_random(enemy.ai_weights)
		2:
			if enemy.ai_pattern.is_empty():
				return RPS.Move.values().pick_random()
			return enemy.ai_pattern[RunState.player_move_history.size() % enemy.ai_pattern.size()]
		3:  return _adaptive_choice()
		4:
			if RunState.player_move_history.is_empty():
				return RPS.Move.values().pick_random()
			return RunState.player_move_history[-1]
	return RPS.Move.values().pick_random()

func _weighted_random(weights: Dictionary) -> int:
	var keys: Array[String] = ["rock", "paper", "scissors"]
	var move_map: Dictionary = {"rock": RPS.Move.ROCK, "paper": RPS.Move.PAPER, "scissors": RPS.Move.SCISSORS}
	var total := 0.0
	for k: String in keys:
		total += weights.get(k, 0.333)
	var r := randf() * total
	var cumulative := 0.0
	for k: String in keys:
		cumulative += weights.get(k, 0.333)
		if r <= cumulative:
			return move_map[k]
	return RPS.Move.ROCK

func _adaptive_choice() -> int:
	var history := RunState.player_move_history
	if history.size() < 3:
		return RPS.Move.values().pick_random()
	var counts: Dictionary = {RPS.Move.ROCK: 0, RPS.Move.PAPER: 0, RPS.Move.SCISSORS: 0}
	for m: int in history:
		counts[m] += 1
	var most_common: int = RPS.Move.ROCK
	var top := -1
	for m: int in counts:
		if counts[m] > top:
			top = counts[m]
			most_common = m
	for m: int in RPS.BEATS:
		if RPS.BEATS[m] == most_common:
			return m
	return RPS.Move.values().pick_random()

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _get_living_enemy_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(_enemy_hps.size()):
		if _enemy_hps[i] > 0:
			result.append(i)
	return result

func _check_battle_over() -> bool:
	if _player_hp <= 0:
		_end_battle(false)
		return true
	if _get_living_enemy_indices().is_empty():
		_end_battle(true)
		return true
	return false

func _end_battle(player_won: bool) -> void:
	_battle_won = player_won
	_current_phase = Phase.DONE
	RunState.current_hp = _player_hp
	skill_handler.on_battle_end()
	if player_won:
		result_label.text = "Victory!"
		_log("\n[color=green][b]All enemies defeated![/b][/color]")
	else:
		result_label.text = "Defeated!"
		_log("\n[color=red][b]You were defeated...[/b][/color]")
	result_overlay.visible = true

func _on_continue_pressed() -> void:
	if _battle_won:
		GameManager.battle_won()
	else:
		GameManager.battle_lost()

func _on_skill_triggered(skill_name: String, message: String) -> void:
	_log("  ✦ [color=#c8a0ff][b]%s[/b][/color]: %s" % [skill_name, message])

func _log_exchange(attacker: String, a_move: int, defender: String, d_move: int) -> void:
	_log("[b]%s[/b] plays %s %s  vs  [b]%s[/b] plays %s %s" % [
		attacker, RPS.MOVE_ICONS[a_move], RPS.MOVE_NAMES[a_move],
		defender, RPS.MOVE_ICONS[d_move], RPS.MOVE_NAMES[d_move]
	])

func _log(message: String) -> void:
	battle_log.append_text(message + "\n")
