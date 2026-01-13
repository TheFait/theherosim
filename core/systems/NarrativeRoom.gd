extends Node

## NarrativeRoom - Handles narrative situation logic
## Loads situations, selects random hero, applies outcomes

const DataLoader = preload("res://data/loaders/DataLoader.gd")

const SITUATIONS_PATH = "res://data/narrative_situations.json"

var situations_data = []

func _ready():
	load_data()

func load_data():
	situations_data = DataLoader.load_json(SITUATIONS_PATH)

## Get a random narrative situation
func get_random_situation() -> Dictionary:
	if situations_data.is_empty():
		push_error("NarrativeRoom: No situations loaded")
		return {}
	return situations_data[randi() % situations_data.size()]

## Select a random living hero
func select_random_hero(heroes: Array) -> Combatant:
	var living_heroes = []
	for hero in heroes:
		if not hero.is_dead:
			living_heroes.append(hero)

	if living_heroes.is_empty():
		return null

	return living_heroes[randi() % living_heroes.size()]

## Apply outcomes to a hero
## Returns a dictionary with results for logging
func apply_outcomes(hero: Combatant, situation: Dictionary) -> Dictionary:
	var results = {
		"hero": hero,
		"situation_title": situation.get("title", "Unknown"),
		"text": situation.get("text", "").replace("{hero}", hero.combatant_name),
		"outcome_log": []
	}

	for outcome in situation.get("outcomes", []):
		var outcome_type = outcome.get("type", "")

		match outcome_type:
			"heal":
				var heal_amount = outcome.get("value", 0)
				var old_health = hero.stats["Health"]
				hero.stats["Health"] = min(hero.stats["Health"] + heal_amount, hero.stats.get("MaxHealth", 999))
				var actual_heal = hero.stats["Health"] - old_health
				results["outcome_log"].append("Healed %d HP" % actual_heal)
				EventBus.combat_log_entry.emit("%s was healed for %d HP" % [hero.combatant_name, actual_heal])

			"damage":
				var damage_amount = outcome.get("value", 0)
				var result = hero.take_damage(damage_amount)
				results["outcome_log"].append("Took %d damage" % result["actual_damage"])
				EventBus.combat_log_entry.emit("%s took %d damage" % [hero.combatant_name, result["actual_damage"]])
				if result["died"]:
					results["outcome_log"].append("DIED!")
					EventBus.combat_log_entry.emit("[bgcolor=#8B0000][color=#FFFFFF]%s has died![/color][/bgcolor]" % hero.combatant_name)

			"item":
				var item_pools = outcome.get("item_pool", [])
				for pool_id in item_pools:
					var item_ids = ItemManager.roll_treasure_package(pool_id)
					for item_id in item_ids:
						var item = ItemManager.create_item(item_id)
						var equip_result = hero.equip_item(item, ItemManager.get_player_item_slots())
						var item_name = ItemManager.get_colored_item_name(item)
						results["outcome_log"].append("Received %s" % item["name"])
						EventBus.combat_log_entry.emit("%s received %s" % [hero.combatant_name, item_name])

			"ability_exp":
				var exp_amount = outcome.get("value", 0)
				if not hero.abilities.is_empty():
					var random_ability = hero.abilities[randi() % hero.abilities.size()]
					for i in exp_amount:
						ExperienceManager.grant_ability_exp(hero, random_ability["name"])
					results["outcome_log"].append("Gained %d exp for %s" % [exp_amount, random_ability["name"]])

			"swap_ability":
				if hero.abilities.size() > 0:
					# Remove a random ability and add a new random one
					var removed_ability = hero.abilities[randi() % hero.abilities.size()]
					hero.abilities.erase(removed_ability)

					# Get a random ability from the database
					var all_abilities = AbilityDatabase.get_all_abilities()
					if not all_abilities.is_empty():
						var new_ability = all_abilities[randi() % all_abilities.size()]
						hero.abilities.append(new_ability)

						# Initialize stats for new ability
						var hero_stats = StatsTracker.get_hero_stats(hero)
						if not hero_stats.is_empty():
							hero_stats["ability_levels"][new_ability["name"]] = 1
							hero_stats["ability_exp"][new_ability["name"]] = 0

						results["outcome_log"].append("Swapped %s for %s" % [removed_ability["name"], new_ability["name"]])
						EventBus.combat_log_entry.emit("%s forgot %s and learned %s!" % [hero.combatant_name, removed_ability["name"], new_ability["name"]])

			"ability_level_up":
				if not hero.abilities.is_empty():
					var random_ability = hero.abilities[randi() % hero.abilities.size()]
					var hero_stats = StatsTracker.get_hero_stats(hero)
					if not hero_stats.is_empty():
						hero_stats["ability_levels"][random_ability["name"]] += 1
						results["outcome_log"].append("%s leveled up to %d!" % [random_ability["name"], hero_stats["ability_levels"][random_ability["name"]]])
						EventBus.combat_log_entry.emit("%s's %s instantly leveled up!" % [hero.combatant_name, random_ability["name"]])

	return results
