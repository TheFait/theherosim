extends Node

const ABILITY_PATH = "res://data/abilities.json"

var heroes = []
var monsters = []
var all_combatants = []
var abilities = []
var roundsWon = 0
var floorsCleared = 0
var currentFloor = ""

@onready var log_box = $LogBoxPanel/LogBox
@onready var start_button = $StartButton

func _ready():
	start_button.pressed.connect(on_start_pressed)
	log_event("Ready to simulate combat.")

func on_start_pressed():
	start_button.disabled = true
	abilities = load_json_file(ABILITY_PATH)
	generate_new_floor()
	generate_combatants()
	sort_by_agility()
	await simulate_battle()

func log_event(text):
	log_box.append_text(text + "\n")
	log_box.scroll_to_line(log_box.get_line_count() - 1)

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

	for i in 4:
		var hero = Combatant.new()
		hero.combatant_name = "Hero %d" % i
		hero.stats = random_hero_stats()
		hero.abilities = pick_random_abilities()
		heroes.append(hero)

	for i in currentFloor.getNextRoom():
		var monster = Combatant.new()
		monster.combatant_name = "{name} {num}".format({"name": currentFloor.monster_type, "num": i})
		monster.stats = random_stats()
		monster.abilities = pick_random_abilities()
		monsters.append(monster)

	all_combatants = heroes + monsters

func generate_monsters():
	monsters.clear()
	for i in 3:
		var monster = Combatant.new()
		monster.combatant_name = "{name} {num}".format({"name": currentFloor.monster_type, "num": i})
		monster.stats = random_stats()
		monster.abilities = pick_random_abilities()
		monsters.append(monster)
	
	all_combatants.clear()
	all_combatants = heroes + monsters

func generate_new_floor():
	currentFloor = Floor.new(randi()%9+2, "Goblin")
	log_event("------------------------------------------------")
	log_event("------------------------------------------------")
	log_event("Starting Floor: " + str(floorsCleared+1) + ". Number of rooms: " + str(currentFloor.num_rooms))
	log_event("Monsters in room 1: " + str(currentFloor.getNextRoom()))
	log_event("------------------------------------------------")
	log_event("------------------------------------------------")

func random_stats():
	return {
		"Health": randi_range(70, 120),
		"Power": randi_range(10, 20),
		"Agility": randi_range(5, 15),
		"Resilience": randi_range(5, 10),
		"Willpower": randi_range(5, 10)
	}
	
func random_hero_stats():
	return {
		"Health": randi_range(100, 120),
		"Power": randi_range(10, 20),
		"Agility": randi_range(5, 15),
		"Resilience": randi_range(5, 10),
		"Willpower": randi_range(5, 10)
	}

func pick_random_abilities():
	var chosen = []
	for i in 3:
		chosen.append(abilities[randi() % abilities.size()])
	return chosen

func sort_by_agility():
	all_combatants.shuffle()
	all_combatants.sort_custom(func(a, b):
		return b.stats["Agility"] - a.stats["Agility"]
	)

func is_battle_over():
	return heroes.all(func(c): return c.is_dead) or monsters.all(func(c): return c.is_dead)

func get_team(combatant):
	return heroes if heroes.has(combatant) else monsters

func get_enemy_team(combatant):
	return monsters if heroes.has(combatant) else heroes

func choose_target(combatant, ability):
	var targets = []
	var allies = get_team(combatant)
	var enemies = get_enemy_team(combatant)

	match ability["target"]:
		"enemy_single":
			targets = enemies.filter(func(c): return not c.is_dead)
			if targets:
				return [targets[randi() % targets.size()]]
		"ally_single":
			targets = allies.filter(func(c): return not c.is_dead)
			if targets:
				return [targets[randi() % targets.size()]]
		"enemy_all":
			return enemies.filter(func(c): return not c.is_dead)
		"ally_all":
			return allies.filter(func(c): return not c.is_dead)

	return []

func apply_ability(user, ability, targets):
	for target in targets:
		var dmg = ability["damage"]
		target.take_damage(dmg)
		var action = "%s uses %s on %s for %d %s." % [
			user.combatant_name, ability["name"], target.combatant_name, abs(dmg), "healing" if dmg < 0 else "damage"
		]
		log_event(action)

func get_alive_combatants():
	return all_combatants.filter(func(c): return not c.is_dead)

func skip_if_dead(combatant):
	return combatant.is_dead

func print_winner():
	if heroes.all(func(c): return c.is_dead):
		log_event("Monsters win! Rounds won: " + str(roundsWon) + ". Floors cleared: " + str(floorsCleared) )
	elif monsters.all(func(c): return c.is_dead):
		log_event("------------------------------------------------")
		currentFloor.clearRoom()
		if currentFloor.hasNextRoom():
			log_event("Heroes win! Moving to next Room. Room " + str(currentFloor.current_room+1))
			log_event("Monsters in room: " + str(currentFloor.getNextRoom()))
			roundsWon += 1
		else:
			roundsWon += 1
			floorsCleared += 1
			log_event("Heroes win! All rooms cleared, moving to Floor " + str(floorsCleared+1))
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
	else:
		log_event("Turn: " + combatant.combatant_name + " (" + str(combatant.stats["Health"]) + ")")
	var ability = combatant.choose_ability()
	var targets = choose_target(combatant, ability)
	if targets.size() > 0:
		apply_ability(combatant, ability, targets)

func simulate_round():
	for combatant in get_alive_combatants():
		simulate_turn(combatant)
		await get_tree().create_timer(0.5).timeout

func simulate_battle():
	while not is_battle_over():
		await simulate_round()
	print_winner()
	start_button.disabled = false
