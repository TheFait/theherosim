extends Node

## ElementalSystem - Singleton for managing elemental damage calculations
## This is an autoload singleton - access via ElementalSystem global
## Handles element data, damage multipliers, and elemental advantage/disadvantage

const DataLoader = preload("res://data/loaders/DataLoader.gd")

const ELEMENTS_PATH = "res://data/elements.json"
const STRONG_MULTIPLIER = 2.0
const WEAK_MULTIPLIER = 0.5
const AFFINITY_BONUS = 1.1  # 10% damage increase

# Data stores
var element_data = {}  # element_id -> element definition

func _ready():
	load_data()

func load_data():
	# Load element definitions
	var elements_array = DataLoader.load_json(ELEMENTS_PATH)
	for element_def in elements_array:
		element_data[element_def["id"]] = element_def

## Calculate elemental damage multiplier
## Returns multiplier based on attacker element vs defender element
func get_elemental_multiplier(attacker_element: String, defender_element: String) -> float:
	# No attacker element = neutral damage
	if attacker_element == "" or attacker_element == "none":
		return 1.0

	# No defender element = neutral damage
	if defender_element == "" or defender_element == "none":
		return 1.0

	# Same element = neutral damage
	if attacker_element == defender_element:
		return 1.0

	# Check if attacker element exists
	if not element_data.has(attacker_element):
		push_error("ElementalSystem: Unknown attacker element: " + attacker_element)
		return 1.0

	var attacker_data = element_data[attacker_element]

	# Check if strong against defender
	if defender_element in attacker_data["strong_against"]:
		return STRONG_MULTIPLIER

	# Check if weak against defender
	if defender_element in attacker_data["weak_against"]:
		return WEAK_MULTIPLIER

	# Neutral matchup
	return 1.0

## Calculate affinity bonus multiplier
## Returns 1.1 if hero has affinity for the element, 1.0 otherwise
func get_affinity_multiplier(hero_affinities: Array, ability_element: String) -> float:
	if ability_element == "" or ability_element == "none":
		return 1.0

	if ability_element in hero_affinities:
		return AFFINITY_BONUS

	return 1.0

## Get element display name
func get_element_name(element_id: String) -> String:
	if element_data.has(element_id):
		return element_data[element_id]["name"]
	return ""

## Get element icon
func get_element_icon(element_id: String) -> String:
	if element_data.has(element_id):
		return element_data[element_id]["icon"]
	return ""

## Get element color
func get_element_color(element_id: String) -> String:
	if element_data.has(element_id):
		return element_data[element_id]["color"]
	return "#FFFFFF"

## Get colored element text (icon + name)
func get_colored_element_text(element_id: String) -> String:
	if element_id == "" or element_id == "none":
		return ""

	if not element_data.has(element_id):
		return ""

	var icon = get_element_icon(element_id)
	var name = get_element_name(element_id)
	var color = get_element_color(element_id)

	return "[color=%s]%s %s[/color]" % [color, icon, name]

## Get all element IDs
func get_all_element_ids() -> Array:
	return element_data.keys()

## Get random element ID
func get_random_element() -> String:
	var elements = get_all_element_ids()
	if elements.is_empty():
		return ""
	return elements[randi() % elements.size()]

## Calculate elemental damage with all modifiers applied
## Returns Dictionary with "damage" (float) and "multiplier_text" (String)
func calculate_damage(base_damage: float, element: String, user, target) -> Dictionary:
	var final_damage = base_damage
	var multiplier_text = ""

	# Get target's element (if any)
	var target_element = ""
	if target and "element" in target:
		target_element = target.element

	# Apply elemental multiplier (strong/weak against)
	var elemental_mult = get_elemental_multiplier(element, target_element)
	if elemental_mult != 1.0:
		final_damage *= elemental_mult
		if elemental_mult > 1.0:
			multiplier_text = " [color=#FF6B6B](Super Effective!)[/color]"
		elif elemental_mult < 1.0:
			multiplier_text = " [color=#6B9FFF](Not Very Effective)[/color]"

	# Apply affinity bonus for heroes
	if user and "elemental_affinities" in user:
		var affinity_mult = get_affinity_multiplier(user.elemental_affinities, element)
		if affinity_mult > 1.0:
			final_damage *= affinity_mult
			multiplier_text += " [color=#90EE90](Affinity Bonus)[/color]"

	return {
		"damage": final_damage,
		"multiplier_text": multiplier_text
	}
