class_name Floor

var num_rooms = 0
var monster_type = ""
var current_room = 1
var all_rooms = []

func _init(rooms:int, type:String):
	num_rooms = rooms
	monster_type = type
	current_room = 0
	
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
