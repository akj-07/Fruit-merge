extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_reload_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()



func _on_back_button_pressed() -> void:
	pass # Replace with function body.
	get_tree
