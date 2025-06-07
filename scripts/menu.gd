extends Node2D

@onready var back_button: Button = $Panel/Back_button
@onready var current_score: Label = $Control/Current_Score
@onready var reload_button: Button = $Panel/ReloadButton  # Add if you have one
@onready var exit_button: Button = $Panel/ExitButton    # Add if you have one

var current_game_score: int = 0

func _ready() -> void:
	# Set process modes for pause menu functionality
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	back_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	current_score.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Set process mode for other buttons if they exist
	if reload_button:
		reload_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if exit_button:
		exit_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Get current score from the game scene
	get_current_score_from_game()
	update_score_display()
	
	# Connect button signals
	back_button.pressed.connect(_on_back_button_pressed)
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)

func get_current_score_from_game():
	# Try to get the current score from the game scene
	var game_scene = get_tree().get_first_node_in_group("Game")
	if not game_scene:
		# Alternative: try to find game scene by path
		game_scene = get_node_or_null("/root/Game")
	
	if game_scene and game_scene.has_method("get_current_score"):
		current_game_score = game_scene.get_current_score()
	elif game_scene and "current_score" in game_scene:
		current_game_score = game_scene.current_score
	else:
		# Fallback: try to get from GameData singleton if it exists
		if GameData and "current_score" in GameData:
			current_game_score = GameData.current_score
		else:
			current_game_score = 0
			print("Warning: Could not retrieve current score")

func update_score_display():
	if current_score:
		current_score.text = "Current Score: %d" % current_game_score

func _on_reload_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_back_button_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

# If you want to update the score periodically while menu is open
func _on_timer_timeout() -> void:
	get_current_score_from_game()
	update_score_display()
