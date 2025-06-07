extends Node2D

@onready var score_label: Label = $Control/ScoreLabel  # Add this to your scene
@onready var high_score_label: Label = $Control/HighScoreLabel  # Add this to your scene
@onready var reload_button: Button = $Control/ReloadButton
@onready var menu_button: Button = $Control/MenuButton
@onready var exit_button: Button = $Control/ExitButton

var final_score: int = 0
var high_score: int = 0

func _ready() -> void:
	# Get final score from GameData singleton
	final_score = GameData.final_score if GameData else 0
	
	# Load and update high score
	load_high_score()
	if final_score > high_score:
		high_score = final_score
		save_high_score()
		# Show "NEW HIGH SCORE!" animation or text
		show_new_high_score()
	
	# Update UI
	update_score_display()
	
	# Connect buttons if they exist
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

func update_score_display():
	if score_label:
		score_label.text = "Final Score: " + str(final_score)
	if high_score_label:
		high_score_label.text = "High Score: " + str(high_score)

func show_new_high_score():
	# Add a celebratory animation or effect
	print("NEW HIGH SCORE!")
	# You can add tween animations, particle effects, etc. here

func load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		high_score = file.get_32()
		file.close()
	else:
		high_score = 0

func save_high_score():
	var file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	file.store_32(high_score)
	file.close()

func _on_reload_pressed() -> void:
	# Reset game data
	if GameData:
		GameData.final_score = 0
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_menu_pressed() -> void:
	# Go back to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")  # Adjust path as needed

func _on_exit_pressed() -> void:
	get_tree().quit()
