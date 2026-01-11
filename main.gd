extends Node

const ABILITY_PATH = "res://data/abilities.json"
const MONSTER_ABILITY_PATH = "res://data/monster_abilities.json"
const MONSTER_FAMILY_PATH = "res://data/monster_families.json"
const TICK_SPEED = 1

# Hit zones 0-10 with different difficulty multipliers
# Higher multiplier = harder to hit (like vital spots)
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

# Monster family colors for log display
const MONSTER_COLORS = {
	"Goblin": "#90EE90",      # Light green
	"Orc": "#CD5C5C",         # Indian red
	"Wolf": "#87CEEB",        # Sky blue
	"Dragon": "#9370DB"       # Medium purple
}

var heroes = []
var monsters = []
var all_combatants = []
# abilities, monster_abilities, monster_families now handled by AbilityDatabase singleton
var family_probabilities = []  # Probability table for current floor
var rank_probabilities = []    # Probability table for ranks
var roundsWon = 0
var floorsCleared = 0
var currentFloor = ""
var is_paused = false
var current_turn_combatant = null
var last_ability_targets = []

@onready var log_box = $LogBoxPanel/LogBox
@onready var start_button = $StartButton
@onready var pause_button = $PauseButton
@onready var floor_label = $FloorLabel
@onready var room_label = $RoomLabel
@onready var combatants_list = $CombatantsPanel/ScrollContainer/CombatantsList
@onready var game_over_popup = $GameOverPopup
@onready var game_over_stats_container = $GameOverPopup/VBoxContainer/ScrollContainer/StatsContainer
@onready var game_over_floor_room_label = $GameOverPopup/VBoxContainer/FloorRoomLabel
@onready var game_over_restart_button = $GameOverPopup/VBoxContainer/RestartButton
@onready var hero_preview_popup = $HeroPreviewPopup
@onready var hero_preview_container = $HeroPreviewPopup/VBoxContainer/ScrollContainer/HeroesContainer
@onready var hero_preview_countdown = $HeroPreviewPopup/VBoxContainer/CountdownLabel
@onready var floor_cleared_popup = $FloorClearedPopup
@onready var floor_cleared_container = $FloorClearedPopup/VBoxContainer/ScrollContainer/HeroesContainer
@onready var floor_cleared_countdown = $FloorClearedPopup/VBoxContainer/CountdownLabel
@onready var floor_cleared_floor_label = $FloorClearedPopup/VBoxContainer/FloorLabel

func _ready():
	start_button.pressed.connect(on_start_pressed)
	pause_button.pressed.connect(on_pause_pressed)
	game_over_restart_button.pressed.connect(on_restart_pressed)
	pause_button.disabled = true

	# Connect EventBus signals to UI handlers
	EventBus.combat_log_entry.connect(log_event)

	log_event("Ready to simulate combat.")

func on_start_pressed():
	start_button.disabled = true
	pause_button.disabled = false
	is_paused = false
	pause_button.text = "Pause"
	# Data now loaded by AbilityDatabase singleton
	generate_new_floor()
	generate_combatants()

	# Show hero preview popup with countdown
	await show_hero_preview_popup()

	sort_by_agility()
	await simulate_battle()

func on_pause_pressed():
	is_paused = !is_paused
	if is_paused:
		pause_button.text = "Resume"
		log_event("--- Simulation Paused ---")
	else:
		pause_button.text = "Pause"
		log_event("--- Simulation Resumed ---")

func on_restart_pressed():
	game_over_popup.visible = false
	start_button.disabled = false
	pause_button.disabled = true

	# Reset state
	roundsWon = 0
	floorsCleared = 0
	heroes.clear()
	monsters.clear()
	all_combatants.clear()
	StatsTracker.clear_stats()

	# Clear UI
	update_combatants_display()
	floor_label.text = "Floor: --"
	room_label.text = "Room: --"

func log_event(text):
	log_box.append_text(text + "\n")
	log_box.scroll_to_line(log_box.get_line_count() - 1)

func colorize_monster_name(monster_name):
	# Extract the family name from the full monster name (e.g., "Chieftain Goblin" -> "Goblin")
	for family_name in MONSTER_COLORS.keys():
		if monster_name.contains(family_name):
			var color = MONSTER_COLORS[family_name]
			return "[color=%s]%s[/color]" % [color, monster_name]
	return monster_name  # No color if family not found

func colorize_combatant_name(combatant):
	# Colorize monsters, leave heroes as is
	if monsters.has(combatant):
		return colorize_monster_name(combatant.combatant_name)
	return combatant.combatant_name

