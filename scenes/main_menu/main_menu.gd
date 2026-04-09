extends Control

@onready var start_button: Button = $Content/StartButton
@onready var quit_button: Button = $Content/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	GameManager.go_to_save_slot()

func _on_quit_pressed() -> void:
	get_tree().quit()
