extends Node2D
@onready var back_button: Button = $Panel/Back_button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	back_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_reload_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_back_button_pressed() -> void:
	get_tree().paused = false
	queue_free()
	


func _on_exit_button_pressed() -> void:
	get_tree().quit()
