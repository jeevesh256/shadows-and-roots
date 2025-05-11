extends CharacterBody2D

@onready var left = $sword/left
@onready var right = $sword/right
@onready var p_1 = $p1
@onready var p_2 = $p2
@onready var anim = $AnimatedSprite2D
@onready var hitbox = $hitbox
@onready var detection_area = $detection_area

var speed = 100  # Single speed value
var direction = 1
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
var player = null  # Direct player reference

enum State { PATROL, DETECT, CHASE, ATTACK, DASH, REPOSITION }
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

func _ready():
	left.disabled = true
	right.disabled = true
	anim.animation_finished.connect(_on_animation_finished)
	player = get_tree().get_nodes_in_group("players")[0]
	# Determine which marker is left and right
	if p_1.position.x < p_2.position.x:
		left_marker = p_1.position.x
		right_marker = p_2.position.x
	else:
		left_marker = p_2.position.x
		right_marker = p_1.position.x

func _physics_process(delta):
	velocity.y += gravity * delta
	state_cooldown -= delta
	
	if is_on_floor() and is_instance_valid(player):
		var dir_to_player = (player.global_position - global_position).normalized()
		var distance = global_position.distance_to(player.global_position)
		var y_diff = abs(player.global_position.y - global_position.y)
		
		# Only engage if on similar height level
		if y_diff < 40:
			match current_state:
				State.PATROL:
					handle_patrol()
					if distance < attack_range * 1.5:
						transition_to_state(State.CHASE)
				State.DETECT:
					velocity.x = 0
					anim.play("walk")
					if state_cooldown <= 0:
						transition_to_state(State.CHASE)
				State.CHASE:
					handle_strategic_chase(dir_to_player, distance)
				State.ATTACK, State.DASH, State.REPOSITION:
					if distance > attack_range * 2:
						transition_to_state(State.CHASE)
					else:
						handle_combat_state(dir_to_player, distance)
		else:
			# Return to patrol if height difference is too large
			transition_to_state(State.PATROL)
	
	move_and_slide()

func handle_patrol():
	if position.x >= right_marker:
		direction = -1
	elif position.x <= left_marker:
		direction = 1
	
	velocity.x = direction * speed
	anim.flip_h = (direction < 0)
	anim.play("walk")

func handle_strategic_chase(dir_to_player: Vector2, distance: float):
	if state_cooldown <= 0:
		if distance < optimal_combat_range:
			choose_combat_action(distance)
		else:
			# Smart approach
			direction = sign(dir_to_player.x)
			velocity.x = direction * speed
			anim.flip_h = (direction < 0)
			anim.play("walk")

func choose_combat_action(distance: float):
	if pattern_complete:
		pattern_complete = false
		pattern_step = 0
		# Choose next pattern based on distance
		if distance > optimal_combat_range:
			current_pattern = CombatPattern.DASH_ATTACK
		elif distance < optimal_attack_distance:
			current_pattern = CombatPattern.REPOSITION_ATTACK
		else:
			current_pattern = CombatPattern.APPROACH_ATTACK
	
	match current_pattern:
		CombatPattern.APPROACH_ATTACK:
			execute_approach_pattern()
		CombatPattern.DASH_ATTACK:
			execute_dash_pattern()
		CombatPattern.REPOSITION_ATTACK:
			execute_reposition_pattern()

func execute_approach_pattern():
	match pattern_step:
		0:  # Approach
			transition_to_state(State.CHASE)
			pattern_step += 1
		1:  # Attack when in range
			if abs(global_position.x - player.global_position.x) < optimal_attack_distance:
				transition_to_state(State.ATTACK)
				pattern_step += 1
		2:  # Pattern complete
			pattern_complete = true

func execute_dash_pattern():
	match pattern_step:
		0:  # Prepare dash
			transition_to_state(State.DASH)
			pattern_step += 1
		1:  # Wait for dash to complete
			if current_state != State.DASH:
				pattern_step += 1
		2:  # Attack
			transition_to_state(State.ATTACK)
			pattern_step += 1
		3:  # Pattern complete
			pattern_complete = true

func execute_reposition_pattern():
	match pattern_step:
		0:  # Move to optimal distance
			transition_to_state(State.REPOSITION)
			pattern_step += 1
		1:  # Wait for repositioning
			if abs(global_position.x - player.global_position.x) >= optimal_attack_distance:
				pattern_step += 1
		2:  # Attack
			transition_to_state(State.ATTACK)
			pattern_step += 1
		3:  # Pattern complete
			pattern_complete = true

func transition_to_state(new_state: int):
	if state_cooldown <= 0:
		current_state = new_state
		state_cooldown = min_state_time
		match new_state:
			State.DETECT:
				state_cooldown = 0.3
			State.ATTACK:
				state_cooldown = 0.8
			State.DASH:
				prepare_dash()
			State.PATROL:
				pattern_complete = true  # Reset pattern when returning to patrol

func handle_combat_state(dir_to_player: Vector2, distance: float):
	match current_state:
		State.ATTACK:
			handle_attack(dir_to_player, distance)
		State.DASH:
			handle_dash()
		State.REPOSITION:
			handle_tactical_reposition(distance)

func handle_tactical_reposition(distance: float):
	var optimal_x = player.global_position.x
	if distance < optimal_combat_range:
		optimal_x += direction * optimal_combat_range
	
	direction = sign(optimal_x - global_position.x)
	velocity.x = direction * speed
	anim.flip_h = (direction < 0)
	anim.play("walk")
	
	if abs(global_position.x - optimal_x) < 10:
		transition_to_state(State.ATTACK)

func prepare_dash():
	current_state = State.DASH
	dash_target = player.global_position
	# Brief pause before dash
	velocity.x = 0
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(player):
		direction = sign(player.global_position.x - global_position.x)

func handle_dash():
	if not is_instance_valid(player):
		current_state = State.PATROL
		return
		
	velocity.x = direction * dash_speed
	anim.play("walk")  # Should have a dash animation
	
	if abs(global_position.x - dash_target.x) < 20:
		transition_to_state(State.ATTACK)
		start_attack()

func handle_attack(dir_to_player: Vector2, distance: float):
	if can_attack and not is_attacking:
		if distance > optimal_attack_distance:
			transition_to_state(State.CHASE)
		else:
			direction = sign(dir_to_player.x)
			anim.flip_h = (direction < 0)
			start_attack()

func start_attack():
	is_attacking = true
	velocity.x = direction * speed * 0.3  # Slight movement during attack
	anim.play("attack")
	if direction < 0:
		right.disabled = false
	else:
		left.disabled = false

func _on_animation_finished():
	if anim.animation == "attack":
		is_attacking = false
		left.disabled = true
		right.disabled = true
		can_attack = false
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true

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
