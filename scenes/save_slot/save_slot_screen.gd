extends Control

@onready var slots_container: VBoxContainer = $Layout/SlotsContainer
@onready var back_button: Button            = $Layout/BackButton

## Tracks which slot is waiting for a delete confirmation.
var _pending_delete_slot: int   = -1
var _pending_delete_btn: Button = null

func _ready() -> void:
	back_button.pressed.connect(func(): GameManager.go_to_main_menu())
	_refresh()

# ─── Build / Refresh ─────────────────────────────────────────────────────────

func _refresh() -> void:
	_pending_delete_slot = -1
	_pending_delete_btn  = null
	for child in slots_container.get_children():
		child.queue_free()
	for i in MetaProgression.SLOT_COUNT:
		_build_slot_row(i,
			MetaProgression.get_slot_summary(i),
			MetaProgression.get_run_summary(i))

func _build_slot_row(slot: int, summary: Dictionary, run_summary: Dictionary) -> void:
	var has_meta: bool = summary.get("exists",    false)
	var has_run:  bool = run_summary.get("exists", false)
	var has_any:  bool = has_meta or has_run

	# ── Outer card ──
	var panel  := PanelContainer.new()
	slots_container.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     6)
	margin.add_theme_constant_override("margin_bottom",  6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	# ── Slot number ──
	var slot_lbl := Label.new()
	slot_lbl.text                = "Slot %d" % (slot + 1)
	slot_lbl.custom_minimum_size = Vector2(56, 0)
	slot_lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(slot_lbl)

	row.add_child(VSeparator.new())

	# ── Info label ──
	var info_lbl := Label.new()
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER

	if has_run:
		# Active run takes priority in display
		var floor: int  = run_summary.get("floor_number", 0)
		var hp: int     = run_summary.get("current_hp",   0)
		var mhp: int    = run_summary.get("max_hp",       30)
		info_lbl.text = "⚔ Run in progress — Floor %d   |   HP: %d / %d" % [floor + 1, hp, mhp]
	elif has_meta:
		var runs: int = summary.get("total_runs", 0)
		var best: int = summary.get("best_floor", 0)
		var wins: int = summary.get("victories",  0)
		info_lbl.text = "Runs: %d   |   Best Floor: %d   |   Victories: %d" % [runs, best, wins]
	else:
		info_lbl.text     = "Empty"
		info_lbl.modulate = Color(0.55, 0.55, 0.55)
	row.add_child(info_lbl)

	# ── Action buttons ──
	if has_run:
		# Continue the saved run
		var cont_btn := Button.new()
		cont_btn.text                = "Continue"
		cont_btn.custom_minimum_size = Vector2(100, 36)
		cont_btn.pressed.connect(_on_continue_pressed.bind(slot))
		row.add_child(cont_btn)

		# Discard run and start fresh on the same slot
		var new_btn := Button.new()
		new_btn.text                = "New Run"
		new_btn.custom_minimum_size = Vector2(90, 36)
		new_btn.pressed.connect(_on_new_run_pressed.bind(slot))
		row.add_child(new_btn)
	else:
		var play_btn := Button.new()
		play_btn.text                = "New Game" if not has_meta else "New Run"
		play_btn.custom_minimum_size = Vector2(110, 36)
		play_btn.pressed.connect(_on_play_pressed.bind(slot))
		row.add_child(play_btn)

	# Delete (whole slot — meta + any run save)
	if has_any:
		var del_btn := Button.new()
		del_btn.text                = "Delete"
		del_btn.custom_minimum_size = Vector2(90, 36)
		del_btn.pressed.connect(_on_delete_pressed.bind(slot, del_btn))
		row.add_child(del_btn)

# ─── Button Handlers ─────────────────────────────────────────────────────────

## Start a completely new run on this slot.
func _on_play_pressed(slot: int) -> void:
	MetaProgression.load_slot(slot)
	GameManager.start_new_run()

## Discard the saved run and start fresh (meta progression is kept).
func _on_new_run_pressed(slot: int) -> void:
	MetaProgression.load_slot(slot)
	MetaProgression.delete_run_save(slot)
	GameManager.start_new_run()

## Resume the saved mid-run state.
func _on_continue_pressed(slot: int) -> void:
	MetaProgression.load_slot(slot)
	MetaProgression.load_run_state()  # populates RunState from the save file
	GameManager.continue_run()        # deletes run save, picks enemies, enters battle

## Delete with two-press confirmation.
func _on_delete_pressed(slot: int, btn: Button) -> void:
	if _pending_delete_slot == slot:
		MetaProgression.delete_slot(slot)
		_refresh()
	else:
		if _pending_delete_btn != null:
			_pending_delete_btn.text = "Delete"
		_pending_delete_slot = slot
		_pending_delete_btn  = btn
		btn.text             = "Confirm?"
