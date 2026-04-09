class_name CombatantDisplay
extends VBoxContainer

@onready var name_label: Label = $NameLabel
@onready var hp_label: Label = $HpLabel
@onready var hp_bar: ProgressBar = $HpBar

var _max_hp: int = 30

func setup(display_name: String, current_hp: int, max_hp: int) -> void:
	_max_hp = max_hp
	name_label.text = display_name
	hp_bar.max_value = max_hp
	update_hp(current_hp)

func update_hp(new_hp: int) -> void:
	var clamped: int = maxi(0, new_hp)
	hp_label.text = "HP: %d / %d" % [clamped, _max_hp]
	hp_bar.value = clamped
