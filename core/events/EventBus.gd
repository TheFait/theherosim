extends Node

## Central event dispatcher for HeroSim combat system
## This is an autoload singleton - access via EventBus global
## Implements Observer pattern to decouple business logic from UI and statistics

# Combat log events
signal combat_log_entry(text: String)

# Damage and healing events
signal combatant_damaged(attacker, target, damage: float, actual_damage: float)
signal combatant_healed(healer, target, amount: float)
signal combatant_died(deceased, killer)

# Status effect events
signal status_effect_applied(target, effect)
signal status_effect_expired(target, effect_name: String)

# Ability events
signal ability_used(user, ability: Dictionary, targets: Array)

# Experience and progression events
signal experience_gained(hero, amount: int)
signal level_up(hero, new_level: int)
signal ability_level_up(hero, ability_name: String, new_level: int)

# Battle state events
signal battle_state_changed()
signal battle_started(heroes: Array, monsters: Array)
signal battle_ended(winner: String)
signal turn_started(combatant)
signal turn_ended(combatant)
signal round_started(round_number: int)
signal round_ended(round_number: int)

# Room and floor events
signal room_cleared(floor_number: int, room_number: int)
signal floor_cleared(floor_number: int)
