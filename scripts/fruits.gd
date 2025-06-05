extends RigidBody2D

signal fruit_collided
signal fruit_merged
signal update_score(point: int)

const FRUIT_TEXTURES = [
	preload("res://assets/fruits/cherry.tres"),
	preload("res://assets/fruits/strawberry.tres"),
	preload("res://assets/fruits/grapes.tres"),
	preload("res://assets/fruits/lemon.tres"),
	preload("res://assets/fruits/orange.tres"),
	preload("res://assets/fruits/guava.tres")
]
const FRUIT_SHAPE = [2.5, 3.5, 5, 7, 8, 10]
@onready var merge: AudioStreamPlayer2D = $Merge
@onready var face_anim: AnimatedSprite2D = $Face_anim
@onready var sprite = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tween: Tween

var fruit_type = 0
var has_collided = false
var is_paused := false
var is_tweening := false
var can_drop := true
var is_merging := false
var merge_timer := 0.0
var tween_speed := 2.0  # Adjust this to control movement speed

func _ready() -> void:
	setup_physics()
	initialize_fruit()
	setup_collision_detection()
	create_tween_node()
	
	face_anim.play("idle") 
	

func create_tween_node():
	tween = create_tween()
	tween.set_loops(0)  # No loops
	tween.pause()  # Start paused

func grow(from_fusion := false):
	if is_tweening:
		return
	
	is_tweening = true

	if from_fusion:
		# Optional: Add effects (sound, flash, etc.)
		pass

	# Reset sprite scale and collision radius
	sprite.scale = Vector2.ZERO
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = 0

	# Kill existing tween if needed
	if tween:
		tween.kill()
	tween = create_tween()

	# Animate sprite scaling
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Animate collision radius
	var target_radius = FRUIT_SHAPE[fruit_type]
	tween.tween_method(
		func(r): collision_shape.shape.radius = r,
		0.0, target_radius, 0.25
	)

	# Reset tweening flag when done
	tween.connect("finished", func():
		is_tweening = false
	)

func setup_physics():
	gravity_scale = 2
	linear_damp = 2
	angular_damp = 5
	collision_layer = 2
	collision_mask = 1 | 2  

func initialize_fruit(type: int = -1):
	if type >= 0:
		fruit_type = type
	else:
		# Only generate the first three smallest fruits randomly
		fruit_type = randi() % 3  # This will only generate cherry (0), strawberry (1), or grapes (2)
	
	set_fruit_appearance()

func set_fruit_appearance():
	sprite.texture = FRUIT_TEXTURES[fruit_type]
	sprite.scale = Vector2.ONE
	var new_shape = CircleShape2D.new()
	new_shape.radius = FRUIT_SHAPE[fruit_type]
	collision_shape.shape = new_shape
	
	var base_radius = 3.5  # Smallest fruit size, used for reference
	var current_radius = FRUIT_SHAPE[fruit_type]
	var scale_factor = current_radius / base_radius
	
	face_anim.scale = Vector2(0.2,0.2) * scale_factor


func setup_collision_detection():
	contact_monitor = true
	max_contacts_reported = 10
	connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta):
	if merge_timer > 0:
		merge_timer -= delta
	
	var vertical_speed = linear_velocity.y
	var horizontal_speed = abs(linear_velocity.x)
	
	if vertical_speed > 100:
		face_anim.play("falling")
	elif horizontal_speed > 20:
		face_anim.play("rolling")
	elif sleeping:
		face_anim.play("idle")
	else:
		face_anim.play("idle")

func _on_body_entered(body):
	if is_merging:
		return

	if body.name == "Floor":
		handle_floor_collision()
		return
	
	if body.is_in_group("Fruit") and body.has_method("get_fruit_type"):
		handle_fruit_collision(body)
	else:
		handle_general_collision()

func handle_floor_collision():
	if not has_collided:
		has_collided = true
		emit_signal("fruit_collided")
		freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC

func handle_fruit_collision(other_fruit):
	if can_merge_with(other_fruit):
		merge_with(other_fruit)
	else:
		if not has_collided:
			has_collided = true
			emit_signal("fruit_collided")

func can_merge_with(other_fruit) -> bool:
	if other_fruit.get_fruit_type() != fruit_type:
		return false
	
	if fruit_type + 1 >= FRUIT_TEXTURES.size():
		return false
	
	if is_merging or other_fruit.is_merging:
		return false
	
	if merge_timer > 0 or other_fruit.merge_timer > 0:
		return false
	
	return true

