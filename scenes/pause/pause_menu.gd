class_name PauseMenu
extends CanvasLayer

@onready var hp_label: Label           = $Panel/Content/HPLabel
@onready var barrier_label: Label      = $Panel/Content/BarrierLabel
@onready var dmg_rock_label: Label     = $Panel/Content/DmgRockLabel
@onready var dmg_paper_label: Label    = $Panel/Content/DmgPaperLabel
@onready var dmg_scissors_label: Label = $Panel/Content/DmgScissorsLabel
@onready var reduction_label: Label    = $Panel/Content/ReductionLabel
@onready var skills_list: VBoxContainer  = $Panel/Content/SkillsList
@onready var resume_button: Button      = $Panel/Content/ResumeButton
@onready var main_menu_button: Button   = $Panel/Content/MainMenuButton

func _ready() -> void:
	resume_button.pressed.connect(close)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	visible = false

func open(stats: Dictionary) -> void:
	_populate(stats)
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_main_menu_pressed() -> void:
	# Save the mid-run state (HP, floor, active skills) so the player can
	# continue this run later from the slot screen.
	# Meta progression itself hasn't changed during battle, but save it too
	# for safety in case future code adds mid-battle meta updates.
	MetaProgression.save_run_state()
	MetaProgression.save_data()
	get_tree().paused = false
	GameManager.go_to_main_menu()

func _populate(stats: Dictionary) -> void:
	var current_hp: int  = stats.get("current_hp",    0)
	var max_hp: int      = stats.get("max_hp",         30)
	var barrier: int     = stats.get("barrier_hp",     0)
	var dmg_rock: int    = stats.get("dmg_rock",       8)
	var dmg_paper: int   = stats.get("dmg_paper",      8)
	var dmg_sci: int     = stats.get("dmg_scissors",   8)
	var flat_red: int    = stats.get("flat_reduction", 0)
	var glass_pen: int   = stats.get("glass_penalty",  0)
	var skills: Array    = stats.get("skills",         [])

	hp_label.text = "HP:  %d / %d" % [current_hp, max_hp]

	if barrier > 0:
		barrier_label.text    = "Barrier:  %d HP" % barrier
		barrier_label.visible = true
	else:
		barrier_label.visible = false

	dmg_rock_label.text     = "✊ Rock:      %d dmg" % dmg_rock
	dmg_paper_label.text    = "✋ Paper:     %d dmg" % dmg_paper
	dmg_scissors_label.text = "✌ Scissors:  %d dmg" % dmg_sci

	var def_parts: Array[String] = []
	if flat_red > 0:
		def_parts.append("−%d incoming" % flat_red)
	if glass_pen > 0:
		def_parts.append("+%d taken (Glass Cannon)" % glass_pen)
	if def_parts.is_empty():
		reduction_label.visible = false
	else:
		reduction_label.text    = "Defense:  " + ", ".join(def_parts)
		reduction_label.visible = true

	# Clear old entries
	for child in skills_list.get_children():
		child.queue_free()

	if skills.is_empty():
		var lbl := Label.new()
		lbl.text = "(No skills)"
		skills_list.add_child(lbl)
		return

	# Aggregate stacks (keyed by effect_key)
	var seen: Dictionary = {}   # effect_key → { skill, count }
	for skill in skills:
		var key: String = skill.effect_key
		if key in seen:
			seen[key]["count"] += 1
		else:
			seen[key] = { "skill": skill, "count": 1 }

	const RARITY_PREFIX: Array[String] = ["", "★ ", "✦ ", "✦✦ "]
	for key in seen:
		var entry: Dictionary = seen[key]
		var skill             = entry["skill"]
		var count: int        = entry["count"]
		var prefix: String    = RARITY_PREFIX[clampi(skill.rarity, 0, 3)]
		var stack_str: String = ""
		if skill.stackable:
			stack_str = "  (%d / %d)" % [count, skill.max_stacks]
		var lbl               := Label.new()
		lbl.text              = "%s%s%s" % [prefix, skill.display_name, stack_str]
		skills_list.add_child(lbl)
