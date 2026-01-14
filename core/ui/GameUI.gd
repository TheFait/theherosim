extends Node

## GameUI - Manages all game UI with delta updates
## Uses caching to avoid full UI rebuilds

# Monster family colors for display
const MONSTER_COLORS = {
	"Goblin": "#90EE90",
	"Orc": "#CD5C5C",
	"Wolf": "#87CEEB",
	"Dragon": "#9370DB"
}

# UI element cache for delta updates
var _ui_cache: Dictionary = {}  # Stores references to UI nodes by combatant ID

# UI references (set by GameController)
var combatants_list: VBoxContainer  # Heroes panel
var monsters_list: VBoxContainer     # Monsters panel
var floor_label: Label
var room_label: Label
var weather_label: Label

# State tracking
var _current_turn_combatant = null
var _heroes: Array = []
var _monsters: Array = []

## Initialize UI manager with references
func setup(ui_refs: Dictionary):
	combatants_list = ui_refs.get("combatants_list")
	monsters_list = ui_refs.get("monsters_list")
	floor_label = ui_refs.get("floor_label")
	room_label = ui_refs.get("room_label")
	weather_label = ui_refs.get("weather_label")

## Full rebuild of combatants display (used on initialization)
func rebuild_combatants_display(heroes: Array, monsters: Array, current_turn: Variant):
	_heroes = heroes
	_monsters = monsters
	_current_turn_combatant = current_turn
	_ui_cache.clear()

	# Clear existing UI in both panels
	if combatants_list:
		for child in combatants_list.get_children():
			child.queue_free()

	if monsters_list:
		for child in monsters_list.get_children():
			child.queue_free()

	# Build heroes section in CombatantsPanel
	if combatants_list:
		var heroes_header = Label.new()
		heroes_header.text = "HEROES"
		heroes_header.add_theme_font_size_override("font_size", 16)
		heroes_header.name = "HeroesHeader"
		combatants_list.add_child(heroes_header)

		for hero in heroes:
			_create_combatant_ui(hero, true)

	# Build monsters section in MonstersPanel
	if monsters_list:
		var monsters_header = Label.new()
		monsters_header.text = "MONSTERS"
		monsters_header.add_theme_font_size_override("font_size", 16)
		monsters_header.name = "MonstersHeader"
		monsters_list.add_child(monsters_header)

		for monster in monsters:
			_create_combatant_ui(monster, false)

## Delta update - only update changing parts
func update_combatants_display(heroes: Array, monsters: Array, current_turn: Variant):
	"""
	Performs delta updates to UI - only updates:
	- Health bars
	- Status effects
	- Current turn indicator
	"""
	_heroes = heroes
	_monsters = monsters
	var previous_turn = _current_turn_combatant
	_current_turn_combatant = current_turn

	# Update all combatants
	for hero in heroes:
		_update_combatant_ui(hero)

	for monster in monsters:
		_update_combatant_ui(monster)

	# Update turn indicators if changed
	if previous_turn != current_turn:
		if previous_turn and _ui_cache.has(_get_combatant_id(previous_turn)):
			_update_turn_indicator(_ui_cache[_get_combatant_id(previous_turn)]["container"], false)
		if current_turn and _ui_cache.has(_get_combatant_id(current_turn)):
			_update_turn_indicator(_ui_cache[_get_combatant_id(current_turn)]["container"], true)

