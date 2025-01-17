extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var player = null
@onready var projectile_scene = preload("res://projectile.tscn")

var SPEED = 300  # Slightly reduced for better control
var GRAVITY = 2000
var JUMP_FORCE = -800
var ATTACK_JUMP_FORCE = -1000

# Attack pattern variables
var current_attack_phase = 0
var attack_phases = ["ground", "air", "aerial_projectile", "final"]
var phase_duration = 5.0
var phase_timer = 0.0

# Jump attack improvements
var jump_count = 0
var max_jumps = 3  # Reduced for better control
var jump_timer = 0.0
var jump_cooldown = 1.5  # Cooldown between jump sequences
var is_preparing_jump = false
var jump_telegraph_time = 0.5  # Time to telegraph jump attack

# Projectile attack improvements
var projectile_burst_count = 3
var projectile_burst_delay = 0.2
var current_burst = 0
var burst_timer = 0.0

# Teleport improvements
var is_teleporting = false
var teleport_distance = 150  # Distance from player after teleport

# Add these constants at the top with other variables
var MIN_X = 1345
var MAX_X = 2019

# Aerial projectile phase variables
var hits_in_aerial_phase = 0
var hover_height = 200
var aerial_shot_cooldown = 0.8
var aerial_shot_timer = 0.0
var projectile_accuracy = 0.7  # 1.0 is perfect accuracy, lower values add more randomness

# Boundary points defining the boss arena
const BOUNDARY_POINTS = [
	Vector2(1345, -22),
	Vector2(1392, -245),
	Vector2(1461, -305),
	Vector2(1510, -355),
	Vector2(2018, -355),
	Vector2(2018, -22)
]

# Add these new variables after the other variables
var player_last_position = Vector2.ZERO
var player_stationary_time = 0.0
var player_stationary_threshold = 0.5  # Time before considering player stationary
var dive_attack_cooldown = 2.0
var dive_attack_timer = 0.0
var is_diving = false
var dive_speed = 800

func is_position_in_bounds(pos: Vector2) -> bool:
	# Create a temporary polygon for boundary checking
	var polygon = PackedVector2Array(BOUNDARY_POINTS)
	return Geometry2D.is_point_in_polygon(pos, polygon)

func _ready():
	player = get_tree().get_nodes_in_group("players")[0]
	phase_timer = phase_duration

func _physics_process(delta):
	if !player or !is_instance_valid(player):
		return

	# Track player movement
	if player_last_position.distance_to(player.global_position) < 10:
		player_stationary_time += delta
	else:
		player_stationary_time = 0
	player_last_position = player.global_position

	# Update timers
	dive_attack_timer -= delta

	# Apply gravity
	velocity.y += GRAVITY * delta

	# Calculate direction towards the player
	var direction = (player.global_position - global_position).normalized()

	# Calculate the distance to the player
	var distance = global_position.distance_to(player.global_position)

	# Move the enemy towards the player
	if distance > 0:
		var move_amount = SPEED * delta
		var move_vector = direction * min(move_amount, distance)
		# Check if new position would be in bounds
		var new_pos = global_position + Vector2(move_vector.x, 0)
		if is_position_in_bounds(new_pos):
			velocity.x = move_vector.x
		else:
			velocity.x = 0

	# Phase-based attack system
	phase_timer -= delta
	if phase_timer <= 0:
		switch_attack_phase()

	match current_attack_phase:
		0:  # Ground phase
			ground_phase(delta)
		1:  # Air phase
			air_phase(delta)
		2:  # Aerial projectile phase
			aerial_projectile_phase(delta)
		3:  # Final phase
			final_phase(delta)

	move_and_slide()

func switch_attack_phase():
	current_attack_phase = (current_attack_phase + 1) % 4
	phase_timer = phase_duration
	reset_attack_variables()
	if current_attack_phase == 2:  # Aerial projectile phase
		hits_in_aerial_phase = 0

func ground_phase(delta):
	if !is_preparing_jump and is_on_floor():
		var distance = global_position.distance_to(player.global_position)
		
		# Initiate dive attack if player is stationary
		if player_stationary_time >= player_stationary_threshold and dive_attack_timer <= 0:
			perform_dive_attack()
		elif distance < 150:
			prepare_jump_attack()
		elif distance < 300:
			if randf() < 0.3:  # 30% chance to teleport instead of shooting
				teleport_to_player()
			else:
				shoot_projectile_burst()

