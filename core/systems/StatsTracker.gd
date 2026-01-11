extends Node

## Event-based statistics tracking for heroes
## This is an autoload singleton - access via StatsTracker global
## Listens to combat events and maintains hero statistics

# Hero statistics tracking
var hero_stats = {}

func _ready():
	# Connect to combat events
	EventBus.combatant_damaged.connect(_on_combatant_damaged)
	EventBus.combatant_healed.connect(_on_combatant_healed)
	EventBus.ability_used.connect(_on_ability_used)

func initialize_hero(hero):
	"""Initialize statistics tracking for a hero"""
	hero_stats[hero] = {
		"total_damage_dealt": 0.0,
		"total_healing_done": 0.0,
		"total_damage_taken": 0.0,
		"ability_usage": {},
		"ability_levels": {},
		"ability_exp": {}
	}

	# Initialize ability levels for each ability the hero has
	for ability in hero.abilities:
		var ability_name = ability["name"]
		hero_stats[hero]["ability_levels"][ability_name] = 1
		hero_stats[hero]["ability_exp"][ability_name] = 0

func clear_stats():
	"""Clear all statistics (called on restart)"""
	hero_stats.clear()

func get_hero_stats(hero) -> Dictionary:
	"""Get statistics for a specific hero"""
	return hero_stats.get(hero, {})

func _on_combatant_damaged(attacker, target, damage: float, actual_damage: float):
	"""Track damage dealt and damage taken"""
	# Track damage dealt by heroes
	if CombatantCache.is_hero(attacker) and hero_stats.has(attacker):
		hero_stats[attacker]["total_damage_dealt"] += actual_damage

	# Track damage taken by heroes
	if CombatantCache.is_hero(target) and hero_stats.has(target):
		hero_stats[target]["total_damage_taken"] += actual_damage

func _on_combatant_healed(healer, target, amount: float):
	"""Track healing done"""
	# Track healing done by heroes
	if CombatantCache.is_hero(healer) and hero_stats.has(healer):
		hero_stats[healer]["total_healing_done"] += amount

func _on_ability_used(user, ability: Dictionary, targets: Array):
	"""Track ability usage and statistics"""
	# Only track for heroes
	if not CombatantCache.is_hero(user) or not hero_stats.has(user):
		return

	var stats = hero_stats[user]
	var ability_name = ability["name"]

	# Increment usage counter
	if not stats["ability_usage"].has(ability_name):
		stats["ability_usage"][ability_name] = 0
	stats["ability_usage"][ability_name] += 1

func track_damage_dealt(hero, damage: float):
	"""Manually track damage dealt by a hero"""
	if hero_stats.has(hero):
		hero_stats[hero]["total_damage_dealt"] += damage

func track_healing_done(hero, healing: float):
	"""Manually track healing done by a hero"""
	if hero_stats.has(hero):
		hero_stats[hero]["total_healing_done"] += healing

func generate_tooltip(hero) -> String:
	"""Generate tooltip text for a hero showing current stats and abilities"""
	if not hero_stats.has(hero):
		return "No stats available"

	var stats = hero_stats[hero]
	var tooltip = ""

	# Current statistics
	tooltip += "=== Statistics ===\n"
	tooltip += "Damage Dealt: %d\n" % int(stats["total_damage_dealt"])
	tooltip += "Healing Done: %d\n" % int(stats["total_healing_done"])
	tooltip += "Damage Taken: %d\n" % int(stats["total_damage_taken"])
	tooltip += "\n=== Abilities ===\n"

	# Abilities and usage
	for ability in hero.abilities:
		var ability_name = ability["name"]
		var usage_count = stats["ability_usage"].get(ability_name, 0)
		var ability_level = stats["ability_levels"].get(ability_name, 1)
		tooltip += "%s (Lv. %d): %d uses\n" % [ability_name, ability_level, usage_count]

	return tooltip

func get_most_used_ability(hero) -> String:
	"""Get the name of the hero's most used ability"""
	if not hero_stats.has(hero):
		return "None"

	var stats = hero_stats[hero]
	var max_uses = 0
	var most_used = "None"

	for ability_name in stats["ability_usage"]:
		var uses = stats["ability_usage"][ability_name]
		if uses > max_uses:
			max_uses = uses
			most_used = ability_name

	return most_used