## Create UI for a combatant (initial creation)
func _create_combatant_ui(combatant, is_hero: bool):
	var combatant_id = _get_combatant_id(combatant)
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)
	container.name = combatant_id

	# Add tooltip for heroes
	if is_hero:
		container.tooltip_text = _generate_hero_tooltip(combatant)
		container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Name container with turn indicator
	var name_container = HBoxContainer.new()
	name_container.name = "NameContainer"

	# Turn indicator arrow
	var arrow_label = Label.new()
	arrow_label.text = ""
	arrow_label.name = "TurnArrow"
	arrow_label.add_theme_font_size_override("font_size", 14)
	if combatant == _current_turn_combatant:
		arrow_label.text = "► "
		arrow_label.modulate = Color(0.2, 1.0, 0.2)
	name_container.add_child(arrow_label)

	# Name label with level for heroes
	var name_label = Label.new()
	if is_hero:
		name_label.text = "Lv. %d %s" % [combatant.stats.get("Level", 1), combatant.combatant_name]
	else:
		name_label.text = combatant.combatant_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.name = "NameLabel"

	# Colorize monsters by family
	if not is_hero and "family_name" in combatant:
		var family_color = MONSTER_COLORS.get(combatant.family_name, "#FFFFFF")
		name_label.set("theme_override_colors/font_color", Color(family_color))

	# Gray out if dead
	if combatant.is_dead:
		name_label.modulate = Color(0.5, 0.5, 0.5)

	name_container.add_child(name_label)
	container.add_child(name_container)

	# Health bar
	var health_container = _create_health_bar(combatant)
	health_container.name = "HealthContainer"
	container.add_child(health_container)

	# EXP bar for heroes only
	var exp_container = null
	if is_hero:
		exp_container = _create_exp_bar(combatant)
		exp_container.name = "ExpContainer"
		container.add_child(exp_container)

	# Status effects
	var status_container = _create_status_effects_ui(combatant)
	status_container.name = "StatusContainer"
	container.add_child(status_container)

	# Add to the correct panel
	if is_hero and combatants_list:
		combatants_list.add_child(container)
	elif not is_hero and monsters_list:
		monsters_list.add_child(container)

	# Cache UI references
	_ui_cache[combatant_id] = {
		"container": container,
		"arrow": arrow_label,
		"name": name_label,
		"health_container": health_container,
		"exp_container": exp_container,
		"status_container": status_container,
		"is_hero": is_hero,
		"last_health": combatant.stats["Health"],
		"last_max_health": combatant.stats.get("MaxHealth", 100),
		"last_exp": combatant.stats.get("CurrentEXP", 0) if is_hero else 0,
		"last_status_count": combatant.status_effects.size()
	}

## Update existing combatant UI (delta update)
func _update_combatant_ui(combatant):
	var combatant_id = _get_combatant_id(combatant)

	if not _ui_cache.has(combatant_id):
		return  # Combatant not in cache, skip

	var cache = _ui_cache[combatant_id]
	var current_health = combatant.stats["Health"]
	var current_max_health = combatant.stats.get("MaxHealth", 100)
	var current_status_count = combatant.status_effects.size()

	# Update health bar if changed
	if cache["last_health"] != current_health or cache["last_max_health"] != current_max_health:
		_update_health_bar(cache["health_container"], combatant)
		cache["last_health"] = current_health
		cache["last_max_health"] = current_max_health

	# Update EXP bar for heroes if changed
	if cache.get("is_hero", false) and cache.get("exp_container"):
		var current_exp = combatant.stats.get("CurrentEXP", 0)
		if cache["last_exp"] != current_exp:
			_update_exp_bar(cache["exp_container"], combatant)
			cache["last_exp"] = current_exp

	# Update status effects if changed
	if cache["last_status_count"] != current_status_count:
		_update_status_effects_ui(cache["status_container"], combatant)
		cache["last_status_count"] = current_status_count

	# Update tooltip for heroes (always update to show latest stats)
	if cache.get("is_hero", false):
		cache["container"].tooltip_text = _generate_hero_tooltip(combatant)

## Create health bar UI
func _create_health_bar(combatant) -> HBoxContainer:
	var container = HBoxContainer.new()

	var health_bg = ProgressBar.new()
	health_bg.custom_minimum_size = Vector2(175, 20)
	health_bg.show_percentage = false

	var current_health = combatant.stats["Health"]
	var max_health = combatant.stats.get("MaxHealth", 100)

	health_bg.max_value = max_health
	health_bg.value = current_health

	# Color based on health percentage
	var health_percent = float(current_health) / float(max_health) if max_health > 0 else 0
	var bar_color = Color(0, 1, 0) if health_percent > 0.66 else (Color(1, 1, 0) if health_percent > 0.33 else Color(1, 0, 0))

	var style = StyleBoxFlat.new()
	style.bg_color = bar_color
	health_bg.add_theme_stylebox_override("fill", style)
	health_bg.name = "HealthBar"

	container.add_child(health_bg)

	var health_label = Label.new()
	health_label.text = " %d/%d" % [current_health, max_health]
	health_label.custom_minimum_size = Vector2(70, 0)
	health_label.name = "HealthLabel"
	container.add_child(health_label)

	return container

## Update health bar (delta update)
func _update_health_bar(health_container: HBoxContainer, combatant):
	var health_bar = health_container.get_node("HealthBar") as ProgressBar
	var health_label = health_container.get_node("HealthLabel") as Label

	if not health_bar or not health_label:
		return

	var current_health = combatant.stats["Health"]
	var max_health = combatant.stats.get("MaxHealth", 100)

	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = " %d/%d" % [current_health, max_health]

	# Update color
	var health_percent = float(current_health) / float(max_health) if max_health > 0 else 0
	var bar_color = Color(0, 1, 0) if health_percent > 0.66 else (Color(1, 1, 0) if health_percent > 0.33 else Color(1, 0, 0))

	var style = StyleBoxFlat.new()
	style.bg_color = bar_color
	health_bar.add_theme_stylebox_override("fill", style)