func update_floor_room_display():
	floor_label.text = "Floor: %d" % (floorsCleared + 1)
	room_label.text = "Room: %d / %d" % [currentFloor.current_room + 1, currentFloor.num_rooms]

func generate_hero_tooltip(hero):
	# Use StatsTracker to generate tooltip
	return StatsTracker.generate_tooltip(hero)

func update_combatants_display():
	# Clear existing children
	for child in combatants_list.get_children():
		child.queue_free()

	# Add Heroes header
	var heroes_label = Label.new()
	heroes_label.text = "HEROES"
	heroes_label.add_theme_font_size_override("font_size", 16)
	combatants_list.add_child(heroes_label)

	# Add each hero
	for hero in heroes:
		create_combatant_display(hero)

	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	combatants_list.add_child(spacer)

	# Add Monsters header
	var monsters_label = Label.new()
	monsters_label.text = "MONSTERS"
	monsters_label.add_theme_font_size_override("font_size", 16)
	combatants_list.add_child(monsters_label)

	# Add each monster
	for monster in monsters:
		create_combatant_display(monster)

func create_combatant_display(combatant):
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)

	# Add tooltip for heroes on the entire container
	if heroes.has(combatant):
		container.tooltip_text = generate_hero_tooltip(combatant)
		container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Name label with arrow indicator
	var name_container = HBoxContainer.new()

	# Green arrow for current turn
	if combatant == current_turn_combatant:
		var arrow_label = Label.new()
		arrow_label.text = "► "
		arrow_label.modulate = Color(0.2, 1.0, 0.2)
		name_container.add_child(arrow_label)
	else:
		var spacer = Label.new()
		spacer.text = "   "
		name_container.add_child(spacer)

	# Name label using RichTextLabel for BBCode support
	var name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.scroll_active = false
	name_label.custom_minimum_size = Vector2(180, 20)

	# Build the BBCode text
	var name_text = combatant.combatant_name

	# Add level for heroes
	if heroes.has(combatant):
		name_text = "Lv. %d %s" % [combatant.stats.get("Level", 1), name_text]

	# Colorize monsters by family
	if monsters.has(combatant):
		name_text = colorize_monster_name(name_text)

	# Italic if last target
	if last_ability_targets.has(combatant):
		name_text = "[i][color=#FFFFCC]" + name_text + "[/color][/i]"

	# Gray out if dead
	if combatant.is_dead:
		name_text = "[color=#808080]" + name_text + "[/color]"

	name_label.text = name_text

	name_container.add_child(name_label)
	container.add_child(name_container)

	# Health bar container
	var health_container = HBoxContainer.new()

	# HP Label
	var hp_label = Label.new()
	hp_label.text = "HP:"
	hp_label.custom_minimum_size = Vector2(25, 0)
	health_container.add_child(hp_label)

	# Health bar background
	var health_bg = ProgressBar.new()
	health_bg.custom_minimum_size = Vector2(175, 20)
	health_bg.max_value = combatant.stats["MaxHealth"]
	health_bg.value = combatant.stats["Health"]
	health_bg.show_percentage = false

	# Color the health bar based on health
	var health_percent = float(combatant.stats["Health"]) / float(combatant.stats["MaxHealth"])
	if combatant.is_dead:
		health_bg.modulate = Color(0.3, 0.3, 0.3)
	elif health_percent > 0.66:
		health_bg.modulate = Color(0.2, 1.0, 0.2)
	elif health_percent > 0.33:
		health_bg.modulate = Color(1.0, 1.0, 0.2)
	else:
		health_bg.modulate = Color(1.0, 0.2, 0.2)

	health_container.add_child(health_bg)

	# Health value label
	var health_label = Label.new()
	if combatant.is_dead:
		health_label.text = " DEAD"
		health_label.modulate = Color(0.5, 0.5, 0.5)
	else:
		health_label.text = " %d/%d" % [combatant.stats["Health"], combatant.stats["MaxHealth"]]
	health_label.custom_minimum_size = Vector2(70, 0)
	health_container.add_child(health_label)

	container.add_child(health_container)

	# Add EXP bar for heroes only
	if heroes.has(combatant):
		var exp_container = HBoxContainer.new()

		# EXP Label
		var exp_label = Label.new()
		exp_label.text = "EXP:"
		exp_label.custom_minimum_size = Vector2(25, 0)
		exp_container.add_child(exp_label)

		# EXP progress bar
		var exp_bg = ProgressBar.new()
		exp_bg.custom_minimum_size = Vector2(175, 20)
		exp_bg.max_value = combatant.stats.get("EXPToNextLevel", 100)
		exp_bg.value = combatant.stats.get("CurrentEXP", 0)
		exp_bg.show_percentage = false
		exp_bg.modulate = Color(0.5, 0.5, 1.0)
		exp_container.add_child(exp_bg)

		# EXP value label
		var exp_value_label = Label.new()
		exp_value_label.text = " %d/%d" % [combatant.stats.get("CurrentEXP", 0), combatant.stats.get("EXPToNextLevel", 100)]
		exp_value_label.custom_minimum_size = Vector2(70, 0)
		exp_container.add_child(exp_value_label)

		container.add_child(exp_container)

	# Add status effects display
	if combatant.status_effects.size() > 0:
		var status_container = HBoxContainer.new()

		var status_label = Label.new()
		status_label.text = "Status:"
		status_label.custom_minimum_size = Vector2(50, 0)
		status_container.add_child(status_label)

		var effects_text = ""
		for effect in combatant.status_effects:
			if effects_text != "":
				effects_text += ", "
			effects_text += effect.get_display_text()

		var effects_label = Label.new()
		effects_label.text = effects_text
		effects_label.custom_minimum_size = Vector2(200, 0)
		effects_label.modulate = Color(1.0, 0.8, 0.2)  # Golden color
		status_container.add_child(effects_label)

		container.add_child(status_container)

	combatants_list.add_child(container)

