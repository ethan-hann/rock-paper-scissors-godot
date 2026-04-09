class_name ModifierRoller

## Returns a pool of all possible modifier definitions.
## Each entry: type, display_name, icon, tier_values [weak, moderate, strong], desc_template.
static func _get_pool() -> Array:
	return [
		{
			"type":         "armor",
			"display_name": "Armored",
			"icon":         "🛡",
			"tier_values":  [1, 2, 3],
			"desc_template": "Your attacks deal -%d damage to this enemy (min 1)."
		},
		{
			"type":         "thorns",
			"display_name": "Thorns",
			"icon":         "🌵",
			"tier_values":  [1, 2, 3],
			"desc_template": "Hitting this enemy deals %d damage back to you."
		},
		{
			"type":         "regeneration",
			"display_name": "Regeneration",
			"icon":         "💚",
			"tier_values":  [2, 3, 5],
			"desc_template": "This enemy heals %d HP each time it lands a hit on you."
		},
	]

# ─── Public API ───────────────────────────────────────────────────────────────

## Roll random modifiers for an enemy on the given floor.
## Returns an Array of modifier Dictionaries ready to attach to EnemyData.modifiers.
static func roll(floor_number: int) -> Array:
	var count := _roll_count(floor_number)
	if count == 0:
		return []
	var tier  := _get_tier(floor_number)
	var pool  := _get_pool()
	pool.shuffle()
	var result: Array = []
	for i in range(mini(count, pool.size())):
		var def: Dictionary = pool[i]
		var value: int = def.tier_values[tier]
		result.append({
			"type":         def.type,
			"display_name": def.display_name,
			"icon":         def.icon,
			"value":        value,
			"description":  def.desc_template % value,
		})
	return result

# ─── Internals ────────────────────────────────────────────────────────────────

## How many modifiers to roll, keyed by floor.
static func _roll_count(floor_number: int) -> int:
	if floor_number == 0:
		return 0          # First battle — no modifiers
	var r := randf()
	match floor_number:
		1:                # 30% chance of 1 modifier
			return 1 if r < 0.30 else 0
		2:                # 50% → 1,  20% → 2
			if   r < 0.20: return 2
			elif r < 0.70: return 1
			else:          return 0
		_:                # Floor 3+: always at least 1; 40%→1, 35%→2, 25%→3
			if   r < 0.25: return 3
			elif r < 0.60: return 2
			else:          return 1

## Which index into tier_values to use.
static func _get_tier(floor_number: int) -> int:
	if   floor_number <= 1: return 0   # weak
	elif floor_number <= 3: return 1   # moderate
	else:                   return 2   # strong
