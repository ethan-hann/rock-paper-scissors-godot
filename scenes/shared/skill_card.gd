class_name SkillCard
extends PanelContainer

signal card_selected(skill: SkillData)

@onready var name_label: Label = $Content/NameLabel
@onready var rarity_label: Label = $Content/RarityLabel
@onready var description_label: Label = $Content/DescriptionLabel
@onready var choose_button: Button = $Content/ChooseButton

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Legendary"]
const RARITY_COLORS: Array[Color] = [
	Color("#c7c9c6"),   # Common  — grey
	Color("#1fb505"),   # Uncommon — teal
	Color("#cb17f2"),          # Rare    — purple
	Color("#f2ba17")           # Legendary - gold
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