func load_json_file(path):
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: " + path)
		return []

	var content = file.get_as_text()
	var parsed = JSON.parse_string(content)

	# Check if parsing failed
	if typeof(parsed) == TYPE_NIL:
		push_error("Failed to parse JSON or file was empty.")
		return []

	# Optional: check that it's an Array or Dictionary
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Expected array in JSON, got: " + str(typeof(parsed)))
		return []

	return parsed

func generate_combatants():
	heroes.clear()
	monsters.clear()
	all_combatants.clear()
	StatsTracker.clear_stats()

	for i in 4:
		var hero = Combatant.new()
		hero.combatant_name = "Hero %d" % i
		hero.stats = random_hero_stats()
		hero.abilities = pick_random_abilities()
		heroes.append(hero)

		# Initialize hero statistics via StatsTracker
		StatsTracker.initialize_hero(hero)

	var num_monsters = currentFloor.getNextRoom()

	for i in num_monsters:
		var monster = Combatant.new()
		# Roll for random family and rank based on floor probabilities
		var family_name = roll_monster_family()
		var rank = roll_monster_rank()
		var family = get_monster_family(family_name)
		var rank_name = family["rank_names"][rank]
		monster.combatant_name = "%s %s" % [rank_name, family_name]
		monster.stats = random_monster_stats(family_name, rank)
		monster.abilities = pick_monster_abilities(family_name)
		monsters.append(monster)

	all_combatants = heroes + monsters

	# Initialize CombatantCache with new combatants
	CombatantCache.initialize(heroes, monsters)

	update_combatants_display()

func generate_monsters():
	monsters.clear()

	for i in 3:
		var monster = Combatant.new()
		# Roll for random family and rank based on floor probabilities
		var family_name = roll_monster_family()
		var rank = roll_monster_rank()
		var family = get_monster_family(family_name)
		var rank_name = family["rank_names"][rank]
		monster.combatant_name = "%s %s" % [rank_name, family_name]
		monster.stats = random_monster_stats(family_name, rank)
		monster.abilities = pick_monster_abilities(family_name)
		monsters.append(monster)

	all_combatants.clear()
	all_combatants = heroes + monsters

	# Reinitialize CombatantCache with new monsters
	CombatantCache.initialize(heroes, monsters)

	update_combatants_display()

func generate_new_floor():
	# Generate new probability tables for this floor
	generate_family_probabilities()
	generate_rank_probabilities()

	# Use a placeholder for floor generation (no longer tied to single family)
	currentFloor = Floor.new(randi()%4+2, "Mixed")
	log_event("------------------------------------------------")
	log_event("------------------------------------------------")
	log_event("Starting Floor: " + str(floorsCleared+1) + ". Number of rooms: " + str(currentFloor.num_rooms))
	log_event("Monsters in room 1: " + str(currentFloor.getNextRoom()))
	log_event("------------------------------------------------")
	log_event("------------------------------------------------")
	update_floor_room_display()

func get_monster_family(family_name):
	# Now uses O(1) hash lookup instead of O(n) linear search
	var family = AbilityDatabase.get_family(family_name)
	if family.is_empty():
		# Fallback to first family if not found
		return AbilityDatabase.families[0] if AbilityDatabase.families.size() > 0 else {}
	return family

