extends Node2D
class_name Combatant

var combatant_name = ""
var stats = {}
var abilities = []
var is_dead = false
var status_effects = []  # Array of StatusEffect objects

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
	return abilities[randi() % abilities.size()]

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
