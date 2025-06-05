extends Node2D

@export var fruit_scene = preload("res://scenes/fruits.tscn")  # Adjust path to your fruit scene

var current_fruit: RigidBody2D = null
@onready var label: Label = $Control/Label
@onready var menu: Button = $Menu
@onready var game_audio: AudioStreamPlayer2D = $GameAudio
@onready var drop_zone: Area2D = $"Drop Zone"
@onready var check_fruit: Timer = $CheckFruit

func _ready():
	randomize()
	spawn_fruit()
	game_audio.stream.loop =true
	game_audio.play()
	
func spawn_fruit():
	
	var mat = PhysicsMaterial.new()
	
	# if the fruit has collided with the floor or another fruit then instantiate new fruit.
	current_fruit = fruit_scene.instantiate()
	current_fruit.position = Vector2(580, 50)
	current_fruit.mass = 1
	mat.bounce = 0
	mat.friction = 2.0
	current_fruit.get_node("CollisionShape2D").material = mat
	add_child(current_fruit)
	current_fruit.update_score.connect(Update_Label)
	current_fruit.add_to_group("Fruit")
	# Connect to fruit_collided signal from fruit
	current_fruit.connect("fruit_collided", Callable(self, "_on_fruit_collided"))
	current_fruit.connect("fruit_merged", Callable(self, "_on_fruit_merged"))

func _on_fruit_collided():
	# Small delay so you see the fruit before the next spawns
	await get_tree().create_timer(0.2).timeout 
	#spawn_fruit()


func _on_drop_zone_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Fruit"):
		return

	if body.has_method("pause_until_released") and body.is_paused == false and body.can_drop == false and body.is_merging == false:
		# Fruit has already been dropped and is falling — game over condition
		game_over()
	elif body.has_method("pause_until_released"):
		# First time entering drop zone, freeze the fruit for user input
		body.pause_until_released()


func _on_drop_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("Fruit") and body.has_method("set_drag_allowed"):
		body.set_drag_allowed(false)
		check_fruit.start()

func Update_Label(points:int)->void:
	$Control/Label.update_score(points)

func _on_menu_pressed() -> void:
	get_tree().paused = true
	var menu = preload("res://scenes/menu.tscn").instantiate()
	menu.name = "PauseMenu"
	add_child(menu)  

func game_over() -> void:
	get_tree().change_scene_to_file("res://scenes/Game_over.tscn")


func _on_check_fruit_timeout() -> void:
	var overlapping = drop_zone.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("Fruit"):
			return
	
	spawn_fruit()