func generate_family_probabilities():
	# Create randomized probability weights for each family
	family_probabilities.clear()
	var total_weight = 0.0

	# Assign random weights to each family
	for family in AbilityDatabase.families:
		var weight = randf_range(1.0, 10.0)
		total_weight += weight
		family_probabilities.append({"family": family["name"], "weight": weight, "cumulative": 0.0})

	# Convert to cumulative probabilities
	var cumulative = 0.0
	for prob in family_probabilities:
		cumulative += prob["weight"] / total_weight
		prob["cumulative"] = cumulative

func generate_rank_probabilities():
	# Create randomized probability weights for each rank (0-3)
	# Lower ranks are more common, higher ranks are rarer
	rank_probabilities.clear()
	var weights = []

	# Generate decreasing weights for higher ranks
	for i in 4:
		var weight = randf_range(5.0, 10.0) / (i + 1)  # Higher ranks have lower weights
		weights.append(weight)

	var total_weight = 0.0
	for w in weights:
		total_weight += w

	# Convert to cumulative probabilities
	var cumulative = 0.0
	for i in 4:
		cumulative += weights[i] / total_weight
		rank_probabilities.append({"rank": i, "cumulative": cumulative})

func roll_monster_family():
	var roll = randf()
	for prob in family_probabilities:
		if roll <= prob["cumulative"]:
			return prob["family"]
	return family_probabilities[-1]["family"]  # Fallback to last family

func roll_monster_rank():
	var roll = randf()
	for prob in rank_probabilities:
		if roll <= prob["cumulative"]:
			return prob["rank"]
	return 0  # Fallback to rank 0

func random_monster_stats(family_name, rank):
	var family = get_monster_family(family_name)
	var modifiers = family["stat_modifiers"]

	# Base stats
	var base_health = randi_range(50, 80)
	var base_power = randi_range(8, 15)
	var base_agility = randi_range(4, 12)
	var base_resilience = randi_range(3, 8)
	var base_willpower = randi_range(3, 8)
	var base_accuracy = randi_range(50, 80)
	var base_evasion = randi_range(0, 20)

	# Apply family modifiers
	var max_health = int(base_health * modifiers["health_multiplier"])
	var power = int(base_power * modifiers["power_multiplier"])
	var agility = int(base_agility * modifiers["agility_multiplier"])
	var accuracy = int(base_accuracy * modifiers["accuracy_multiplier"])
	var evasion = base_evasion + modifiers["evasion_bonus"]

	# Apply rank bonuses (rank 0-3, each rank adds 20% to stats)
	var rank_multiplier = 1.0 + (rank * 0.2)
	max_health = int(max_health * rank_multiplier)
	power = int(power * rank_multiplier)

	return {
		"Health": max_health,
		"MaxHealth": max_health,
		"Power": power,
		"Agility": agility,
		"Resilience": base_resilience,
		"Willpower": base_willpower,
		"Accuracy": accuracy,
		"Evasion": evasion,
		"EXP": randi_range(30, 80) + (rank * 20)
	}

func random_stats():
	var max_health = randi_range(50, 80)
	return {
		"Health": max_health,
		"MaxHealth": max_health,
		"Power": randi_range(8, 15),
		"Agility": randi_range(4, 12),
		"Resilience": randi_range(3, 8),
		"Willpower": randi_range(3, 8),
		"Accuracy": randi_range(50, 80),
		"Evasion": randi_range(0, 20),
		"EXP": randi_range(30, 80)
	}

func random_hero_stats():
	var max_health = randi_range(150, 200)
	return {
		"Health": max_health,
		"MaxHealth": max_health,
		"Power": randi_range(15, 25),
		"Agility": randi_range(8, 18),
		"Resilience": randi_range(8, 15),
		"Willpower": randi_range(8, 15),
		"Accuracy": randi_range(70, 95),
		"Evasion": randi_range(5, 35),
		"Level": 1,
		"CurrentEXP": 0,
		"EXPToNextLevel": 100
	}

func pick_random_abilities():
	var chosen = []
	var available_abilities = AbilityDatabase.abilities.duplicate()

	for i in 3:
		if available_abilities.is_empty():
			break  # No more unique abilities available

		var random_index = randi() % available_abilities.size()
		var selected_ability = available_abilities[random_index]
		chosen.append(selected_ability)
		available_abilities.remove_at(random_index)

	return chosen

func pick_monster_abilities(family_name):
	# Now uses O(1) hash lookups instead of O(n²) nested loops
	var chosen = AbilityDatabase.get_monster_abilities_for_family(family_name)

	# If we don't have 3 abilities, fill with random monster abilities
	while chosen.size() < 3:
		var random_ability = AbilityDatabase.get_random_monster_ability()
		if not chosen.has(random_ability):
			chosen.append(random_ability)

	return chosen

