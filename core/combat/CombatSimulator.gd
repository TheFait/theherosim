extends Node

## CombatSimulator - Handles all combat logic and simulation
## Extracted from main.gd to separate concerns

const HIT_ZONES = {
	0: {"name": "Head", "difficulty": 1.3},
	1: {"name": "Neck", "difficulty": 1.4},
	2: {"name": "Left Shoulder", "difficulty": 1.1},
	3: {"name": "Right Shoulder", "difficulty": 1.1},
	4: {"name": "Chest", "difficulty": 0.9},
	5: {"name": "Left Mid Body", "difficulty": 1.0},
	6: {"name": "Right Mid Body", "difficulty": 1.0},
	7: {"name": "Lower Body", "difficulty": 1.1},
	8: {"name": "Left Lower Body", "difficulty": 1.2},
	9: {"name": "Right Lower Body", "difficulty": 1.2},
	10: {"name": "Movement", "difficulty": 1.3}
}

# Combat state
var heroes: Array = []
var monsters: Array = []
var all_combatants: Array = []
var current_turn_combatant = null
var last_ability_targets: Array = []

# Callbacks (set by GameController)
var on_combatant_display_update: Callable
var on_log_event: Callable
var on_give_item_to_hero: Callable
var on_colorize_combatant_name: Callable  # For colorizing names in logs

## Set combat participants
func set_combatants(hero_list: Array, monster_list: Array):
	heroes = hero_list
	monsters = monster_list
	all_combatants = heroes + monsters

## Check accuracy for hit zone targeting
func check_accuracy(combatant, intended_zone: int) -> Dictionary:
	var accuracy_stat = combatant.stats.get("Accuracy", 50)
	var accuracy_roll = randi() % 100 + 1
	var success = accuracy_roll <= accuracy_stat

	if success:
		return {"success": true, "zone": intended_zone}
	else:
		var miss_margin = accuracy_roll - accuracy_stat
		var zone_shift = calculate_zone_shift(miss_margin)
		var new_zone = shift_hit_zone(intended_zone, zone_shift)
		return {"success": false, "zone": new_zone}

## Calculate how many zones to shift on missed accuracy
func calculate_zone_shift(miss_margin: int) -> int:
	if miss_margin <= 10:
		return randi() % 2 + 1
	elif miss_margin <= 25:
		return randi() % 3 + 2
	else:
		return randi() % 4 + 3

## Shift hit zone by amount in random direction
func shift_hit_zone(original_zone: int, shift_amount: int) -> int:
	var direction = 1 if randi() % 2 == 0 else -1
	var new_zone = (original_zone + (shift_amount * direction)) % HIT_ZONES.size()
	if new_zone < 0:
		new_zone += HIT_ZONES.size()
	return new_zone

## Check if attack hits target at zone
func check_hit(target, hit_zone: int) -> bool:
	var base_hit_chance = 100 - target.stats["Evasion"]
	var zone_difficulty = HIT_ZONES[hit_zone]["difficulty"]
	var final_hit_chance = (base_hit_chance / zone_difficulty) + 15

	var hit_roll = randi() % 100 + 1
	return hit_roll <= final_hit_chance

## Apply elemental damage multipliers
func apply_elemental_damage(base_damage: float, user, target, ability: Dictionary) -> Dictionary:
	var element = ability.get("element", "")
	if element == "":
		return {"damage": base_damage, "text": ""}

	var result = ElementalSystem.calculate_damage(base_damage, element, user, target)
	return {
		"damage": result["damage"],
		"text": result["multiplier_text"]
	}

## Apply status effect to target
func apply_status_effect_to_target(target, effect_type: String, params: Dictionary = {}):
	var effect = StatusEffects.create_effect(effect_type, params)
	if effect:
		target.apply_status_effect(effect)
		if on_log_event.is_valid():
			on_log_event.call("%s is affected by %s!" % [target.combatant_name, effect.get_display_text()])

