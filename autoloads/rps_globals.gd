extends Node

enum Move { ROCK = 0, PAPER = 1, SCISSORS = 2 }
enum Outcome { WIN, LOSS, TIE }

const BEATS: Dictionary = {
	Move.ROCK: Move.SCISSORS,
	Move.SCISSORS: Move.PAPER,
	Move.PAPER: Move.ROCK
}

const MOVE_NAMES: Dictionary = {
	Move.ROCK: "Rock",
	Move.PAPER: "Paper",
	Move.SCISSORS: "Scissors"
}

const MOVE_ICONS: Dictionary = {
	Move.ROCK: "✊",
	Move.PAPER: "✋",
	Move.SCISSORS: "✌"
}

static func resolve(player_move: int, enemy_move: int) -> int:
	if player_move == enemy_move:
		return Outcome.TIE
	if BEATS[player_move] == enemy_move:
		return Outcome.WIN
	return Outcome.LOSS
