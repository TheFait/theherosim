extends Node

## Performance optimization layer for combatant management
## This is an autoload singleton - access via CombatantCache global
## Caches alive combatants and provides O(1) lookups instead of O(n) filtering

var heroes: Array = []
var monsters: Array = []
var all_combatants: Array = []

# Cached alive arrays (rebuilt only on death events)
var alive_heroes: Array = []
var alive_monsters: Array = []

# Fast team membership lookup (O(1) instead of O(n) array.has())
var combatant_to_team: Dictionary = {}  # combatant -> "hero" or "monster"

var _initialized: bool = false

func _ready():
	# Listen for death events to invalidate cache
	EventBus.combatant_died.connect(_on_combatant_died)

func initialize(hero_list: Array, monster_list: Array):
	heroes = hero_list
	monsters = monster_list
	all_combatants = heroes + monsters

	# Build team lookup table
	combatant_to_team.clear()
	for hero in heroes:
		combatant_to_team[hero] = "hero"
	for monster in monsters:
		combatant_to_team[monster] = "monster"

	# Build alive caches
	_rebuild_caches()

	_initialized = true
	print("CombatantCache initialized: %d heroes, %d monsters" % [heroes.size(), monsters.size()])

func get_alive_combatants() -> Array:
	return alive_heroes + alive_monsters

func get_alive_heroes() -> Array:
	return alive_heroes

func get_alive_monsters() -> Array:
	return alive_monsters

func get_team(combatant) -> Array:
	var team_type = combatant_to_team.get(combatant, "")
	if team_type == "hero":
		return heroes
	elif team_type == "monster":
		return monsters
	else:
		push_warning("CombatantCache: Unknown combatant team")
		return []

func get_enemy_team(combatant) -> Array:
	var team_type = combatant_to_team.get(combatant, "")
	if team_type == "hero":
		return monsters
	elif team_type == "monster":
		return heroes
	else:
		push_warning("CombatantCache: Unknown combatant team")
		return []

func get_alive_allies(combatant) -> Array:
	var team_type = combatant_to_team.get(combatant, "")
	if team_type == "hero":
		return alive_heroes
	elif team_type == "monster":
		return alive_monsters
	else:
		return []

func get_alive_enemies(combatant) -> Array:
	var team_type = combatant_to_team.get(combatant, "")
	if team_type == "hero":
		return alive_monsters
	elif team_type == "monster":
		return alive_heroes
	else:
		return []

func are_all_dead(team: Array) -> bool:
	for combatant in team:
		if not combatant.is_dead:
			return false
	return true

func is_hero(combatant) -> bool:
	return combatant_to_team.get(combatant, "") == "hero"

func is_monster(combatant) -> bool:
	return combatant_to_team.get(combatant, "") == "monster"

func _on_combatant_died(deceased, killer):
	_rebuild_caches()
	# Emit battle state changed to trigger UI update
	EventBus.battle_state_changed.emit()

func _rebuild_caches():
	alive_heroes = heroes.filter(func(c): return not c.is_dead)
	alive_monsters = monsters.filter(func(c): return not c.is_dead)
