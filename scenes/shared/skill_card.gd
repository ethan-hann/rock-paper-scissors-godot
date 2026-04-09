class_name SkillCard
extends PanelContainer

signal card_selected(skill: SkillData)

@onready var name_label: Label = $Content/NameLabel
@onready var rarity_label: Label = $Content/RarityLabel
@onready var description_label: Label = $Content/DescriptionLabel
@onready var choose_button: Button = $Content/ChooseButton

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare"]
const RARITY_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.75),   # Common  — grey
	Color(0.20, 0.85, 0.85),   # Uncommon — teal
	Color(1.00, 0.80, 0.10),   # Rare    — gold
]

var _skill: SkillData = null

func setup(skill: SkillData) -> void:
	_skill = skill
	name_label.text = skill.display_name
	rarity_label.text = RARITY_NAMES[skill.rarity]
	rarity_label.add_theme_color_override("font_color", RARITY_COLORS[skill.rarity])
	description_label.text = skill.description
	choose_button.pressed.connect(_on_choose_pressed)

func _on_choose_pressed() -> void:
	card_selected.emit(_skill)
