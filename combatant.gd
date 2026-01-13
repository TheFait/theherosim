extends Node2D
class_name Combatant

var combatant_name = ""
var stats = {}
var base_stats = {}  # Stats without item bonuses
var abilities = []
var is_dead = false
var status_effects = []  # Array of StatusEffect objects
var is_shiny = false  # 1% chance for monsters to be shiny (5x EXP)
var equipped_items = []  # Array of item instances (Dictionary)
var item_effects = []  # Array of active item effect names
var element = ""  # Monster's elemental type (fire, water, ice, etc.)
var elemental_affinities = []  # Hero's elemental affinities (Array of element IDs)

func take_damage(amount):
	var was_alive = not is_dead

	# Apply status effect modifiers (e.g., Shield)
	var modified_damage = amount
	for effect in status_effects:
		modified_damage = effect.on_damage_taken(self, modified_damage)

	var actual_damage = min(modified_damage, stats["Health"])  # Track actual damage dealt (not overflow)
	stats["Health"] = clamp(stats["Health"] - modified_damage, 0, stats["MaxHealth"])
	if stats["Health"] == 0:
		is_dead = true
	# Return dictionary with death status and actual damage
	return {"died": was_alive and is_dead, "actual_damage": actual_damage}

func choose_ability():
	# Check if this is a hero with ability levels tracked
	if CombatantCache.is_hero(self):
		var hero_stats = StatsTracker.get_hero_stats(self)
		if not hero_stats.is_empty():
			# 60% chance to use highest level ability
			if randf() < 0.6:
				return _choose_highest_level_ability(hero_stats)
			# 40% chance to use any ability (including highest)

	# Default: random ability (used by monsters and 40% of hero picks)
	return abilities[randi() % abilities.size()]

func _choose_highest_level_ability(hero_stats: Dictionary):
	"""Choose randomly from the abilities with the highest level"""
	var max_level = 0
	var highest_abilities = []

	# Find the maximum level
	for ability in abilities:
		var ability_name = ability["name"]
		var level = hero_stats["ability_levels"].get(ability_name, 1)
		if level > max_level:
			max_level = level

	# Collect all abilities at max level
	for ability in abilities:
		var ability_name = ability["name"]
		var level = hero_stats["ability_levels"].get(ability_name, 1)
		if level == max_level:
			highest_abilities.append(ability)

	# Return random choice from highest level abilities
	if highest_abilities.is_empty():
		return abilities[randi() % abilities.size()]
	return highest_abilities[randi() % highest_abilities.size()]

func choose_hit_zone():
	return randi() % 11

func apply_status_effect(effect):
	# Check if effect already exists (for stacking or refreshing)
	for existing_effect in status_effects:
		if existing_effect.effect_name == effect.effect_name:
			# Refresh duration to the longer of the two
			existing_effect.duration = max(existing_effect.duration, effect.duration)
			# Add stacks if applicable
			if "stacks" in existing_effect:
				existing_effect.stacks += effect.stacks
			return

	# Add new effect
	status_effects.append(effect)
	effect.on_apply(self)

func process_status_effects_turn_start():
	# Process all status effects at turn start
	for effect in status_effects:
		effect.on_turn_start(self)

	# Remove expired effects
	status_effects = status_effects.filter(func(e): return !e.is_expired())

func process_status_effects_turn_end():
	# Process all status effects at turn end
	for effect in status_effects:
		effect.on_turn_end(self)

	# Remove expired effects
	status_effects = status_effects.filter(func(e): return !e.is_expired())

func has_status_effect(effect_name: String) -> bool:
	for effect in status_effects:
		if effect.effect_name == effect_name:
			return true
	return false

func is_stunned() -> bool:
	for effect in status_effects:
		if effect.effect_name == "Stun":
			if effect.should_skip_turn():
				return true
	return false

## Add an item to this combatant's equipment
## If slots are full, randomly removes an item first
## max_slots parameter should be passed from ItemManager
func equip_item(item: Dictionary, max_slots: int) -> Dictionary:
	var removed_item = null

	# If slots are full, remove a random item
	if equipped_items.size() >= max_slots:
		var remove_index = randi() % equipped_items.size()
		removed_item = equipped_items[remove_index]
		equipped_items.remove_at(remove_index)

	# Add new item
	equipped_items.append(item)

	# Add item effect if present
	if item.has("effect") and item["effect"] != null and not item_effects.has(item["effect"]):
		item_effects.append(item["effect"])

	# Recalculate stats
	recalculate_stats()

	# Return info about what happened
	return {"added": item, "removed": removed_item}

## Recalculate stats by applying base stats + all item bonuses
func recalculate_stats():
	# Start with base stats
	stats = base_stats.duplicate(true)

	# Reset elemental affinities (will be rebuilt from items)
	elemental_affinities.clear()

	# Apply item bonuses
	for item in equipped_items:
		# Apply stat bonuses
		if item.has("stats"):
			for stat_name in item["stats"].keys():
				var bonus = item["stats"][stat_name]
				if stats.has(stat_name):
					stats[stat_name] += bonus
				else:
					stats[stat_name] = bonus

		# Apply elemental affinity if present
		if item.has("elemental_affinity") and item["elemental_affinity"] != null:
			var affinity = item["elemental_affinity"]
			if not elemental_affinities.has(affinity):
				elemental_affinities.append(affinity)

	# Ensure Health doesn't exceed MaxHealth after recalculation
	if stats.has("Health") and stats.has("MaxHealth"):
		stats["Health"] = min(stats["Health"], stats["MaxHealth"])

## Remove all items from this combatant
func clear_items():
	equipped_items.clear()
	item_effects.clear()
	recalculate_stats()
