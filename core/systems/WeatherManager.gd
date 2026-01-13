extends Node

## WeatherManager - Singleton for managing weather conditions
## This is an autoload singleton - access via WeatherManager global
## Handles weather selection and provides current weather information

const DataLoader = preload("res://data/loaders/DataLoader.gd")
const Weather = preload("res://core/systems/Weather.gd")

const WEATHER_PATH = "res://data/weather.json"

# Data stores
var weather_data = {}  # weather_id -> weather definition
var weather_list = []  # Array of all weather IDs for random selection

# Current active weather
var current_weather: Weather = null

func _ready():
	load_data()
	# Start with clear weather
	set_weather("clear")

func load_data():
	# Load weather definitions
	var weather_array = DataLoader.load_json(WEATHER_PATH)
	for weather_def in weather_array:
		weather_data[weather_def["id"]] = weather_def
		# Don't store in simple list anymore - we'll use weights

## Set weather by ID
func set_weather(weather_id: String):
	if not weather_data.has(weather_id):
		push_error("WeatherManager: Weather ID not found: " + weather_id)
		weather_id = "clear"

	current_weather = Weather.new(weather_data[weather_id])
	EventBus.combat_log_entry.emit("Weather changed to: %s" % current_weather.weather_name)

## Get random weather using weighted selection
func roll_random_weather() -> String:
	if weather_data.is_empty():
		return "clear"

	# Calculate total weight
	var total_weight = 0
	for weather_id in weather_data.keys():
		var weight = weather_data[weather_id].get("weight", 1)
		total_weight += int(weight)

	# Roll for weather
	var roll = randi() % total_weight
	var cumulative_weight = 0

	for weather_id in weather_data.keys():
		var weight = weather_data[weather_id].get("weight", 1)
		cumulative_weight += weight
		if roll < cumulative_weight:
			return weather_id

	# Fallback
	return "clear"

## Get current weather (never null)
func get_current_weather() -> Weather:
	if current_weather == null:
		set_weather("clear")
	return current_weather

## Get accuracy modifier from current weather
func get_accuracy_modifier() -> int:
	if current_weather == null:
		return 0
	return current_weather.get_accuracy_modifier()

## Check if should slip on attack (Rain)
func should_slip_on_attack() -> bool:
	if current_weather == null:
		return false
	return current_weather.should_slip_on_attack()

## Try Blood Moon healing
func try_blood_moon_heal(all_combatants: Array) -> Dictionary:
	if current_weather == null:
		return {"triggered": false, "target": null, "amount": 0}
	return current_weather.try_blood_moon_heal(all_combatants)

## Try Lunar Eclipse exp boost
func try_lunar_exp_boost(heroes: Array) -> Dictionary:
	if current_weather == null:
		return {"triggered": false, "target": null, "amount": 0}
	return current_weather.try_lunar_exp_boost(heroes)

## Get weather display text
func get_weather_display() -> String:
	if current_weather == null:
		return "Clear"
	return current_weather.weather_name

## Get weather description
func get_weather_description() -> String:
	if current_weather == null:
		return "Clear skies."
	return current_weather.description

## Check if current weather has particle effect
func has_particle_effect() -> bool:
	if current_weather == null:
		return false
	return current_weather.has_particle_effect()

## Get particle effect name for current weather
func get_particle_effect() -> String:
	if current_weather == null:
		return ""
	return current_weather.particle_effect
