class_name Combatant extends Node2D

@export var health := 0
@export var power := 0
@export var agility := 0
@export var resilience := 0
@export var willpower := 0
@export var player_name := ""
@export var abilities := []



func take_damage(amount):
	pass
	#stats["Health"] = max(0, stats["Health"] - amount)
	#if stats["Health"] == 0:
		#is_dead = true

func choose_ability():
	return abilities[randi() % abilities.size()]

func choose_target(allies, enemies, target_type):
	pass
	#var pool = []
	#if target_type == "enemy_single":
		#pool = enemies.filter(lambda e: !e.is_dead)
	#elif target_type == "ally_single":
		#pool = allies.filter(lambda a: !a.is_dead)
	#elif target_type == "enemy_all":
		#return enemies.filter(lambda e: !e.is_dead)
	#elif target_type == "ally_all":
		#return allies.filter(lambda a: !a.is_dead)
#
	#if pool.size() > 0:
		#return [pool[randi() % pool.size()]]
	#return []
