class_name RoundTracker
extends HBoxContainer

@onready var player_wins_label: Label = $PlayerWins
@onready var enemy_wins_label: Label = $EnemyWins

var _player_target: int = 2
var _enemy_target: int = 2

func setup(player_rounds_to_win: int, enemy_rounds_to_win: int) -> void:
	_player_target = player_rounds_to_win
	_enemy_target = enemy_rounds_to_win
	update(0, 0)

func update(player_wins: int, enemy_wins: int) -> void:
	player_wins_label.text = "You: %d / %d" % [player_wins, _player_target]
	enemy_wins_label.text = "Enemy: %d / %d" % [enemy_wins, _enemy_target]
