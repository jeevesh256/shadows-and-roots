extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var player = null
@onready var projectile_scene = preload("res://projectile.tscn")

var SPEED = 200  # Reduced from 300
var GRAVITY = 2000
var dive_speed = 400  # Reduced from 600
var dive_telegraph_time = 1.2  # Increased from 0.8
var dive_recovery_time = 1.0  # Increased from 0.6
var dive_target_position = Vector2.ZERO
var max_consecutive_dives = 1  # Reduced from 2

# Attack pattern variables
var current_attack_phase = 0
var attack_phases = ["ground", "aerial_projectile", "dash", "final"]  # Added dash phase
var phase_duration = 5.0  # Reduced from 8.0
var phase_timer = 0.0

# Teleport improvements
var is_teleporting = false
var teleport_distance = 200  # Increased from 150
var teleport_cooldown = 1.5  # New variable

var MIN_X = 1345
var MAX_X = 2019

# Aerial projectile phase variables
var hits_in_aerial_phase = 0
var hover_height = 250  # Increased from 200
var aerial_shot_cooldown = 1.2  # Increased from 0.8
var aerial_shot_timer = 0.0
var projectile_accuracy = 0.8  # Increased from 0.7 for more predictable shots

# Boundary points defining the boss arena
const BOUNDARY_POINTS = [
	Vector2(1345, -22),
	Vector2(1392, -245),
	Vector2(1461, -305),
	Vector2(1510, -355),
	Vector2(2018, -355),
	Vector2(2018, -22)
]

# Dive attack variables
var player_last_position = Vector2.ZERO
var player_stationary_time = 0.0
var player_stationary_threshold = 0.3  # Reduced threshold for more aggressive dives
var dive_attack_cooldown = 1.5  # Reduced cooldown
var dive_attack_timer = 0.0
var is_diving = false
var consecutive_dives = 0

# Dash attack variables
var dash_speed = 800
var dash_telegraph_time = 0.3
var dash_duration = 0.4
var dash_cooldown = 1.0
var dash_timer = 0.0
var is_dashing = false
var post_dash_recovery = 0.5
var can_attack = true
var dash_telegraphing = false
var dash_telegraph_timer = 0.0
var dash_distance = 150
var dash_start_pos = Vector2.ZERO

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

	# Add dash telegraph handling
	if dash_telegraphing:
		dash_telegraph_timer -= delta
		if dash_telegraph_timer <= 0:
			execute_dash()
		return  # Prevent other actions while telegraphing

	# Prevent normal movement during dash
	if is_dashing:
		# Only check bounds during dash
		var new_pos = global_position + (velocity * delta)
		if !is_position_in_bounds(new_pos):
			velocity.x *= -1  # Reverse direction if hitting boundary
		move_and_slide()
		return

	# Track player movement
	if player_last_position.distance_to(player.global_position) < 10:
		player_stationary_time += delta
	else:
		player_stationary_time = 0
	player_last_position = player.global_position

	# Update timers
	dive_attack_timer -= delta
	dash_timer = max(0, dash_timer - delta)

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
		1:  # Aerial projectile phase
			aerial_projectile_phase(delta)
		2:  # Dash phase
			dash_phase(delta)
		3:  # Final phase
			final_phase(delta)

	move_and_slide()

func switch_attack_phase():
	current_attack_phase = (current_attack_phase + 1) % 4  # Changed to 4 phases
	phase_timer = phase_duration
	reset_attack_variables()
	if current_attack_phase == 1:  # Aerial projectile phase
		hits_in_aerial_phase = 0

func ground_phase(delta):
	if !is_diving and can_attack:
		var distance = global_position.distance_to(player.global_position)
		
		if player_stationary_time >= player_stationary_threshold and dive_attack_timer <= 0:
			perform_dive_attack()
		elif distance < 300:
			teleport_to_player()

func aerial_projectile_phase(delta):
	# Maintain fixed hover height from ground instead of relative to player
	var target_y = -200  # Fixed Y position above ground
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
		direction = direction.rotated(randf_range(-1 + projectile_accuracy, 1 - projectile_accuracy))
		spawn_projectile(direction)
		aerial_shot_timer = aerial_shot_cooldown

