extends RigidBody2D

signal fruit_collided
signal fruit_merged
signal update_score(point: int)
signal fruit_crossed_limit


const FRUIT_TEXTURES = [
	preload("res://assets/fruits/cherry.tres"),
	preload("res://assets/fruits/strawberry.tres"),
	preload("res://assets/fruits/grapes.tres"),
	preload("res://assets/fruits/lemon.tres"),
	preload("res://assets/fruits/orange.tres"),
	preload("res://assets/fruits/guava.tres"),
	preload("res://assets/fruits/pear.tres"),
	preload("res://assets/fruits/peach.tres"),
	preload("res://assets/fruits/pineapple.tres"),
	preload("res://assets/fruits/melon.tres"),
	preload("res://assets/fruits/watermelon.tres"),
]
const FRUIT_SHAPE = [2.5, 3.5, 6, 7, 8.5, 10, 11, 13, 15, 17, 19]
@onready var drop: AudioStreamPlayer2D = $Drop
@onready var merge: AudioStreamPlayer2D = $Merge
@onready var face_anim: AnimatedSprite2D = $Face_anim
@onready var sprite = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tween: Tween

var invincible := true
var fruit_type = 0
var has_collided = false
var is_paused := false
var is_tweening := false
var can_drop := true
var is_merging := false
var merge_timer := 0.0
var tween_speed := 2.0  # Adjust this to control movement speed
var is_on_floor := false
var limit_y: float = 0.0
var is_dragging := false
var drag_speed := 10.0 
@onready var landing_line: Line2D = $LandingLine
var raycast: RayCast2D

func _ready() -> void:
	initialize_fruit()
	setup_physics()
	setup_collision_detection()
	create_tween_node()
	
	face_anim.play("idle") 
	
	raycast = RayCast2D.new()
	raycast.target_position = Vector2.DOWN * 1000  # Long enough to reach the bottom
	raycast.collision_mask = 1 | 2 # Layer for floor and other fruits
	raycast.enabled = true
	add_child(raycast)

	# Setup landing line
	raycast.position = Vector2.ZERO
	landing_line.width = 8
	landing_line.default_color = Color(1, 0, 0)
	print("Paused:", is_paused, " Drop allowed:", can_drop)


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
	gravity_scale = 1
	collision_layer = 2
	collision_mask = 1 | 2  
	
	# FIXED: More balanced mass distribution
	# Use linear scaling instead of exponential
	var base_mass = 1.0
	var mass_multiplier = 1.0 + (fruit_type * 0.5)  # Gradual increase
	mass = base_mass * mass_multiplier
	
	# FIXED: Better physics material
	var mat = PhysicsMaterial.new()
	mat.bounce = 0.2  # Slightly higher bounce
	mat.friction = 0.8  # Higher friction to reduce sliding/spinning
	physics_material_override = mat
	
	# FIXED: Enable angular damping to prevent excessive rotation
	angular_damp = 5.0  # Add this line - it's crucial!
	linear_damp = 0.5   # Slight linear damping too

func initialize_fruit(type: int = -1):
	if type >= 0:
		fruit_type = type
	else:
		# Only generate the first three smallest fruits randomly
		fruit_type = randi() % 5  # This will only generate cherry (0), strawberry (1), or grapes (2)
	
	set_fruit_appearance()

func set_fruit_appearance():
	sprite.texture = FRUIT_TEXTURES[fruit_type]
	if fruit_type == 0:  # Cherry
		sprite.scale = Vector2(1.5, 1.5)  # 50% larger
	elif fruit_type == 1:  # Strawberry
		sprite.scale = Vector2(1.3, 1.3)  # 30% larger
	else:
		sprite.scale = Vector2.ONE
	var new_shape = CircleShape2D.new()
	new_shape.radius = FRUIT_SHAPE[fruit_type]
	collision_shape.shape = new_shape
	
	var base_radius = 3.5  # Smallest fruit size, used for reference
	var current_radius = FRUIT_SHAPE[fruit_type]
	var scale_factor = current_radius / base_radius
	
	if fruit_type == 0:  # Cherry
		face_anim.scale = Vector2(0.3, 0.297)  # 50% larger
	elif fruit_type == 1:  # Strawberry
		face_anim.scale = Vector2(0.26, 0.257)  # 30% larger
	else:
		face_anim.scale = Vector2(0.2, 0.198) * scale_factor


func setup_collision_detection():
	contact_monitor = true
	max_contacts_reported = 1
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
		
	if is_paused and can_drop:
		update_landing_line()
	else:
		landing_line.visible = false