func handle_general_collision():
	if not has_collided:
		has_collided = true
		emit_signal("fruit_collided")

func merge_with(other_fruit):
	if is_merging or other_fruit.is_merging:
		return
	
	is_merging = true
	other_fruit.is_merging = true
	
	var merged_type = fruit_type + 1
	var merge_position = (global_position + other_fruit.global_position) / 2
	
	emit_signal("fruit_merged")
	merge.play()
	
	# Create the merged fruit before removing the old ones
	create_merged_fruit(merged_type, merge_position)
	emit_signal("update_score", 10)
	
	# Add a small delay before removing the old fruits
	await get_tree().create_timer(0.1).timeout
	queue_free()
	other_fruit.queue_free()

func create_merged_fruit(merged_type: int, position: Vector2):
	var merged_fruit_scene = preload("res://scenes/fruits.tscn")
	var merged_fruit = merged_fruit_scene.instantiate()
	get_parent().add_child(merged_fruit)
	
	# Set the fruit type and position immediately
	merged_fruit.fruit_type = merged_type
	merged_fruit.global_position = position
	
	# Initialize the fruit's appearance
	merged_fruit.set_fruit_appearance()
	
	# Set a shorter merge timer for the new fruit
	merged_fruit.merge_timer = 0.1
	
	# Ensure the new fruit can merge
	merged_fruit.is_merging = false
	merged_fruit.has_collided = false
	
	# Start the grow animation
	merged_fruit.grow(true)
	merged_fruit.add_to_group("Fruit")
# NEW TWEENING FUNCTIONS
func pause_until_released():
	if is_paused:
		return
	is_paused = true
	freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC
	sleeping = true
	can_drop = true
	set_pickable(true)
	

func _input_event(viewport, event, shape_idx):
	if is_paused and can_drop and not is_merging:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if event.pressed:
				handle_touch_input(event.position)

func handle_touch_input(touch_position: Vector2):
	if is_tweening:
		return  # Ignore input while tweening
	
	# Convert touch position to world coordinates
	var target_x = get_global_mouse_position().x
	
	# Optional: Clamp target position to screen bounds
	var screen_width = get_viewport().get_visible_rect().size.x
	target_x = clamp(target_x, 50, screen_width - 50)  # Add margins
	
	move_to_position(target_x)

func move_to_position(target_x: float):
	if is_tweening:
		return
	
	is_tweening = true
	can_drop = false  # Prevent multiple clicks during tween
	
	var start_pos = global_position
	var target_pos = Vector2(target_x, global_position.y)
	
	# Calculate tween duration based on distance
	var distance = abs(target_x - start_pos.x)
	var duration = distance / (tween_speed * 100)  # Adjust multiplier as needed
	duration = clamp(duration, 0.1, 1.0)  # Min 0.1s, max 1.0s
	
	# Kill any existing tween and create new one
	if tween:
		tween.kill()
	tween = create_tween()
	
	# Tween to target position
	tween.tween_property(self, "global_position", target_pos, duration)
	tween.tween_callback(drop_fruit)

func drop_fruit():
	is_tweening = false
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.01

	self.global_position = global_position  
	#self.sleeping = false  
	freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC
	linear_velocity = Vector2.ZERO

	# State flags
	has_collided = false
	can_drop = false
	


func resume_physics():
	is_paused = false
	freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC
	freeze = false
	sleeping = false
	has_collided = false
	can_drop = false  # Prevent further interaction once dropped
	
	freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_STATIC
	await get_tree().process_frame  # Wait a frame to ensure state sync
	freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC
	
# ALTERNATIVE: Click anywhere on screen to move fruit
func _unhandled_input(event):
	if is_paused and can_drop and not is_merging:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if event.pressed:
				var target_x = event.position.x
				# Convert screen coordinates to world coordinates if needed
				var viewport = get_viewport()
				var camera = viewport.get_camera_2d()
				if camera:
					var world_pos = camera.to_global(event.position)
					target_x = world_pos.x
				
				move_to_position(target_x)

func set_drag_allowed(value: bool) -> void:
	can_drop = value

func set_fruit_type(t: int):
	fruit_type = t
	set_fruit_appearance()

func get_fruit_type() -> int:
	return fruit_type

func reset_collision_state():
	has_collided = false
	is_merging = false
	merge_timer = 0.0

# Optional: Add visual feedback during tweening
func _on_tween_started():
	# Add visual effects like scaling or color change
	var scale_tween = create_tween()
	scale_tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.1)
	scale_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