## Create EXP bar UI (heroes only)
func _create_exp_bar(combatant) -> HBoxContainer:
	var container = HBoxContainer.new()

	var exp_label = Label.new()
	exp_label.text = "EXP:"
	exp_label.custom_minimum_size = Vector2(30, 0)
	exp_label.add_theme_font_size_override("font_size", 12)
	container.add_child(exp_label)

	var exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(145, 16)
	exp_bar.show_percentage = false

	var current_exp = combatant.stats.get("CurrentEXP", 0)
	var exp_to_next = combatant.stats.get("EXPToNextLevel", 100)

	exp_bar.max_value = exp_to_next
	exp_bar.value = current_exp

	# Blue color for EXP bar
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 1.0)
	exp_bar.add_theme_stylebox_override("fill", style)
	exp_bar.name = "ExpBar"

	container.add_child(exp_bar)

	var exp_value_label = Label.new()
	exp_value_label.text = " %d/%d" % [current_exp, exp_to_next]
	exp_value_label.custom_minimum_size = Vector2(70, 0)
	exp_value_label.add_theme_font_size_override("font_size", 12)
	exp_value_label.name = "ExpLabel"
	container.add_child(exp_value_label)

	return container

## Update EXP bar (delta update)
func _update_exp_bar(exp_container: HBoxContainer, combatant):
	if not exp_container:
		return

	var exp_bar = exp_container.get_node("ExpBar") as ProgressBar
	var exp_label = exp_container.get_node("ExpLabel") as Label

	if not exp_bar or not exp_label:
		return

	var current_exp = combatant.stats.get("CurrentEXP", 0)
	var exp_to_next = combatant.stats.get("EXPToNextLevel", 100)

	exp_bar.max_value = exp_to_next
	exp_bar.value = current_exp
	exp_label.text = " %d/%d" % [current_exp, exp_to_next]

## Create status effects UI
func _create_status_effects_ui(combatant) -> Label:
	var status_label = Label.new()
	status_label.text = ""

	if not combatant.status_effects.is_empty():
		var status_texts = []
		for effect in combatant.status_effects:
			status_texts.append(effect.get_display_text())
		status_label.text = "  Status: " + ", ".join(status_texts)

	status_label.add_theme_font_size_override("font_size", 12)
	status_label.set("theme_override_colors/font_color", Color(0.8, 0.8, 0.8))

	return status_label

## Update status effects UI (delta update)
func _update_status_effects_ui(status_container: Label, combatant):
	if not combatant.status_effects.is_empty():
		var status_texts = []
		for effect in combatant.status_effects:
			status_texts.append(effect.get_display_text())
		status_container.text = "  Status: " + ", ".join(status_texts)
	else:
		status_container.text = ""

## Update turn indicator
func _update_turn_indicator(container: VBoxContainer, is_current_turn: bool):
	var name_container = container.get_node("NameContainer") as HBoxContainer
	if not name_container:
		return

	var arrow = name_container.get_node("TurnArrow") as Label
	if arrow:
		arrow.text = "► " if is_current_turn else ""

## Get unique ID for combatant
func _get_combatant_id(combatant) -> String:
	if combatant and "combatant_name" in combatant:
		return "combatant_" + combatant.combatant_name + "_" + str(combatant.get_instance_id())
	return "combatant_" + str(combatant.get_instance_id()) if combatant else "unknown"

## Generate tooltip for hero
func _generate_hero_tooltip(hero) -> String:
	return StatsTracker.generate_tooltip(hero)

## Update floor/room display
func update_floor_room_display(floor_num: int, room_num: int):
	if floor_label:
		floor_label.text = "Floor: %d" % floor_num
	if room_label:
		room_label.text = "Room: %d" % room_num

## Update weather display
func update_weather_display(weather_name: String):
	if weather_label:
		var icon = WeatherManager.get_weather_icon()
		weather_label.text = "%s Weather: %s" % [icon, weather_name]

## Generate colored combatant name for logs
func colorize_combatant_name(combatant, is_hero: bool) -> String:
	var color = "#90EE90" if is_hero else "#FFB6C1"
	return "[color=%s]%s[/color]" % [color, combatant.combatant_name]
