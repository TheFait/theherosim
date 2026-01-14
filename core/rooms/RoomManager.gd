extends Node

## RoomManager - Handles room generation, loot rooms, and narrative rooms
## Extracted from main.gd to separate room-related logic

# Loot room chest voting
var loot_room_selected_chest = -1
var loot_room_chest_votes = [0, 0, 0]

# Callbacks (set by GameController)
var on_log_event: Callable
var on_give_item_to_hero: Callable
var on_update_combatants_display: Callable

## Set the chest that will be opened (for Twitch voting integration)
func set_loot_chest_selection(chest_number: int):
	"""Set which chest will be opened. Call this from Twitch integration."""
	if chest_number >= 0 and chest_number < 3:
		loot_room_selected_chest = chest_number
		if on_log_event.is_valid():
			on_log_event.call("Chest %d has been selected!" % (chest_number + 1))

## Vote for a chest (for Twitch voting integration)
func vote_for_loot_chest(chest_number: int):
	"""Add a vote for a chest. Call this from Twitch chat integration."""
	if chest_number >= 0 and chest_number < 3:
		loot_room_chest_votes[chest_number] += 1

## Process loot room (returns loot results for each hero)
func process_loot_room(heroes: Array) -> Dictionary:
	"""
	Process loot room logic and return results.
	Returns: {"heroes_results": Array of {hero, items, resurrected, etc.}}
	"""
	var item_chance = ItemManager.get_loot_room_item_chance()
	var resurrection_chance = ItemManager.get_loot_room_resurrection_chance()
	var resurrection_health_percent = ItemManager.get_loot_room_resurrection_health_percent()

	var results = []

	for hero in heroes:
		var hero_result = {
			"hero": hero,
			"was_dead": hero.is_dead,
			"resurrected": false,
			"items": [],
			"messages": []
		}

		if hero.is_dead:
			# Dead heroes have a chance to be resurrected
			if randf() < resurrection_chance:
				var max_health = hero.base_stats["MaxHealth"]
				var resurrection_health = int(max_health * resurrection_health_percent)
				hero.stats["Health"] = resurrection_health
				hero.is_dead = false
				hero_result["resurrected"] = true
				hero_result["resurrection_health"] = resurrection_health
				hero_result["messages"].append("RESURRECTED with %d HP!" % resurrection_health)
				if on_log_event.is_valid():
					on_log_event.call("%s was resurrected with %d HP!" % [hero.combatant_name, resurrection_health])
			else:
				hero_result["messages"].append("Remains dead.")
				if on_log_event.is_valid():
					on_log_event.call("%s remains dead." % hero.combatant_name)
		else:
			# Living heroes roll for loot
			if randf() < item_chance:
				var item_ids = ItemManager.roll_treasure_package("common_chest")
				if not item_ids.is_empty():
					for item_id in item_ids:
						var item = ItemManager.create_item(item_id)
						if on_give_item_to_hero.is_valid():
							on_give_item_to_hero.call(hero, item)

						hero_result["items"].append(item)
						var message = ItemManager.get_item_found_message(hero.combatant_name, item)
						hero_result["messages"].append(message)
						if on_log_event.is_valid():
							on_log_event.call(message)
				else:
					var message = ItemManager.get_item_not_found_message(hero.combatant_name)
					hero_result["messages"].append(message)
					if on_log_event.is_valid():
						on_log_event.call(message)
			else:
				var message = ItemManager.get_item_not_found_message(hero.combatant_name)
				hero_result["messages"].append(message)
				if on_log_event.is_valid():
					on_log_event.call(message)

		results.append(hero_result)

	return {"heroes_results": results}

## Process narrative room event
func process_narrative_room(heroes: Array) -> Dictionary:
	"""
	Process narrative room and return results.
	Returns: {situation, chosen_hero, outcome_results}
	"""
	# Get a random situation
	var situation = NarrativeRoom.get_random_situation()
	if situation.is_empty():
		if on_log_event.is_valid():
			on_log_event.call("No narrative situations available.")
		return {}

	# Select a random living hero
	var living_heroes = heroes.filter(func(h): return not h.is_dead)
	if living_heroes.is_empty():
		if on_log_event.is_valid():
			on_log_event.call("No living heroes to experience the narrative event.")
		return {}

	var chosen_hero = NarrativeRoom.select_random_hero(living_heroes)

	# Get situation text with hero name replaced
	var situation_text = situation["text"].replace("{hero}", chosen_hero.combatant_name)
	if on_log_event.is_valid():
		on_log_event.call(situation_text)

	# Apply outcomes and get results
	var outcome_results = NarrativeRoom.apply_outcomes(chosen_hero, situation)

	# Log outcome results
	if on_log_event.is_valid():
		for result_text in outcome_results:
			on_log_event.call(result_text)

	# Trigger UI update
	if on_update_combatants_display.is_valid():
		on_update_combatants_display.call()

	return {
		"situation": situation,
		"chosen_hero": chosen_hero,
		"situation_text": situation_text,
		"outcome_results": outcome_results
	}
