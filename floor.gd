class_name Floor

var num_rooms = 0
var monster_family = ""  # All monsters on this floor belong to this family
var current_room = 0
var all_rooms = []
var narrative_room_index = -1  # Index of the narrative room (-1 if none)

func _init(rooms: int, family: String):
	num_rooms = rooms
	monster_family = family
	current_room = 0

	# Randomly decide if this floor has a narrative room (50% chance)
	if randf() < 0.5:
		narrative_room_index = randi() % num_rooms

	for i in num_rooms:
		var room = Room.new(randi() % 3 + 2)
		all_rooms.append(room)

## Get room progression as a value from 0.0 (first room) to 1.0 (last room)
func get_room_progression() -> float:
	if num_rooms <= 1:
		return 0.0
	return float(current_room) / float(num_rooms - 1)

func hasNextRoom() -> bool:
	if current_room < num_rooms:
		return true
	else:
		return false

func getNextRoom() -> int:
	return all_rooms[current_room].num_monsters

func clearRoom():
	current_room += 1

func is_current_room_narrative() -> bool:
	"""Check if the current room is a narrative room"""
	return narrative_room_index >= 0 and current_room == narrative_room_index
