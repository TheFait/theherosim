extends Node

## Manages hero and ability experience and leveling
## This is an autoload singleton - access via ExperienceManager global

const ABILITY_LEVEL_BASE_EXP = 10  # Casts needed for level 1 -> 2
const ABILITY_LEVEL_EXP_MULTIPLIER = 1.25  # 25% more casts each level

func _ready():
	# Connect to combat events
	EventBus.combatant_died.connect(_on_combatant_died)
	EventBus.ability_used.connect(_on_ability_used)

func _on_combatant_died(deceased, killer):
	"""Award experience to the hero who killed a monster"""
	# Only award exp if the deceased is a monster and there's a hero killer
	if not CombatantCache.is_monster(deceased):
		return

	# Only award if the killer is a hero (not null for poison deaths)
	if killer == null or not CombatantCache.is_hero(killer):
		return

	var exp_gained = deceased.stats.get("EXP", 0)
	if exp_gained == 0:
		return

	# Award to the killing hero only
	award_hero_exp(killer, exp_gained)

func _on_ability_used(user, ability: Dictionary, targets: Array):
	"""Grant ability experience when a hero uses an ability"""
	# Only grant exp to heroes
	if not CombatantCache.is_hero(user):
		return

	grant_ability_exp(user, ability["name"])

func award_hero_exp(hero, amount: int):
	"""Award experience points to a hero and handle level ups"""
	hero.stats["CurrentEXP"] += amount
	EventBus.combat_log_entry.emit("%s gains %d EXP!" % [hero.combatant_name, amount])

	# Check for level up
	while hero.stats["CurrentEXP"] >= hero.stats["EXPToNextLevel"]:
		hero.stats["CurrentEXP"] -= hero.stats["EXPToNextLevel"]
		hero.stats["Level"] += 1

		# Increase stats on level up
		hero.stats["MaxHealth"] = int(hero.stats["MaxHealth"] * 1.1)
		hero.stats["Power"] = int(hero.stats["Power"] * 1.05)
		hero.stats["Resilience"] = int(hero.stats["Resilience"] * 1.05)

		# Restore 10-25% health on level up
		var heal_percent = randf_range(0.15, 0.3)
		var heal_amount = int(hero.stats["MaxHealth"] * heal_percent)
		hero.stats["Health"] = min(hero.stats["Health"] + heal_amount, hero.stats["MaxHealth"])

		# Increase EXP requirement
		hero.stats["EXPToNextLevel"] = int(hero.stats["EXPToNextLevel"] * 1.5)

		# 10% chance to gain a random elemental affinity
		if randf() < 0.10:
			var random_element = ElementalSystem.get_random_element()
			if random_element != "" and not hero.elemental_affinities.has(random_element):
				hero.elemental_affinities.append(random_element)
				var element_text = ElementalSystem.get_colored_element_text(random_element)
				EventBus.combat_log_entry.emit("%s gained elemental affinity: %s" % [hero.combatant_name, element_text])

		EventBus.combat_log_entry.emit("[bgcolor=#FFD700][color=#000000]%s reached Level %d![/color][/bgcolor]" % [hero.combatant_name, hero.stats["Level"]])
		EventBus.level_up.emit(hero, hero.stats["Level"])

func grant_ability_exp(hero, ability_name: String):
	"""Grant experience to a specific ability and handle ability level ups"""
	var stats = StatsTracker.get_hero_stats(hero)
	if stats.is_empty():
		return

	# Initialize if not present
	if not stats["ability_exp"].has(ability_name):
		stats["ability_exp"][ability_name] = 0
	if not stats["ability_levels"].has(ability_name):
		stats["ability_levels"][ability_name] = 1

	# Grant 1 exp point
	stats["ability_exp"][ability_name] += 1

	# Check for ability level up
	var current_level = stats["ability_levels"][ability_name]
	var exp_required = get_ability_exp_required(current_level)

	if stats["ability_exp"][ability_name] >= exp_required:
		stats["ability_exp"][ability_name] -= exp_required
		stats["ability_levels"][ability_name] += 1
		EventBus.combat_log_entry.emit("%s's %s leveled up to Level %d!" % [hero.combatant_name, ability_name, stats["ability_levels"][ability_name]])
		EventBus.ability_level_up.emit(hero, ability_name, stats["ability_levels"][ability_name])

func get_ability_exp_required(level: int) -> int:
	"""Calculate experience required to level up an ability"""
	return int(ABILITY_LEVEL_BASE_EXP * pow(ABILITY_LEVEL_EXP_MULTIPLIER, level - 1))
