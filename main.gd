extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Label.text = "Hello World"
	$Label.modulate = Color.AQUAMARINE


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("run_sim"):
		print("Starting Sim")