func sort_by_agility():
	all_combatants.shuffle()
	all_combatants.sort_custom(func(a, b):
		return b.stats["Agility"] - a.stats["Agility"]
	)

func is_battle_over():
	# Use cache to check if all combatants of a team are dead
	return CombatantCache.are_all_dead(heroes) or CombatantCache.are_all_dead(monsters)

func get_team(combatant):
	return heroes if heroes.has(combatant) else monsters

func get_enemy_team(combatant):
	return monsters if heroes.has(combatant) else heroes

func choose_target(combatant, ability):
	var num_targets = ability.get("num_targets", 1)
	var target_type = ability.get("target", "enemy")

	# Use cached alive combatants instead of filtering every time
	var potential_targets = []
	if target_type == "enemy":
		potential_targets = CombatantCache.get_alive_enemies(combatant)
	else:  # ally
		potential_targets = CombatantCache.get_alive_allies(combatant)

	if potential_targets.is_empty():
		return []

	# Shuffle and take up to num_targets
	potential_targets.shuffle()
	var actual_num = min(num_targets, potential_targets.size())
	return potential_targets.slice(0, actual_num)

func check_accuracy(user, intended_zone):
	var accuracy_roll = randi() % 100 + 1
	var accuracy_stat = user.stats["Accuracy"]

	if accuracy_roll <= accuracy_stat:
		return {"success": true, "zone": intended_zone, "margin": 0}
	else:
		var miss_margin = accuracy_roll - accuracy_stat
		var zone_shift = calculate_zone_shift(miss_margin)
		var new_zone = shift_hit_zone(intended_zone, zone_shift)
		return {"success": false, "zone": new_zone, "margin": miss_margin}

func calculate_zone_shift(miss_margin):
	if miss_margin <= 10:
		return randi() % 2 + 1
	elif miss_margin <= 25:
		return randi() % 3 + 2
	else:
		return randi() % 4 + 3

func shift_hit_zone(original_zone, shift_amount):
	var direction = 1 if randi() % 2 == 0 else -1
	var new_zone = (original_zone + (shift_amount * direction)) % HIT_ZONES.size()
	if new_zone < 0:
		new_zone += HIT_ZONES.size()
	return new_zone

func check_hit(target, hit_zone):
	var base_hit_chance = 100 - target.stats["Evasion"]
	var zone_difficulty = HIT_ZONES[hit_zone]["difficulty"]
	var final_hit_chance = (base_hit_chance / zone_difficulty) + 15

	var hit_roll = randi() % 100 + 1
	return hit_roll <= final_hit_chance

func apply_status_effect_to_target(target, effect_type: String, params: Dictionary = {}):
	# Create and apply status effect using the factory
	var effect = StatusEffects.create_effect(effect_type, params)
	if effect:
		target.apply_status_effect(effect)
		log_event("%s is affected by %s!" % [target.combatant_name, effect.get_display_text()])

