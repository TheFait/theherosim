class_name StatusEffects

# Base status effect class
class StatusEffect:
	var effect_name: String = ""
	var duration: int = 0  # Turns remaining
	var stacks: int = 1
	var icon: String = ""  # For future UI

	# Called when effect is first applied
	func on_apply(target):
		pass

	# Called at the start of the target's turn
	func on_turn_start(target):
		duration -= 1

	# Called at the end of the target's turn
	func on_turn_end(target):
		pass

	# Called when taking damage
	func on_damage_taken(target, damage: float) -> float:
		return damage

	# Called when dealing damage
	func on_damage_dealt(target, damage: float) -> float:
		return damage

	# Returns true if effect should be removed
	func is_expired() -> bool:
		return duration <= 0

	# Get display text for UI
	func get_display_text() -> String:
		if stacks > 1:
			return "%s (%d) [%d]" % [effect_name, stacks, duration]
		return "%s [%d]" % [effect_name, duration]

# Regeneration - Healing over time
class Regeneration extends StatusEffect:
	var heal_amount: float = 5.0

	func _init(heal: float = 5.0, turns: int = 3):
		effect_name = "Regeneration"
		heal_amount = heal
		duration = turns
		icon = "♥"

	func on_turn_start(target):
		# Heal at start of turn
		var old_health = target.stats["Health"]
		target.stats["Health"] = min(target.stats["Health"] + heal_amount, target.stats["MaxHealth"])
		var actual_heal = target.stats["Health"] - old_health

		if actual_heal > 0:
			EventBus.combat_log_entry.emit("%s regenerates %d health" % [target.combatant_name, int(actual_heal)])

		super.on_turn_start(target)

	func get_display_text() -> String:
		return "Regen +%d [%d]" % [int(heal_amount), duration]

# Poison - Damage over time
class Poison extends StatusEffect:
	var damage_amount: float = 5.0

	func _init(damage: float = 5.0, turns: int = 3):
		effect_name = "Poison"
		damage_amount = damage
		duration = turns
		icon = "☠"

	func on_turn_start(target):
		# Deal damage at start of turn
		var result = target.take_damage(damage_amount)
		var actual_damage = result["actual_damage"]

		EventBus.combat_log_entry.emit("%s takes %d poison damage" % [target.combatant_name, int(actual_damage)])

		if result["died"]:
			EventBus.combat_log_entry.emit("[bgcolor=#8B0000][color=#FFFFFF]%s has died from poison![/color][/bgcolor]" % target.combatant_name)
			EventBus.combatant_died.emit(target, null)  # No killer for poison deaths

		super.on_turn_start(target)

	func get_display_text() -> String:
		return "Poison -%d [%d]" % [int(damage_amount), duration]

# Shield - Reduces incoming damage
class Shield extends StatusEffect:
	var damage_reduction: float = 5.0
	var total_absorbed: float = 0.0

	func _init(reduction: float = 5.0, turns: int = 3):
		effect_name = "Shield"
		damage_reduction = reduction
		duration = turns
		icon = "🛡"

	func on_damage_taken(target, damage: float) -> float:
		if damage <= 0:  # Don't affect healing
			return damage

		var reduced = max(0, damage - damage_reduction)
		var absorbed = damage - reduced
		total_absorbed += absorbed

		if absorbed > 0:
			EventBus.combat_log_entry.emit("%s's shield absorbs %d damage" % [target.combatant_name, int(absorbed)])

		return reduced

	func get_display_text() -> String:
		return "Shield -%d [%d]" % [int(damage_reduction), duration]

# Stun - Skip next turn
class Stun extends StatusEffect:
	var skipped_turn: bool = false

	func _init(turns: int = 1):
		effect_name = "Stun"
		duration = turns
		icon = "💫"
		skipped_turn = false

	func should_skip_turn() -> bool:
		return !skipped_turn

	func on_turn_start(target):
		if !skipped_turn:
			EventBus.combat_log_entry.emit("%s is stunned and cannot act!" % target.combatant_name)
			skipped_turn = true

		super.on_turn_start(target)

	func get_display_text() -> String:
		return "Stunned [%d]" % duration

# Factory function to create status effects by name
static func create_effect(effect_type: String, params: Dictionary = {}):
	match effect_type:
		"Regeneration":
			var heal = params.get("heal", 5.0)
			var turns = params.get("turns", 3)
			return Regeneration.new(heal, turns)
		"Poison":
			var damage = params.get("damage", 5.0)
			var turns = params.get("turns", 3)
			return Poison.new(damage, turns)
		"Shield":
			var reduction = params.get("reduction", 5.0)
			var turns = params.get("turns", 3)
			return Shield.new(reduction, turns)
		"Stun":
			var turns = params.get("turns", 1)
			return Stun.new(turns)
		_:
			push_error("Unknown status effect type: " + effect_type)
			return null
