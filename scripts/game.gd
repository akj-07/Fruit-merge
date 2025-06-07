extends Node2D

@export var fruit_scene = preload("res://scenes/fruits.tscn")
var current_fruit: RigidBody2D = null
var current_score: int = 0
var game_over_triggered: bool = false
var can_spawn_fruit := true

@onready var drop_zone: Area2D = $"Drop Zone"
@onready var label: Label = $Control/Label
@onready var menu: Button = $Menu
@onready var game_audio: AudioStreamPlayer2D = $GameAudio
@onready var check_fruit: Timer = $CheckFruit
@onready var limit_line: Area2D = $"Limit Line"
@onready var game_over_timer: Timer = $GameOverTimer

func _ready():
	randomize()
	print("Limit line position: ", limit_line.global_position)
	
	# Connect game over timer
	if not game_over_timer.timeout.is_connected(_on_game_over_timer_timeout):
		game_over_timer.timeout.connect(_on_game_over_timer_timeout)
	
	spawn_fruit()
	game_audio.stream.loop = true
	game_audio.play()
	
	# Connect limit line detection
	limit_line.body_entered.connect(_on_limit_line_body_entered)
	limit_line.body_exited.connect(_on_limit_line_body_exited)

func spawn_fruit():
	if game_over_triggered or not can_spawn_fruit:
		return
		
	can_spawn_fruit = false
	
	current_fruit = fruit_scene.instantiate()
	current_fruit.position = Vector2(580, 50)
	add_child(current_fruit)
	current_fruit.update_score.connect(Update_Label)
	current_fruit.add_to_group("Fruit")
	current_fruit.angular_damp = 10
	current_fruit.limit_y = limit_line.global_position.y
	
	# Connect signals
	current_fruit.connect("fruit_collided", Callable(self, "_on_fruit_collided"))
	current_fruit.connect("fruit_merged", Callable(self, "_on_fruit_merged"))

func _on_limit_line_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Fruit"):
		return
	print("Fruit entered limit line: ", body.name)
	print("Is invincible: ", body.invincible)
	print("Game over triggered: ", game_over_triggered)
	
	# Handle game over logic
	if not game_over_triggered and not body.invincible:
		print("Starting game over timer")
		game_over_timer.start()
	elif not game_over_triggered and body.invincible:
		# If fruit is invincible but above limit, wait for it to become vulnerable
		print("Fruit above limit but still invincible - waiting for vulnerability")

	# Handle game over logic
	if not game_over_triggered and not body.invincible:
		print("Non-invincible fruit crossed limit line: ", body.name)
		game_over_timer.start()

func _on_limit_line_body_exited(body: Node2D) -> void:
	# Handle game over timer cancellation
	if body.is_in_group("Fruit") and game_over_timer.time_left > 0:
		game_over_timer.stop()
		print("Fruit moved back below limit line - timer stopped")

func trigger_game_over():
	if game_over_triggered:
		return
		
	game_over_triggered = true
	print("Game over triggered! Final score: ", current_score)
	
	# Stop spawning new fruits
	check_fruit.stop()
	
	# Freeze all fruits
	var fruits = get_tree().get_nodes_in_group("Fruit")
	for fruit in fruits:
		fruit.freeze = true

func _on_game_over_timer_timeout():
	# Double-check if any fruits are still above the line
	var overlapping = limit_line.get_overlapping_bodies()
	var fruits_above_line = false
	
	for body in overlapping:
		if body.is_in_group("Fruit") and not body.invincible:
			fruits_above_line = true
			break
	
	if fruits_above_line:
		trigger_game_over()
		# Pass score to game over scene
		GameData.final_score = current_score
		get_tree().change_scene_to_file("res://scenes/Game_over.tscn")

func _on_fruit_collided():
	await get_tree().create_timer(0.2).timeout 

func _on_drop_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Fruit"):
		return

	if body.has_method("pause_until_released"):
		body.pause_until_released()

func _on_drop_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("Fruit") and body.has_method("set_drag_allowed"):
		body.set_drag_allowed(false)
		# Start check_fruit timer when fruit leaves drop zone
		check_fruit.start()
		print("Fruit left drop zone, starting check timer")

func Update_Label(points: int) -> void:
	current_score += points
	$Control/Label.update_score(points)

func _on_menu_pressed() -> void:
	get_tree().paused = true
	var menu = preload("res://scenes/menu.tscn").instantiate()
	menu.name = "PauseMenu"
	add_child(menu)  

func _on_check_fruit_timeout() -> void:
	if game_over_triggered:
		return
		
	# Check if any fruits are still above the limit line
	var overlapping = drop_zone.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("Fruit"):
			print("Fruit still above limit line - no new spawn")
			return
	
	# If no fruits are above limit line, spawn new fruit
	print("Check timer completed, spawning new fruit")
	can_spawn_fruit = true
	spawn_fruit()
