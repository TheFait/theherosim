class_name Floor

var num_rooms = 0
var monster_type = ""
var current_room = 1
var all_rooms = []
var narrative_room_index = -1  # Index of the narrative room (-1 if none)

func _init(rooms:int, type:String):
	num_rooms = rooms
	monster_type = type
	current_room = 0

	# Randomly decide if this floor has a narrative room (50% chance)
	if randf() < 0.5:
		narrative_room_index = randi() % num_rooms

	for i in num_rooms:
		var room = Room.new(randi()%3+2)
		all_rooms.append(room)

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
