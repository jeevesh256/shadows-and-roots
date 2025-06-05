extends CharacterBody2D

@onready var left = $sword/left
@onready var right = $sword/right
@onready var p_1 = $p1
@onready var p_2 = $p2
@onready var anim = $AnimatedSprite2D
@onready var hitbox = $hitbox
@onready var detection_area = $detection_area
@onready var player = null  # Will be assigned in _ready()
@onready var animated_sprite_2d = $AnimatedSprite2D

var speed = 100  # Single speed value
var direction = 1
var facing_direction = 1  # Add this new variable for visual facing
var gravity = 980
var buffer = 5.0  # Small buffer for smoother direction changes

var left_marker
var right_marker

var attack_cooldown = 1.5
var can_attack = true
var player_in_range = false
var current_player = null
var is_attacking = false
var attack_range = 100.0  # Distance to start attack
var last_known_player_pos = Vector2.ZERO

enum State { PATROL, DETECT, ATTACK, DASH_ATTACK }
var current_state = State.PATROL

var optimal_attack_distance = 80.0
var health = 100
var dash_speed = 300
var dash_distance = 200
var dash_target = Vector2.ZERO
var repositioning = false

var state_cooldown = 0.0
var min_state_time = 0.5
var optimal_combat_range = 120.0

enum CombatPattern { APPROACH_ATTACK, DASH_ATTACK, REPOSITION_ATTACK }
var current_pattern = CombatPattern.APPROACH_ATTACK
var pattern_step = 0
var pattern_complete = true

var attack_telegraph_time = 0.5
var dash_telegraph_time = 0.7
var modulate_default = Color(1, 1, 1, 1)
var modulate_attack = Color(1, 0.5, 0.5, 1)  # Red tint
var modulate_dash = Color(0.5, 0.5, 1, 1)    # Blue tint

var last_player_positions = []
const MAX_STORED_POSITIONS = 30  # Store 0.5 seconds of positions at 60fps
var jump_force = -400
var max_attack_attempts = 3

var current_attack_frame = 0
var attack_movement_speed = 50  # Speed during attack

func _ready():
	left.disabled = true
	right.disabled = true
	anim.animation_finished.connect(_on_animation_finished)
	modulate = modulate_default
	
	# Get player reference from the scene tree
	player = get_tree().get_nodes_in_group("players")[0]
	
	# Determine which marker is left and right
	if p_1.position.x < p_2.position.x:
		left_marker = p_1.position.x
		right_marker = p_2.position.x
	else:
		left_marker = p_2.position.x
		right_marker = p_1.position.x

	anim.frame_changed.connect(_on_frame_changed)

func _physics_process(delta):
	velocity.y += gravity * delta
	
	if not is_instance_valid(player):
		player = get_tree().get_nodes_in_group("players")[0]
		if not is_instance_valid(player):
			handle_patrol()
			move_and_slide()
			return
	
	# Store player positions
	if is_instance_valid(player):
		last_player_positions.push_back(player.global_position)
		if last_player_positions.size() > MAX_STORED_POSITIONS:
			last_player_positions.pop_front()
	
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	var y_diff = abs(to_player.y)
	
	if is_on_floor():
		if distance < attack_range * 1.5 and y_diff < 60:
			update_facing_direction()
			choose_combat_state(distance)
		else:
			current_state = State.PATROL
			handle_patrol()
	
	velocity.x = clamp(velocity.x, -speed * 1.5, speed * 1.5)
	move_and_slide()

func choose_combat_state(distance: float):
	if not can_attack or is_attacking:
		return
	
	if distance > attack_range * 1.5:
		current_state = State.PATROL
		return
		
	if distance < optimal_attack_distance:
		current_state = State.ATTACK
		handle_attack()
	else:
		# Reduced jump chance to 15% and add better conditions
		var should_jump = randf() < 0.15 and last_player_positions.size() >= MAX_STORED_POSITIONS and not is_attacking and is_on_floor()
		if should_jump and abs(player.global_position.y - global_position.y) > 20:  # Only jump if player is higher
			perform_jump_attack()
		else:
			current_state = State.DASH_ATTACK
			handle_dash_attack()

func perform_jump_attack():
	if not is_on_floor():
		return
	
	# Get slightly newer position (0.3 seconds ago instead of 0.5)
	var target_index = min(last_player_positions.size() - 1, MAX_STORED_POSITIONS * 0.6) as int
	var target_pos = last_player_positions[target_index] if last_player_positions.size() > 0 else player.global_position
	
	# Calculate jump trajectory
	var to_target = target_pos - global_position
	direction = sign(to_target.x)
	
	# Adjusted jump force based on height difference
	var height_diff = target_pos.y - global_position.y
	velocity.y = jump_force - min(height_diff * 0.5, 200)
	velocity.x = direction * speed * 1.2  # Slightly reduced horizontal speed
	
	anim.flip_h = (direction < 0)
	anim.play("walk")
	
	# Shorter wait time
	await get_tree().create_timer(0.4).timeout
	if is_on_floor():
		start_attack()
	else:
		current_state = State.PATROL

