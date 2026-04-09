extends Control

const SKILL_CARD_SCENE = preload("res://scenes/shared/skill_card.tscn")

@onready var title_label: Label = $Layout/TitleLabel
@onready var subtitle_label: Label = $Layout/SubtitleLabel
@onready var cards_row: HBoxContainer = $Layout/CardsRow
@onready var skip_button: Button = $Layout/SkipButton

func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)

	var offers   := _get_skill_offers(3)
	var legendary: SkillData = _get_legendary_offer()

	if offers.is_empty() and legendary == null:
		title_label.text    = "Skill Selection"
		subtitle_label.text = "No new skills available."
		skip_button.text    = "Continue"
		return

	title_label.text    = "Choose a Skill"
	subtitle_label.text = "Battle won! Pick one to carry forward."

	for skill in offers:
		var card: SkillCard = SKILL_CARD_SCENE.instantiate()
		cards_row.add_child(card)
		card.setup(skill)
		card.card_selected.connect(_on_card_selected)

	# Legendary 4th card (25% chance)
	if legendary:
		var card: SkillCard = SKILL_CARD_SCENE.instantiate()
		cards_row.add_child(card)
		card.setup(legendary)
		card.card_selected.connect(_on_legendary_selected)

## Returns up to [count] skills from the unlocked pool (rarity 0-2 only).
## Stackable skills appear until the player hits max_stacks.
## Non-stackable skills are excluded once the player holds them.
func _get_skill_offers(count: int) -> Array:
	var pool: Array = []
	for skill in SkillRegistry.get_unlocked_skills():
		if skill.rarity >= 3:
			continue  # legendaries are handled separately
		if skill.stackable:
			if RunState.skill_stack_count(skill.id) < skill.max_stacks:
				pool.append(skill)
		elif not RunState.has_skill(skill.id):
			pool.append(skill)
	pool.shuffle()
	# Weighted by rarity: pick rares first with lower probability
	var weighted: Array = _weighted_sort(pool)
	return weighted.slice(0, mini(count, weighted.size()))

## 25% chance of offering a legendary the player doesn't already own permanently.
func _get_legendary_offer() -> SkillData:
	if randf() > 0.25:
		return null
	var pool: Array = []
	for skill in SkillRegistry.get_unlocked_skills():
		if skill.rarity == 3 and not MetaProgression.has_legendary(skill.id):
			pool.append(skill)
	if pool.is_empty():
		return null
	return pool.pick_random()

## Sorts pool so rarer skills appear less often (simple weighted shuffle).
func _weighted_sort(pool: Array) -> Array:
	var buckets: Array = [[], [], []]
	for skill in pool:
		var idx: int = clampi(skill.rarity, 0, 2)
		buckets[idx].append(skill)
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

## Legendary selection: persist to MetaProgression and apply run effects immediately.
func _on_legendary_selected(skill: SkillData) -> void:
	MetaProgression.add_legendary(skill.id)
	RunState.active_skills.append(skill)
	RunState.apply_single_legendary_effect(skill)
	GameManager.after_skill_select()

func _on_skip_pressed() -> void:
	GameManager.after_skill_select()
