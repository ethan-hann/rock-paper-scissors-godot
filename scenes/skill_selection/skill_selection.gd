extends Control

const SKILL_CARD_SCENE = preload("res://scenes/shared/skill_card.tscn")

@onready var title_label: Label = $Layout/TitleLabel
@onready var subtitle_label: Label = $Layout/SubtitleLabel
@onready var cards_row: HBoxContainer = $Layout/CardsRow
@onready var skip_button: Button = $Layout/SkipButton

func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)

	var offers := _get_skill_offers(3)
	if offers.is_empty():
		title_label.text = "Skill Selection"
		subtitle_label.text = "No new skills available."
		skip_button.text = "Continue"
		return

	title_label.text = "Choose a Skill"
	subtitle_label.text = "Battle won! Pick one to carry forward."

	for skill in offers:
		var card: SkillCard = SKILL_CARD_SCENE.instantiate()
		cards_row.add_child(card)
		card.setup(skill)
		card.card_selected.connect(_on_card_selected)

## Returns up to [count] skills from the unlocked pool, excluding skills already held.
func _get_skill_offers(count: int) -> Array:
	var pool: Array = []
	for skill in SkillRegistry.get_unlocked_skills():
		if not RunState.has_skill(skill.id):
			pool.append(skill)
	pool.shuffle()
	# Weighted by rarity: pick rares first with lower probability
	var weighted: Array = _weighted_sort(pool)
	return weighted.slice(0, mini(count, weighted.size()))

## Sorts pool so rarer skills appear less often (simple weighted shuffle).
func _weighted_sort(pool: Array) -> Array:
	var buckets: Array = [[], [], []]
	for skill in pool:
		buckets[skill.rarity].append(skill)
	var result: Array = []
	# Always include at least 1 common if available
	if not buckets[0].is_empty():
		buckets[0].shuffle()
		result.append(buckets[0].pop_front())
	# Fill remaining slots randomly across all rarities (rares weighted lower)
	var remainder: Array = []
	for bucket in buckets:
		remainder.append_array(bucket)
	remainder.shuffle()
	result.append_array(remainder)
	return result

func _on_card_selected(skill: SkillData) -> void:
	RunState.active_skills.append(skill)
	GameManager.after_skill_select()

func _on_skip_pressed() -> void:
	GameManager.after_skill_select()