func handle_patrol():
	# Simple patrol between markers
	if position.x >= right_marker:
		direction = -1
	elif position.x <= left_marker:
		direction = 1
	
	velocity.x = direction * speed
	# Update facing to match movement direction in patrol
	facing_direction = direction
	anim.flip_h = (facing_direction < 0)
	anim.play("walk")
	
	# Check for player
	if player_in_range:
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		if distance < attack_range:
			choose_attack_type()

func handle_detect():
	velocity.x = 0
	anim.play("idle")
	if state_cooldown <= 0:
		choose_attack_type()

func handle_attack():
	if not is_attacking and is_on_floor():
		update_attack_direction()
		telegraph_attack()

func handle_dash_attack():
	if not is_attacking and is_on_floor():
		update_attack_direction()
		telegraph_dash_attack()

func choose_attack_type():
	var distance = global_position.distance_to(player.global_position)
	if distance > optimal_attack_distance:
		current_state = State.DASH_ATTACK
	else:
		current_state = State.ATTACK

func telegraph_attack():
	modulate = modulate_attack
	anim.play("idle")
	velocity.x = 0
	await get_tree().create_timer(attack_telegraph_time).timeout
	if current_state == State.ATTACK:
		start_attack()

func telegraph_dash_attack():
	modulate = modulate_dash
	anim.play("idle")
	velocity.x = 0
	await get_tree().create_timer(dash_telegraph_time).timeout
	if current_state == State.DASH_ATTACK:
		dash_to_player()

func update_facing_direction():
	if not is_instance_valid(player):
		return
		
	var new_direction = sign(player.global_position.x - global_position.x)
	if new_direction != 0:
		# Only update facing direction if we're not moving or moving in that direction
		if abs(velocity.x) < 10 or sign(velocity.x) == new_direction:
			facing_direction = new_direction
			anim.flip_h = (facing_direction < 0)
		direction = new_direction

func update_attack_direction():
	if is_instance_valid(player):
		# Update direction only if player crosses to other side
		var player_side = sign(player.global_position.x - global_position.x)
		if player_side != direction and not is_attacking:
			direction = player_side
			anim.flip_h = (direction < 0)

func dash_to_player():
	if not is_instance_valid(player):
		current_state = State.PATROL
		return
	
	direction = sign(player.global_position.x - global_position.x)
	facing_direction = direction  # Update facing direction with dash
	velocity.x = direction * dash_speed
	anim.flip_h = (facing_direction < 0)
	anim.play("walk")
	
	# Quick dash then attack
	await get_tree().create_timer(0.2).timeout
	var distance = global_position.distance_to(player.global_position)
	if distance <= attack_range:
		start_attack()
	else:
		current_state = State.PATROL

func start_attack():
	modulate = modulate_default
	is_attacking = true
	current_attack_frame = 0
	velocity.x = direction * attack_movement_speed  # Move forward during attack
	anim.play("attack")
	
	# Update direction one final time before attack
	if is_instance_valid(player):
		direction = sign(player.global_position.x - global_position.x)
		anim.flip_h = (direction < 0)
	
	# Ensure swords start disabled
	left.disabled = true
	right.disabled = true

func _on_frame_changed():
	if anim.animation == "attack":
		current_attack_frame = anim.frame
		# Enable sword hitbox only on frames 7 and 8
		if current_attack_frame in [7, 8]:
			if direction < 0:
				right.disabled = false
				left.disabled = true
			else:
				left.disabled = false
				right.disabled = true
		else:
			# Disable both hitboxes on all other frames
			left.disabled = true
			right.disabled = true

func _on_animation_finished():
	if anim.animation == "attack":
		is_attacking = false
		left.disabled = true
		right.disabled = true
		can_attack = false
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true
		
		# Immediately check for new attack opportunity
		if is_instance_valid(player):
			var distance = global_position.distance_to(player.global_position)
			choose_combat_state(distance)
		else:
			current_state = State.PATROL

func _on_hitbox_body_entered(body):
	if body.is_in_group("players"):
		if body.has_method("damage"):
			body.damage(1)

func _on_detection_area_body_entered(body):
	if body.is_in_group("players"):
		player_in_range = true
		current_player = body
		if current_state == State.PATROL:
			transition_to_state(State.DETECT)

func _on_detection_area_body_exited(body):
	if body.is_in_group("players"):
		player_in_range = false
		current_player = null
		is_attacking = false
		left.disabled = true
		right.disabled = true
		transition_to_state(State.PATROL)

func transition_to_state(new_state: int):
	if state_cooldown <= 0:
		current_state = new_state
		state_cooldown = min_state_time
		match new_state:
			State.DETECT:
				state_cooldown = 0.3
				anim.play("idle")
			State.ATTACK:
				state_cooldown = 0.8
			State.PATROL:
				anim.play("walk")


func _on_sword_body_entered(body):
	if body.is_in_group("players"):
		if body.has_method("damage"):
			body.damage(1)