func dash_phase(delta):
	if !is_dashing and !dash_telegraphing and can_attack and dash_timer <= 0:
		if randf() < 0.7:  # High chance to dash
			perform_dash()
		else:
			teleport_to_player()  # Occasionally teleport to mix things up

func final_phase(delta):
	if !is_diving:
		if dive_attack_timer <= 0:
			perform_dive_attack()
		else:
			teleport_to_player()

func perform_dive_attack():
	if !is_diving:
		is_diving = true
		dive_attack_timer = dive_attack_cooldown
		
		 # Store target position at the start
		dive_target_position = player.global_position
		
		# Telegraph the dive
		animated_sprite_2d.modulate = Color(1.5, 0.5, 0.5)
		
		# Create visual indicator at target position
		spawn_target_indicator()
		
		# Longer telegraph time for player to react
		await get_tree().create_timer(dive_telegraph_time).timeout
		animated_sprite_2d.modulate = Color(1, 1, 1)
		
		# Teleport to start position
		var teleport_pos = dive_target_position + Vector2(0, -200)
		if is_position_in_bounds(teleport_pos):
			global_position = teleport_pos
			
			# Brief pause before diving
			await get_tree().create_timer(0.1).timeout
			
			# Dive to the stored target position
			velocity = (dive_target_position - global_position).normalized() * dive_speed
			
			# Recovery period after dive
			await get_tree().create_timer(dive_recovery_time).timeout
			velocity = Vector2.ZERO
			is_diving = false
			
			# Reduced chance of chain dives
			consecutive_dives += 1
			if consecutive_dives < max_consecutive_dives and randf() < 0.4:
				await get_tree().create_timer(0.5).timeout
				perform_dive_attack()
			else:
				consecutive_dives = 0

func perform_dash():
	if !is_dashing and !dash_telegraphing:
		dash_telegraphing = true
		dash_telegraph_timer = dash_telegraph_time
		can_attack = false
		dash_start_pos = global_position
		animated_sprite_2d.modulate = Color(0.5, 1.5, 0.5)

func execute_dash():
	dash_telegraphing = false
	is_dashing = true
	dash_timer = dash_cooldown
	
	# Set horizontal velocity for dash
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * dash_speed
	velocity.y = 0  # Keep vertical velocity at 0 during dash
	
	# Start a timer to end the dash
	get_tree().create_timer(dash_duration).timeout.connect(func():
		animated_sprite_2d.modulate = Color(1, 1, 1)
		velocity = Vector2.ZERO
		is_dashing = false
		get_tree().create_timer(post_dash_recovery).timeout.connect(func(): can_attack = true)
	)

func spawn_target_indicator():
	# You'll need to create a visual scene for this
	# For now, you can use a temporary sprite or marker
	var indicator = Sprite2D.new()
	indicator.position = dive_target_position
	get_parent().add_child(indicator)
	
	# Remove the indicator after telegraph time
	await get_tree().create_timer(dive_telegraph_time).timeout
	indicator.queue_free()

func reset_attack_variables():
	is_teleporting = false
	is_diving = false
	consecutive_dives = 0
	is_dashing = false
	dash_timer = 0.0
	can_attack = true
	dash_telegraphing = false
	dash_telegraph_timer = 0.0

func teleport_to_player():
	if !is_teleporting:
		is_teleporting = true
		animated_sprite_2d.modulate = Color(0.5, 0.5, 1.5)  # Telegraph teleport
		
		await get_tree().create_timer(0.4).timeout  # Telegraph delay
		
		# Rest of teleport logic
		var angle = randf_range(0, PI * 2)
		var direction = Vector2(cos(angle), sin(angle))
		
		var valid_position = global_position
		for dist in range(100, teleport_distance * 2, 50):
			var test_position = player.global_position + (direction * dist)
			if is_position_in_bounds(test_position):
				valid_position = test_position
				break
		
		global_position = valid_position
		animated_sprite_2d.modulate = Color(1, 1, 1)
		
		await get_tree().create_timer(teleport_cooldown).timeout
		is_teleporting = false

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
			if current_attack_phase == 1:  # Aerial projectile phase
				hits_in_aerial_phase += 1
				if hits_in_aerial_phase >= 2:
					switch_attack_phase()