## Helper to apply damage/healing to single target (eliminates duplication)
func apply_ability_to_target(user, ability: Dictionary, target, hit_zone: int = -1) -> bool:
	"""
	Apply ability damage/healing to a single target.
	Returns true if the target died from this attack.
	"""
	var min_dmg = ability.get("min_damage", 0)
	var max_dmg = ability.get("max_damage", 0)
	var number_attacks = ability.get("number_attacks", 1)

	# Roll damage multiple times based on number_attacks
	var total_damage = 0.0
	var damage_rolls = []
	for i in number_attacks:
		var dmg = randf_range(min_dmg, max_dmg)
		total_damage += dmg
		var is_max_damage = abs(dmg - max_dmg) < 0.01
		var damage_text = str(int(abs(dmg)))
		if is_max_damage:
			damage_text = "[b][i]" + damage_text + "[/i][/b]"
		damage_rolls.append(damage_text)

	# Apply elemental multipliers
	var elemental_result = apply_elemental_damage(total_damage, user, target, ability)
	total_damage = elemental_result["damage"]
	var elemental_text = elemental_result["text"]

	# Apply damage to target
	var result = target.take_damage(total_damage)
	var just_died = result["died"]
	var actual_damage = result["actual_damage"]
	var damage_type = "health" if total_damage < 0 else "damage"

	# Emit events for damage/healing tracking
	if total_damage > 0:
		EventBus.combatant_damaged.emit(user, target, total_damage, actual_damage)
	else:
		EventBus.combatant_healed.emit(user, target, abs(actual_damage))

	# Format damage rolls display
	var damage_display = ""
	if number_attacks == 1:
		damage_display = "%s %s" % [damage_rolls[0], damage_type]
	else:
		damage_display = "(%s) = %d %s" % [" + ".join(damage_rolls), int(abs(total_damage)), damage_type]

	# Log action
	if on_log_event.is_valid():
		var user_name = _colorize_combatant_name(user)
		var target_name = _colorize_combatant_name(target)

		var action = ""
		if hit_zone >= 0:
			action = "%s uses %s on %s hitting zone %d (%s) for %s%s." % [
				user_name, ability["name"], target_name, hit_zone, HIT_ZONES[hit_zone]["name"], damage_display, elemental_text
			]
		else:
			action = "%s uses %s on %s for %s%s." % [
				user_name, ability["name"], target_name, damage_display, elemental_text
			]
		on_log_event.call(action)

		# Log death with red background and emit death event
		if just_died:
			on_log_event.call("[bgcolor=#8B0000][color=#FFFFFF]%s has died![/color][/bgcolor]" % _colorize_combatant_name(target))
			EventBus.combatant_died.emit(target, user)

	# Apply status effect if the ability has one
	if ability.has("status_effect") and not target.is_dead:
		var status_data = ability["status_effect"]
		apply_status_effect_to_target(target, status_data["type"], status_data)

	return just_died

