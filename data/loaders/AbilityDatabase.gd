extends Node

## Indexed ability and monster family database for O(1) lookups
## This is an autoload singleton - access via AbilityDatabase global
## Replaces O(n) and O(n²) searches throughout the codebase

const DataLoader = preload("res://data/loaders/DataLoader.gd")
const ABILITY_PATH = "res://data/abilities.json"
const MONSTER_ABILITY_PATH = "res://data/monster_abilities.json"
const MONSTER_FAMILY_PATH = "res://data/monster_families.json"

# Indexed lookups (O(1) access)
var abilities_by_name: Dictionary = {}  # "Fireball" -> ability dict
var monster_abilities_by_name: Dictionary = {}  # "Goblin Stab" -> ability dict
var families_by_name: Dictionary = {}  # "Goblin" -> family dict

# Original arrays (for iteration if needed)
var abilities: Array = []
var monster_abilities: Array = []
var families: Array = []

var _loaded: bool = false

func _ready():
	load_data()

func load_data():
	if _loaded:
		return

	# Load abilities
	abilities = DataLoader.load_json(ABILITY_PATH)
	for ability in abilities:
		abilities_by_name[ability["name"]] = ability

	# Load monster abilities
	monster_abilities = DataLoader.load_json(MONSTER_ABILITY_PATH)
	for ability in monster_abilities:
		monster_abilities_by_name[ability["name"]] = ability

	# Load monster families
	families = DataLoader.load_json(MONSTER_FAMILY_PATH)
	for family in families:
		families_by_name[family["name"]] = family

	_loaded = true
	print("AbilityDatabase loaded: %d abilities, %d monster abilities, %d families" % [
		abilities.size(),
		monster_abilities.size(),
		families.size()
	])

func get_ability(ability_name: String) -> Dictionary:
	return abilities_by_name.get(ability_name, {})

func get_monster_ability(ability_name: String) -> Dictionary:
	return monster_abilities_by_name.get(ability_name, {})

func get_family(family_name: String) -> Dictionary:
	return families_by_name.get(family_name, {})

## Replaces the O(n²) pick_monster_abilities function from main.gd
func get_monster_abilities_for_family(family_name: String) -> Array:
	var family = families_by_name.get(family_name)
	if not family:
		push_warning("AbilityDatabase: Unknown family '%s'" % family_name)
		return []

	var result = []
	for ability_name in family.get("abilities", []):
		var ability = monster_abilities_by_name.get(ability_name)
		if ability:
			result.append(ability)
		else:
			push_warning("AbilityDatabase: Ability '%s' not found for family '%s'" % [ability_name, family_name])

	return result

func get_random_ability() -> Dictionary:
	if abilities.is_empty():
		return {}
	return abilities[randi() % abilities.size()]

func get_random_monster_ability() -> Dictionary:
	if monster_abilities.is_empty():
		return {}
	return monster_abilities[randi() % monster_abilities.size()]
