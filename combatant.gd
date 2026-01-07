extends Node2D
class_name Combatant

var combatant_name = ""
var stats = {}
var abilities = []
var is_dead = false

func take_damage(amount):
	var was_alive = not is_dead
	var actual_damage = min(amount, stats["Health"])  # Track actual damage dealt (not overflow)
	stats["Health"] = clamp(stats["Health"] - amount, 0, stats["MaxHealth"])
	if stats["Health"] == 0:
		is_dead = true
	# Return dictionary with death status and actual damage
	return {"died": was_alive and is_dead, "actual_damage": actual_damage}

func choose_ability():
	return abilities[randi() % abilities.size()]

func choose_hit_zone():
	return randi() % 11
