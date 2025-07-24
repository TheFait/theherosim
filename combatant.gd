extends Node2D
class_name Combatant

var combatant_name = ""
var stats = {}
var abilities = []
var is_dead = false

func take_damage(amount):
	stats["Health"] = max(0, stats["Health"] - amount)
	if stats["Health"] == 0:
		is_dead = true

func choose_ability():
	return abilities[randi() % abilities.size()]
