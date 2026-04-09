class_name MoveSelector
extends HBoxContainer

signal move_chosen(move: int)

@onready var rock_button: Button = $RockButton
@onready var paper_button: Button = $PaperButton
@onready var scissors_button: Button = $ScissorsButton

func _ready() -> void:
	rock_button.pressed.connect(func(): _emit_move(RPS.Move.ROCK))
	paper_button.pressed.connect(func(): _emit_move(RPS.Move.PAPER))
	scissors_button.pressed.connect(func(): _emit_move(RPS.Move.SCISSORS))

func _emit_move(move: int) -> void:
	move_chosen.emit(move)

func enable() -> void:
	rock_button.disabled = false
	paper_button.disabled = false
	scissors_button.disabled = false

func disable() -> void:
	rock_button.disabled = true
	paper_button.disabled = true
	scissors_button.disabled = true
