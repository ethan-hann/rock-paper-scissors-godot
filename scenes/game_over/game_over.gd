extends Control

@onready var result_label: Label = $Content/ResultLabel
@onready var detail_label: Label = $Content/DetailLabel
@onready var restart_button: Button = $Content/RestartButton
@onready var main_menu_button: Button = $Content/MainMenuButton

func _ready() -> void:
	if GameManager.last_victory:
		result_label.text = "Victory!"
		detail_label.text = "The enemy is defeated.\nYou earned %d meta shards." % RunState.meta_currency_earned
	else:
		result_label.text = "Defeated!"
		detail_label.text = "You were overcome.\nBetter luck next run."

	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_restart_pressed() -> void:
	GameManager.start_new_run()

func _on_main_menu_pressed() -> void:
	GameManager.go_to_main_menu()
