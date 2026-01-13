extends RefCounted
class_name Weather

## Weather class representing environmental conditions in combat
## Handles weather effects that modify combat behavior

var weather_id: String = ""
var weather_name: String = ""
var effect_type: String = ""
var effect_value: float = 0.0
var description: String = ""
var particle_effect: String = ""

# Additional effect parameters
var slip_chance: float = 0.0
var heal_chance: float = 0.0
var lunar_chance: float = 0.0

func _init(data: Dictionary):
	weather_id = data.get("id", "clear")
	weather_name = data.get("name", "Clear")
	effect_type = data.get("effect_type", "none")
	effect_value = data.get("effect_value", 0.0)
	description = data.get("description", "")
	particle_effect = data.get("particle_effect", "")

	# Load additional parameters based on effect type
	if effect_type == "slip_chance":
		slip_chance = effect_value
	elif effect_type == "blood_heal":
		heal_chance = data.get("heal_chance", 0.01)
	elif effect_type == "lunar_exp":
		lunar_chance = data.get("lunar_chance", 0.01)

## Apply accuracy modifier for fog weather
func get_accuracy_modifier() -> int:
	if effect_type == "accuracy_penalty":
		return int(effect_value)
	return 0

## Check if combatant should slip during attack (Rain weather)
func should_slip_on_attack() -> bool:
	if effect_type == "slip_chance":
		return randf() < slip_chance
	return false

## Try to trigger Blood Moon healing effect
## Returns Dictionary: {"triggered": bool, "target": Combatant or null, "amount": int}
func try_blood_moon_heal(all_combatants: Array) -> Dictionary:
	if effect_type != "blood_heal":
		return {"triggered": false, "target": null, "amount": 0}

	if randf() < heal_chance:
		# Choose random combatant (dead or alive)
		if all_combatants.is_empty():
			return {"triggered": false, "target": null, "amount": 0}

		var target = all_combatants[randi() % all_combatants.size()]
		return {"triggered": true, "target": target, "amount": int(effect_value)}

	return {"triggered": false, "target": null, "amount": 0}

## Try to trigger Lunar Eclipse ability exp effect
## Returns Dictionary: {"triggered": bool, "target": Combatant or null, "amount": int}
func try_lunar_exp_boost(heroes: Array) -> Dictionary:
	if effect_type != "lunar_exp":
		return {"triggered": false, "target": null, "amount": 0}

	# Only apply to alive heroes
	var alive_heroes = heroes.filter(func(h): return not h.is_dead)

	if alive_heroes.is_empty():
		return {"triggered": false, "target": null, "amount": 0}

	if randf() < lunar_chance:
		var target = alive_heroes[randi() % alive_heroes.size()]
		return {"triggered": true, "target": target, "amount": int(effect_value)}

	return {"triggered": false, "target": null, "amount": 0}

## Check if this weather has particle effects
func has_particle_effect() -> bool:
	return particle_effect != null and particle_effect != ""

## Get display string for UI
func get_display_text() -> String:
	return "%s: %s" % [weather_name, description]