func apply_ability(user, ability, targets):
	last_ability_targets = targets
	var accuracy_mode = ability.get("accuracy_mode", "all")
	var number_attacks = ability.get("number_attacks", 1)

	if accuracy_mode == "none":
		# No accuracy check - all targets get hit
		for target in targets:
			# Skip if target died during this ability (e.g., multi-target attack)
			if target.is_dead:
				continue

			var min_dmg = ability.get("min_damage", 0)
			var max_dmg = ability.get("max_damage", 0)
			var user_name = colorize_combatant_name(user)
			var target_name = colorize_combatant_name(target)

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

			var result = target.take_damage(total_damage)
			var just_died = result["died"]
			var actual_damage = result["actual_damage"]
			var damage_type = "health" if total_damage < 0 else "damage"

			# Emit events for damage/healing tracking
			if total_damage > 0:
				EventBus.combatant_damaged.emit(user, target, total_damage, actual_damage)
			else:
				EventBus.combatant_healed.emit(user, target, abs(actual_damage))

			# Emit ability usage event (only once per ability use, not per target)
			if target == targets[0]:  # Only on first target
				EventBus.ability_used.emit(user, ability, targets)

			# Format damage rolls display
			var damage_display = ""
			if number_attacks == 1:
				damage_display = "%s %s" % [damage_rolls[0], damage_type]
			else:
				damage_display = "(%s) = %d %s" % [" + ".join(damage_rolls), int(abs(total_damage)), damage_type]

			var action = "%s uses %s on %s for %s." % [
				user_name, ability["name"], target_name, damage_display
			]
			log_event(action)
			# Log death with red background and emit death event
			if just_died:
				log_event("[bgcolor=#8B0000][color=#FFFFFF]%s has died![/color][/bgcolor]" % colorize_combatant_name(target))
				EventBus.combatant_died.emit(target, user)

			# Apply status effect if the ability has one
			if ability.has("status_effect") and not target.is_dead:
				var status_data = ability["status_effect"]
				apply_status_effect_to_target(target, status_data["type"], status_data)

	elif accuracy_mode == "one":
		# One accuracy check for all targets - all hit or all miss
		var intended_zone = user.choose_hit_zone()
		var user_name = colorize_combatant_name(user)
		log_event("%s attempts to use %s on hit zone %d (%s)" % [user_name, ability["name"], intended_zone, HIT_ZONES[intended_zone]["name"]])

		var accuracy_result = check_accuracy(user, intended_zone)
		var final_zone = accuracy_result["zone"]

		if not accuracy_result["success"]:
			log_event("%s fails the accuracy check, new hit zone is %d (%s)" % [user_name, final_zone, HIT_ZONES[final_zone]["name"]])

		# Use first target for the single hit check
		var hit_success = check_hit(targets[0], final_zone)

		if not hit_success:
			log_event("%s misses all targets" % user_name)
		else:
			# Emit ability usage event once for the whole attack
			EventBus.ability_used.emit(user, ability, targets)

			# Apply to all targets since the one check passed
			for target in targets:
				# Skip if target died during this ability (e.g., multi-target attack)
				if target.is_dead:
					continue

				var min_dmg = ability.get("min_damage", 0)
				var max_dmg = ability.get("max_damage", 0)
				var target_name = colorize_combatant_name(target)

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

				var action = "%s uses %s on %s hitting zone %d (%s) for %s." % [
					user_name, ability["name"], target_name, final_zone, HIT_ZONES[final_zone]["name"], damage_display
				]
				log_event(action)
				# Log death with red background and emit death event
				if just_died:
					log_event("[bgcolor=#8B0000][color=#FFFFFF]%s has died![/color][/bgcolor]" % colorize_combatant_name(target))
					EventBus.combatant_died.emit(target, user)

				# Apply status effect if the ability has one
				if ability.has("status_effect") and not target.is_dead:
					var status_data = ability["status_effect"]
					apply_status_effect_to_target(target, status_data["type"], status_data)

	else:  # accuracy_mode == "all"
		# Emit ability usage event once for the whole attack
		EventBus.ability_used.emit(user, ability, targets)

		# Separate accuracy check for each target and each attack
		for target in targets:
			# Skip if target died during this ability (e.g., multi-target attack)
			if target.is_dead:
				continue

			var user_name = colorize_combatant_name(user)
			var target_name = colorize_combatant_name(target)
			var min_dmg = ability.get("min_damage", 0)
			var max_dmg = ability.get("max_damage", 0)

			# Roll damage multiple times with accuracy check for each
			var total_damage = 0.0
			var damage_rolls = []
			var hit_count = 0

			for i in number_attacks:
				var intended_zone = user.choose_hit_zone()
				log_event("%s attempts to use %s on %s at hit zone %d (%s)" % [user_name, ability["name"], target_name, intended_zone, HIT_ZONES[intended_zone]["name"]])

				var accuracy_result = check_accuracy(user, intended_zone)
				var final_zone = accuracy_result["zone"]

				if not accuracy_result["success"]:
					log_event("%s fails the accuracy check, new hit zone is %d (%s)" % [user_name, final_zone, HIT_ZONES[final_zone]["name"]])

				var hit_success = check_hit(target, final_zone)

				if not hit_success:
					log_event("%s misses %s" % [user_name, target_name])
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

				log_event("%s hits %s at zone %d (%s)" % [user_name, target_name, final_zone, HIT_ZONES[final_zone]["name"]])

			# Apply total damage if any attacks hit
			if hit_count > 0:
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

				log_event("Total damage dealt: %s" % damage_display)

				# Log death with red background and emit death event
				if just_died:
					log_event("[bgcolor=#8B0000][color=#FFFFFF]%s has died![/color][/bgcolor]" % colorize_combatant_name(target))
					EventBus.combatant_died.emit(target, user)

				# Apply status effect if the ability has one (only if at least one attack hit)
				if ability.has("status_effect") and not target.is_dead:
					var status_data = ability["status_effect"]
					apply_status_effect_to_target(target, status_data["type"], status_data)

	update_combatants_display()

func get_alive_combatants():
	# Use cached alive combatants instead of filtering every time
	return CombatantCache.get_alive_combatants()