func _on_body_entered(body):
	print("Collision with: ", body.name, " Parent: ", body.get_parent().name if body.get_parent() else "No parent")
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
	print("Floor collision - has_collided before: ", has_collided)
	if not has_collided:
		has_collided = true
		is_on_floor = true
		emit_signal("fruit_collided")
		#invincible = false
		#freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC

func handle_fruit_collision(other_fruit):
	print("Fruit collision - has_collided before: ", has_collided)  # Debug print
	if can_merge_with(other_fruit):
		merge_with(other_fruit)
	else:
		if not has_collided:
			has_collided = true
			emit_signal("fruit_collided")
			#invincible = false

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
	emit_signal("update_score", 10*fruit_type+1)
	
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
	merged_fruit.limit_y = limit_y 
	# Set a shorter merge timer for the new fruit
	merged_fruit.merge_timer = 0.1
	merged_fruit.setup_physics()
	
	# Ensure the new fruit can merge
	merged_fruit.is_merging = false
	merged_fruit.has_collided = false
	
	#merged_fruit.linear_velocity = Vector2.ZERO
	#merged_fruit.angular_velocity = 0
	#
	# Start the grow animation
	merged_fruit.grow(true)
	merged_fruit.add_to_group("Fruit")
# NEW TWEENING FUNCTIONS
func pause_until_released():
	if is_paused:
		return
	is_paused = true
	#freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC
	sleeping = true
	can_drop = true
	set_pickable(true)
	

func _input_event(viewport, event, shape_idx):
	if is_paused and can_drop and not is_merging:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			if event.pressed:
				is_dragging = true
				handle_touch_input(event.position)
			else:
				is_dragging = false
		elif event is InputEventScreenDrag or event is InputEventMouseMotion:
			if is_dragging:
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
	duration = clamp(duration, 0.1, 0.2)  # Min 0.1s, max 1.0s
	
	# Kill any existing tween and create new one
	if tween:
		tween.kill()
	tween = create_tween()
	
	# Tween to target position
	tween.tween_property(self, "global_position", target_pos, duration)
	tween.tween_callback(drop_fruit)

func drop_fruit():
	drop.play()
	is_tweening = false
	is_dragging = false
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.0
	physics_material_override.friction = 1.0

	self.global_position = global_position  
	#freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC # Changed from KINEMATIC
	#apply_central_impulse(Vector2(0, 300))
	#linear_velocity = Vector2(0, 300)
	#angular_velocity = 0

	# State flags
	has_collided = false
	can_drop = false
	invincible = true
	#print("Dropping fruit - Position: ", global_position, " Velocity: ", linear_velocity)
	#resume_physics()
	#print("Dropping fruit - Position: ", global_position, " Velocity: ", linear_velocity, " has_collided: ", has_collided)
	
func resume_physics():
	is_paused = false
	#freeze_mode = RigidBody2D.FreezeMode.FREEZE_MODE_KINEMATIC
	freeze = false
	sleeping = false
	has_collided = false
	can_drop = false  # Prevent further interaction once dropped
	apply_central_impulse(Vector2(0, 300))
	await get_tree().process_frame  # Wait a frame to ensure state sync
	print("Resuming physics - Velocity: ", linear_velocity)
	
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
	setup_physics()

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

func is_fruit_paused() -> bool:
	return is_paused
	
func has_crossed_limit() -> bool:
	return global_position.y >= limit_y

func _physics_process(delta):
	var game_scene = get_node("/root/Game")
	if position.y < 10: return  # Not yet dropped

	if position.y < limit_y:  # Hasn't reached limit line yet
		return

	if not invincible and global_position.y >= limit_y:  
		print("Has collided:",has_collided)
		print("Physics process - Velocity: ", linear_velocity, " Position: ", global_position)
		get_tree().change_scene_to_file("res://scenes/Game_over.tscn")
		set_deferred("freeze", true)  # Prevent further motion after game over
	
	# FIXED: More aggressive angular velocity damping
	# Clamp angular velocity to prevent wild spinning
	if abs(angular_velocity) > 10.0:  # Maximum allowed rotation speed
		angular_velocity = sign(angular_velocity) * 10.0
	
	# Additional damping when fruits are moving slowly (likely stacked)
	if linear_velocity.length() < 5.0:
		angular_velocity *= 0.9  # Reduce rotation when nearly stationary

func update_landing_line():
	# Cast ray downward
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		# Draw line from fruit to collision point
		landing_line.points = [Vector2.ZERO, collision_point - global_position]
		landing_line.visible = true
	else:
		landing_line.visible = false
