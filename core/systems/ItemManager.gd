extends Node

## ItemManager - Singleton for managing items, loot, and treasure packages
## Handles item creation, level progression, loot rolling, and item effects

const DataLoader = preload("res://data/loaders/DataLoader.gd")

const ITEMS_PATH = "res://data/items.json"
const TREASURE_PACKAGES_PATH = "res://data/treasure_packages.json"
const LOOT_CONFIG_PATH = "res://data/loot_config.json"
const LOOT_ROOM_MESSAGES_PATH = "res://data/loot_room_messages.json"

# Data stores
var items_data = {}  # item_id -> item definition
var treasure_packages = {}  # package_id -> treasure package definition
var loot_config = {}
var loot_room_messages = {}  # item_found and item_not_found message arrays

# Rarity colors for UI display
const RARITY_COLORS = {
	"Common": "#FFFFFF",
	"Uncommon": "#1EFF00",
	"Rare": "#0070DD",
	"Epic": "#A335EE",
	"Legendary": "#FF8000"
}

func _ready():
	load_data()

func load_data():
	# Load items
	var items_array = DataLoader.load_json(ITEMS_PATH)
	for item in items_array:
		items_data[item["id"]] = item

	# Load treasure packages
	var packages_array = DataLoader.load_json(TREASURE_PACKAGES_PATH)
	for package in packages_array:
		treasure_packages[package["id"]] = package

	# Load loot configuration
	loot_config = DataLoader.load_json(LOOT_CONFIG_PATH)

	# Load loot room messages
	loot_room_messages = DataLoader.load_json(LOOT_ROOM_MESSAGES_PATH)

## Create a new item instance with level tracking
## Returns a dictionary with item data + current_level and current_exp
func create_item(item_id: String) -> Dictionary:
	if not items_data.has(item_id):
		push_error("ItemManager: Item ID not found: " + item_id)
		return {}

	var item_def = items_data[item_id].duplicate(true)
	var item_instance = {
		"id": item_def["id"],
		"name": item_def["name"],
		"rarity": item_def["rarity"],
		"type": item_def["type"],
		"stats": item_def["stats"].duplicate(true),
		"max_level": item_def["max_level"],
		"effect": item_def.get("effect", null),
		"current_level": 1,
		"current_exp": 0
	}

	return item_instance

## Calculate experience required for next level
func get_exp_for_next_level(current_level: int) -> int:
	var base_exp = loot_config.get("item_exp_per_level", 100)
	var scaling = loot_config.get("item_exp_scaling", 1.5)
	return int(base_exp * pow(scaling, current_level - 1))

## Add experience to an item and level it up if enough exp
## Returns true if item leveled up
func add_item_exp(item: Dictionary, exp: int) -> bool:
	if item["current_level"] >= item["max_level"]:
		return false

	item["current_exp"] += exp
	var exp_needed = get_exp_for_next_level(item["current_level"])

	if item["current_exp"] >= exp_needed:
		item["current_exp"] -= exp_needed
		item["current_level"] += 1
		# Scale stats by 10% per level
		scale_item_stats(item, 1.1)
		return true

	return false

## Scale all stats in an item by a multiplier
func scale_item_stats(item: Dictionary, multiplier: float):
	for stat_name in item["stats"].keys():
		item["stats"][stat_name] = int(item["stats"][stat_name] * multiplier)

## Roll for loot from a treasure package
## Returns array of item_ids (can be empty if drop chance fails)
func roll_treasure_package(package_id: String) -> Array:
	if not treasure_packages.has(package_id):
		push_error("ItemManager: Treasure package not found: " + package_id)
		return []

	var package = treasure_packages[package_id]
	var drop_chance = package.get("drop_chance", 1.0)

	# Roll for drop chance first
	if randf() >= drop_chance:
		return []  # No loot dropped

	var items_dropped = []
	var treasure_specs = package.get("treasure_specs", [])

	# Roll for each treasure spec
	for spec in treasure_specs:
		var items_list = spec.get("items", [])
		if items_list.is_empty():
			continue

		# Calculate total weight for this spec
		var total_weight = 0
		for item_entry in items_list:
			total_weight += int(item_entry["weight"])

		# Roll for item from this spec
		var roll = randi() % total_weight
		var cumulative_weight = 0

		for item_entry in items_list:
			cumulative_weight += int(item_entry["weight"])
			if roll < cumulative_weight:
				items_dropped.append(item_entry["item_id"])
				break

	return items_dropped

## Get number of item slots players can have
func get_player_item_slots() -> int:
	return loot_config.get("player_item_slots", 4)

## Get chance for item drop in loot room
func get_loot_room_item_chance() -> float:
	return loot_config.get("loot_room_item_chance", 0.7)

## Get resurrection chance in loot room
func get_loot_room_resurrection_chance() -> float:
	return loot_config.get("loot_room_resurrection_chance", 0.05)

## Get resurrection health percent
func get_loot_room_resurrection_health_percent() -> float:
	return loot_config.get("loot_room_resurrection_health_percent", 0.5)

## Get loot room display duration
func get_loot_room_display_duration() -> float:
	return loot_config.get("loot_room_display_duration", 5.0)

## Get colored item name for display
func get_colored_item_name(item: Dictionary) -> String:
	var color = RARITY_COLORS.get(item["rarity"], "#FFFFFF")
	return "[color=%s]%s[/color]" % [color, item["name"]]

## Generate tooltip text for an item
func generate_item_tooltip(item: Dictionary) -> String:
	var tooltip = "%s\n" % item["name"]
	tooltip += "Type: %s | Rarity: %s\n" % [item["type"], item["rarity"]]
	tooltip += "Level: %d / %d\n" % [item["current_level"], item["max_level"]]

	if item["current_level"] < item["max_level"]:
		var exp_needed = get_exp_for_next_level(item["current_level"])
		tooltip += "EXP: %d / %d\n" % [item["current_exp"], exp_needed]
	else:
		tooltip += "MAX LEVEL\n"

	tooltip += "\nStats:\n"
	for stat_name in item["stats"].keys():
		tooltip += "  %s: +%d\n" % [stat_name, item["stats"][stat_name]]

	if item.has("effect") and item["effect"] != null:
		tooltip += "\nEffect: %s" % item["effect"]

	return tooltip

## Get a random "item found" message with placeholders replaced
func get_item_found_message(hero_name: String, item: Dictionary) -> String:
	var messages = loot_room_messages.get("item_found", ["<hero> found <item>!"])
	if messages.is_empty():
		return "%s found %s!" % [hero_name, item["name"]]

	var template = messages[randi() % messages.size()]
	var message = template.replace("<hero>", hero_name)
	message = message.replace("<item>", item["name"])
	message = message.replace("<rarity>", item["rarity"])

	return message

## Get a random "item not found" message with placeholders replaced
func get_item_not_found_message(hero_name: String) -> String:
	var messages = loot_room_messages.get("item_not_found", ["<hero> found nothing."])
	if messages.is_empty():
		return "%s found nothing." % hero_name

	var template = messages[randi() % messages.size()]
	var message = template.replace("<hero>", hero_name)

	return message