func skip_if_dead(combatant):
	return combatant.is_dead

func show_game_over_popup():
	# Clear previous stats
	for child in game_over_stats_container.get_children():
		child.queue_free()

	# Set floor/room label
	game_over_floor_room_label.text = "Died on Floor %d, Room %d" % [floorsCleared + 1, currentFloor.current_room + 1]

	# Add statistics for each hero
	for hero in heroes:
		var stats = StatsTracker.get_hero_stats(hero)
		if stats.is_empty():
			continue

		# Hero section container
		var hero_section = VBoxContainer.new()
		hero_section.custom_minimum_size = Vector2(0, 10)

		# Hero name header
		var name_label = Label.new()
		name_label.text = "=== %s ===" % hero.combatant_name
		name_label.add_theme_font_size_override("font_size", 16)
		hero_section.add_child(name_label)

		# Final level
		var level_label = Label.new()
		level_label.text = "  Final Level: %d" % hero.stats.get("Level", 1)
		hero_section.add_child(level_label)

		# Total damage dealt
		var damage_label = Label.new()
		damage_label.text = "  Total Damage Dealt: %d" % int(stats["total_damage_dealt"])
		hero_section.add_child(damage_label)

		# Total healing done
		var healing_label = Label.new()
		healing_label.text = "  Total Healing Done: %d" % int(stats["total_healing_done"])
		hero_section.add_child(healing_label)

		# Most used ability (use StatsTracker helper)
		var most_used_ability = StatsTracker.get_most_used_ability(hero)
		var max_uses = stats["ability_usage"].get(most_used_ability, 0) if most_used_ability != "None" else 0
		var ability_text = most_used_ability if most_used_ability == "None" else "%s (%d times)" % [most_used_ability, max_uses]

		var ability_label = Label.new()
		ability_label.text = "  Most Used Ability: %s" % ability_text
		hero_section.add_child(ability_label)

		# Total damage taken
		var taken_label = Label.new()
		taken_label.text = "  Total Damage Taken: %d" % int(stats["total_damage_taken"])
		hero_section.add_child(taken_label)

		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		hero_section.add_child(spacer)

		game_over_stats_container.add_child(hero_section)

	# Show the popup
	game_over_popup.visible = true

func show_hero_preview_popup():
	"""Show the hero preview popup with a 10 second countdown"""
	# Clear previous heroes
	for child in hero_preview_container.get_children():
		child.queue_free()

	# Populate with current heroes
	for hero in heroes:
		var hero_section = VBoxContainer.new()
		hero_section.custom_minimum_size = Vector2(0, 10)

		# Hero name header
		var name_label = Label.new()
		name_label.text = "=== %s ===" % hero.combatant_name
		name_label.add_theme_font_size_override("font_size", 16)
		hero_section.add_child(name_label)

		# Hero stats
		var stats_text = "  HP: %d/%d | Power: %d | Resilience: %d | Agility: %d" % [
			hero.stats["Health"],
			hero.stats["MaxHealth"],
			hero.stats["Power"],
			hero.stats["Resilience"],
			hero.stats["Agility"]
		]
		var stats_label = Label.new()
		stats_label.text = stats_text
		hero_section.add_child(stats_label)

		# Abilities
		var abilities_label = Label.new()
		abilities_label.text = "  Abilities:"
		hero_section.add_child(abilities_label)

		for ability in hero.abilities:
			var ability_label = Label.new()
			ability_label.text = "    - %s (Damage: %.0f-%.0f)" % [
				ability["name"],
				ability.get("min_damage", 0),
				ability.get("max_damage", 0)
			]
			hero_section.add_child(ability_label)

		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		hero_section.add_child(spacer)

		hero_preview_container.add_child(hero_section)

	# Fade in and countdown
	await fade_in_popup(hero_preview_popup)
	await countdown_popup(hero_preview_countdown, "Run starting in %d", 10)
	await fade_out_popup(hero_preview_popup)