func air_phase(delta):
	if is_on_floor() and !is_preparing_jump:
		velocity.y = JUMP_FORCE
		teleport_to_player()

func aerial_projectile_phase(delta):
	# Maintain hover height
	var target_y = player.global_position.y - hover_height
	var height_diff = target_y - global_position.y
	velocity.y = clamp(height_diff * 10, -SPEED, SPEED)
	
	# Move horizontally to maintain distance
	var desired_x = player.global_position.x + (150 * sign(global_position.x - player.global_position.x))
	var new_pos = Vector2(desired_x, global_position.y)
	if is_position_in_bounds(new_pos):
		var x_diff = desired_x - global_position.x
		velocity.x = clamp(x_diff * 5, -SPEED, SPEED)
	else:
		velocity.x = 0
	
	# Shoot projectiles with timing
	aerial_shot_timer -= delta
	if aerial_shot_timer <= 0:
		var direction = (player.global_position - global_position).normalized()
		# Add random deviation based on accuracy
		direction = direction.rotated(randf_range(-1 + projectile_accuracy, 1 - projectile_accuracy))
		spawn_projectile(direction)
		aerial_shot_timer = aerial_shot_cooldown

func final_phase(delta):
	if is_on_floor():
		shoot_projectile_burst()
		prepare_jump_attack()
		if randf() < 0.3:
			teleport_to_player()

func prepare_jump_attack():
	if !is_preparing_jump:
		is_preparing_jump = true
		# Add visual telegraph effect here
		await get_tree().create_timer(jump_telegraph_time).timeout
		perform_jump()
		is_preparing_jump = false

func perform_jump():
	if is_on_floor():
		# Calculate jump direction towards the player
		var direction = (player.global_position - global_position).normalized()
		velocity.x = direction.x * SPEED * 1.5  # Horizontal momentum
		velocity.y = ATTACK_JUMP_FORCE

		# Increment jump count
		jump_count += 1

		# Reset jump sequence if we've done all jumps
		if jump_count >= max_jumps:
			jump_count = 0
			is_preparing_jump = false

func shoot_projectile_burst():
	if current_burst < projectile_burst_count:
		var spread = [-20, 0, 20]  # Degrees
		for angle in spread:
			var direction = (player.global_position - global_position).normalized()
			direction = direction.rotated(deg_to_rad(angle))
			spawn_projectile(direction)
		current_burst += 1
		burst_timer = projectile_burst_delay
	
func teleport_to_player():
	if !is_teleporting:
		is_teleporting = true
		
		# Get random angle relative to player
		var angle = randf_range(0, PI * 2)
		var direction = Vector2(cos(angle), sin(angle))
		
		# Try different distances starting from closer to player
		var valid_position = global_position
		for dist in range(100, teleport_distance * 2, 50):
			var test_position = player.global_position + (direction * dist)
			if is_position_in_bounds(test_position):
				valid_position = test_position
				break
		
		global_position = valid_position
		
		# Shorter cooldown for more aggressive behavior
		await get_tree().create_timer(0.1).timeout
		is_teleporting = false

func perform_dive_attack():
	if !is_diving and !is_preparing_jump:
		is_diving = true
		dive_attack_timer = dive_attack_cooldown
		
		# First teleport above player
		var teleport_pos = player.global_position + Vector2(0, -200)
		if is_position_in_bounds(teleport_pos):
			global_position = teleport_pos
			
			# Brief pause before diving
			await get_tree().create_timer(0.2).timeout
			
			# Dive toward player
			velocity = (player.global_position - global_position).normalized() * dive_speed
			
			# End dive after a short duration
			await get_tree().create_timer(0.5).timeout
			is_diving = false

func reset_attack_variables():
	current_burst = 0
	burst_timer = 0.0
	is_preparing_jump = false
	is_teleporting = false
	jump_count = 0
	is_diving = false

func spawn_projectile(direction):
	var projectile = projectile_scene.instantiate()
	projectile.position = global_position
	projectile.set("direction", direction)
	get_parent().add_child(projectile)

func _on_area_body_entered(body):
	if body.is_in_group("players"):
		print("die")
		if body.has_method("damage"):
			body.damage(1)
			if current_attack_phase == 2:  # Aerial projectile phase
				hits_in_aerial_phase += 1
				if hits_in_aerial_phase >= 2:
					switch_attack_phase()