## Apply ability to targets with accuracy checks
func apply_ability(user, ability: Dictionary, targets: Array):
	last_ability_targets = targets
	var accuracy_mode = ability.get("accuracy_mode", "all")
	var number_attacks = ability.get("number_attacks", 1)

	# Check for Rain weather slip effect
	if WeatherManager.should_slip_on_attack():
		if on_log_event.is_valid():
			var user_name = _colorize_combatant_name(user)
			on_log_event.call("%s slipped in the rain and missed their turn!" % user_name)
		return

	if accuracy_mode == "none":
		# No accuracy check - all targets get hit
		EventBus.ability_used.emit(user, ability, targets)
		for target in targets:
			if target.is_dead:
				continue
			apply_ability_to_target(user, ability, target)

	elif accuracy_mode == "one":
		# One accuracy check for all targets - all hit or all miss
		var intended_zone = user.choose_hit_zone()
		var user_name = _colorize_combatant_name(user)
		if on_log_event.is_valid():
			on_log_event.call("%s attempts to use %s on hit zone %d (%s)" % [user_name, ability["name"], intended_zone, HIT_ZONES[intended_zone]["name"]])

		var accuracy_result = check_accuracy(user, intended_zone)
		var final_zone = accuracy_result["zone"]

		if not accuracy_result["success"] and on_log_event.is_valid():
			on_log_event.call("%s fails the accuracy check, new hit zone is %d (%s)" % [user_name, final_zone, HIT_ZONES[final_zone]["name"]])

		var hit_success = check_hit(targets[0], final_zone)

		if not hit_success:
			if on_log_event.is_valid():
				on_log_event.call("%s misses all targets" % user_name)
		else:
			EventBus.ability_used.emit(user, ability, targets)
			for target in targets:
				if target.is_dead:
					continue
				apply_ability_to_target(user, ability, target, final_zone)

	else:  # accuracy_mode == "all"
		# Emit ability usage event once for the whole attack
		EventBus.ability_used.emit(user, ability, targets)

		# Separate accuracy check for each target and each attack
		for target in targets:
			if target.is_dead:
				continue

			var user_name = _colorize_combatant_name(user)
			var target_name = _colorize_combatant_name(target)
			var min_dmg = ability.get("min_damage", 0)
			var max_dmg = ability.get("max_damage", 0)

			# Roll damage multiple times with accuracy check for each
			var total_damage = 0.0
			var damage_rolls = []
			var hit_count = 0

			for i in number_attacks:
				var intended_zone = user.choose_hit_zone()
				if on_log_event.is_valid():
					on_log_event.call("%s attempts to use %s on %s at hit zone %d (%s)" % [user_name, ability["name"], target_name, intended_zone, HIT_ZONES[intended_zone]["name"]])

				var accuracy_result = check_accuracy(user, intended_zone)
				var final_zone = accuracy_result["zone"]

				if not accuracy_result["success"] and on_log_event.is_valid():
					on_log_event.call("%s fails the accuracy check, new hit zone is %d (%s)" % [user_name, final_zone, HIT_ZONES[final_zone]["name"]])

				var hit_success = check_hit(target, final_zone)

				if not hit_success:
					if on_log_event.is_valid():
						on_log_event.call("%s misses %s" % [user_name, target_name])
					continue

				# This attack hit - roll damage
				var dmg = randf_range(min_dmg, max_dmg)
				total_damage += dmg
				hit_count += 1
				var is_max_damage = abs(dmg - max_dmg) < 0.01
				var damage_text = str(int(abs(dmg)))
				if is_max_damage:
					damage_text = "[b][i]" + damage_text + "[/i][/b]"
				damage_rolls.append(damage_text)

				if on_log_event.is_valid():
					on_log_event.call("%s hits %s at zone %d (%s)" % [user_name, target_name, final_zone, HIT_ZONES[final_zone]["name"]])

			# Apply total damage if any attacks hit
			if hit_count > 0:
				var elemental_result = apply_elemental_damage(total_damage, user, target, ability)
				total_damage = elemental_result["damage"]
				var elemental_text = elemental_result["text"]

				var result = target.take_damage(total_damage)
				var just_died = result["died"]
				var actual_damage = result["actual_damage"]
				var damage_type = "health" if total_damage < 0 else "damage"

				# Emit events for damage/healing tracking
				if total_damage > 0:
					EventBus.combatant_damaged.emit(user, target, total_damage, actual_damage)
				else:
					EventBus.combatant_healed.emit(user, target, abs(actual_damage))

				# Format damage rolls display
				var damage_display = ""
				if hit_count == 1:
					damage_display = "%s %s" % [damage_rolls[0], damage_type]
				else:
					damage_display = "(%s) = %d %s" % [" + ".join(damage_rolls), int(abs(total_damage)), damage_type]

				if on_log_event.is_valid():
					on_log_event.call("Total damage dealt: %s%s" % [damage_display, elemental_text])

				# Log death with red background and emit death event
				if just_died:
					if on_log_event.is_valid():
						on_log_event.call("[bgcolor=#8B0000][color=#FFFFFF]%s has died![/color][/bgcolor]" % _colorize_combatant_name(target))
					EventBus.combatant_died.emit(target, user)

				# Apply status effect if the ability has one (only if at least one attack hit)
				if ability.has("status_effect") and not target.is_dead:
					var status_data = ability["status_effect"]
					apply_status_effect_to_target(target, status_data["type"], status_data)

	# Trigger UI update after ability application
	if on_combatant_display_update.is_valid():
		on_combatant_display_update.call()

## Choose targets for ability
func choose_target(combatant, ability: Dictionary) -> Array:
	var num_targets = ability.get("num_targets", 1)
	var target_type = ability.get("target", "enemy")

	# Use cached alive combatants
	var alive_heroes = CombatantCache.get_alive_combatants().filter(func(c): return heroes.has(c))
	var alive_monsters = CombatantCache.get_alive_combatants().filter(func(c): return monsters.has(c))

	var potential_targets = []
	if target_type == "enemy":
		potential_targets = alive_monsters if heroes.has(combatant) else alive_heroes
	elif target_type == "ally":
		potential_targets = alive_heroes if heroes.has(combatant) else alive_monsters
	elif target_type == "self":
		return [combatant]
	elif target_type == "all_enemies":
		potential_targets = alive_monsters if heroes.has(combatant) else alive_heroes
		return potential_targets  # Return all enemies
	elif target_type == "all_allies":
		potential_targets = alive_heroes if heroes.has(combatant) else alive_monsters
		return potential_targets  # Return all allies

	if potential_targets.is_empty():
		return []

	# Select num_targets random targets
	var targets = []
	var available = potential_targets.duplicate()
	for i in range(min(num_targets, available.size())):
		var target = available[randi() % available.size()]
		targets.append(target)
		available.erase(target)

	return targets

## Check if battle is over
func is_battle_over() -> bool:
	return CombatantCache.are_all_dead(heroes) or CombatantCache.are_all_dead(monsters)

## Get alive combatants
func get_alive_combatants() -> Array:
	return CombatantCache.get_alive_combatants()

## Colorize combatant name for logs
func _colorize_combatant_name(combatant) -> String:
	if on_colorize_combatant_name.is_valid():
		return on_colorize_combatant_name.call(combatant)
	# Fallback
	return combatant.combatant_name if combatant else ""