func show_floor_cleared_popup():
	"""Show the floor cleared popup with a 10 second countdown"""
	# Update floor label
	floor_cleared_floor_label.text = "Floor %d Complete" % floorsCleared

	# Clear previous heroes
	for child in floor_cleared_container.get_children():
		child.queue_free()

	# Populate with current hero status
	for hero in heroes:
		if hero.is_dead:
			continue

		var hero_section = VBoxContainer.new()
		hero_section.custom_minimum_size = Vector2(0, 10)

		# Hero name header
		var name_label = Label.new()
		name_label.text = "=== %s ===" % hero.combatant_name
		name_label.add_theme_font_size_override("font_size", 16)
		hero_section.add_child(name_label)

		# Hero stats
		var stats_text = "  HP: %d/%d | Level: %d | EXP: %d/%d" % [
			hero.stats["Health"],
			hero.stats["MaxHealth"],
			hero.stats["Level"],
			hero.stats["CurrentEXP"],
			hero.stats["EXPToNextLevel"]
		]
		var stats_label = Label.new()
		stats_label.text = stats_text
		hero_section.add_child(stats_label)

		# Abilities with levels
		var abilities_label = Label.new()
		abilities_label.text = "  Abilities:"
		hero_section.add_child(abilities_label)

		var hero_stats = StatsTracker.get_hero_stats(hero)
		for ability in hero.abilities:
			var ability_name = ability["name"]
			var ability_level = hero_stats["ability_levels"].get(ability_name, 1)
			var ability_exp = hero_stats["ability_exp"].get(ability_name, 0)
			var exp_required = ExperienceManager.get_ability_exp_required(ability_level)

			var ability_label = Label.new()
			ability_label.text = "    - %s (Lv. %d, %d/%d EXP)" % [
				ability_name,
				ability_level,
				ability_exp,
				exp_required
			]
			hero_section.add_child(ability_label)

		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		hero_section.add_child(spacer)

		floor_cleared_container.add_child(hero_section)

	# Fade in and countdown
	await fade_in_popup(floor_cleared_popup)
	await countdown_popup(floor_cleared_countdown, "Next floor starting in %d", 10)
	await fade_out_popup(floor_cleared_popup)

func fade_in_popup(popup: Panel):
	"""Fade in a popup over 0.5 seconds"""
	popup.visible = true
	popup.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.5)
	await tween.finished

func fade_out_popup(popup: Panel):
	"""Fade out a popup over 0.5 seconds"""
	var tween = create_tween()
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	await tween.finished
	popup.visible = false

func countdown_popup(countdown_label: Label, format_string: String, seconds: int):
	"""Countdown from seconds to 0, updating the label each second"""
	for i in range(seconds, 0, -1):
		countdown_label.text = format_string % i
		await get_tree().create_timer(1.0).timeout

func print_winner():
	if heroes.all(func(c): return c.is_dead):
		log_event("Monsters win! Rounds won: " + str(roundsWon) + ". Floors cleared: " + str(floorsCleared) )
		pause_button.disabled = true
		show_game_over_popup()
	elif monsters.all(func(c): return c.is_dead):
		log_event("------------------------------------------------")
		currentFloor.clearRoom()
		if currentFloor.hasNextRoom():
			log_event("Heroes win! Moving to next Room. Room " + str(currentFloor.current_room+1))
			log_event("Monsters in room: " + str(currentFloor.getNextRoom()))
			roundsWon += 1
			update_floor_room_display()
		else:
			roundsWon += 1
			floorsCleared += 1
			log_event("Heroes win! All rooms cleared!")

			# Show floor cleared popup with countdown
			await show_floor_cleared_popup()

			log_event("Moving to Floor " + str(floorsCleared+1))
			generate_new_floor()
		log_event("------------------------------------------------")

		generate_monsters()
		simulate_battle()

func get_next_alive_index(from_index):
	var alive = get_alive_combatants()
	return alive[from_index % alive.size()]

func simulate_turn(combatant):
	if combatant.is_dead:
		return

	current_turn_combatant = combatant
	update_combatants_display()

	var combatant_name = colorize_combatant_name(combatant)
	log_event("Turn: " + combatant_name + " (" + str(combatant.stats["Health"]) + ")")

	# Process status effects at turn start
	combatant.process_status_effects_turn_start()
	update_combatants_display()

	# Check if combatant died from status effects (e.g., poison)
	if combatant.is_dead:
		current_turn_combatant = null
		return

	# Check if stunned
	if combatant.is_stunned():
		current_turn_combatant = null
		return

	var ability = combatant.choose_ability()
	var targets = choose_target(combatant, ability)
	if targets.size() > 0:
		apply_ability(combatant, ability, targets)

	# Process status effects at turn end
	combatant.process_status_effects_turn_end()
	update_combatants_display()

	current_turn_combatant = null

func simulate_round():
	for combatant in get_alive_combatants():
		while is_paused:
			await get_tree().create_timer(0.1).timeout

		# Skip if this combatant died during this round (e.g., from poison)
		if combatant.is_dead:
			continue

		simulate_turn(combatant)

		# Check if battle ended during this turn
		if is_battle_over():
			return

		await get_tree().create_timer(TICK_SPEED).timeout

func simulate_battle():
	while not is_battle_over():
		await simulate_round()
	print_winner()
