extends CharacterBody2D

# Constants
const JUMP_VELOCITY = -500.0  # Further increased jump velocity for a higher jump
const DASH_SPEED = 800.0  # Dash speed (fixed)
const DASH_DURATION = 0.2  # Dash duration (in seconds)
const DASH_COOLDOWN = 0.5  # Dash cooldown (in seconds)
const MOVE_SPEED = 300.0  # Movement speed (fixed)
const GRAVITY = 2000.0  # Reduced gravity for a slower fall
const JUMP_BUFFER_TIME = 0.1  # Time window to buffer jump input
const ATTACK_BUFFER_TIME = 0.1  # Time window to buffer attack input
const JUMP_CUT_GRAVITY = 6000.0  # Reintroduce gravity change when jump is cut short
const JUMP_HOLD_GRAVITY = 1500.0  # Reduced gravity when holding jump for a higher jump

# Nodes
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var marker2d = $Marker_dust
@onready var dash_effect_left = $dash2
@onready var dash_effect_right = $dash1
const DUST = preload("res://dust.tscn")
const PROJECTILE = preload("res://projectile.tscn")
@onready var attack_timer = $attack_collision/Timer
@onready var sword_left = $attack_collision/sword_left
@onready var sword_right = $attack_collision/sword_right
@onready var sword_up = $attack_collision/sword_up
@onready var sword_down = $attack_collision/sword_down

# State variables
var was_on_floor = false
var is_dashing = false
var dash_time_remaining = 0.0
var dash_cooldown_remaining = 0.0
var coyote_timer = 0.0  # Timer for coyote time
var is_on_ground = false
var can_shoot_projectile = true
var dead=false
var wall_slide_gravity = 300
var attack_buffer_timer = 0.0  # Timer for attack buffering
var can_dash = true  # State variable to track if the player can dash

# Jump variables
var is_jumping = false
var jump_time = 0.0  # Time the jump button is held down
const JUMP_HOLD_TIME = 0.1  # Reduced max time to hold the jump for a higher jump
var jump_buffer_timer = 0.0  # Timer for jump buffering
var jump_pressed = false  # Track if jump was pressed

const WALL_JUMP_VELOCITY = Vector2(1000, -400)  # Increased vertical jump power
const WALL_JUMP_PUSHBACK = 800  # Increased horizontal pushback when wall jumping
const WALL_JUMP_RETURN_FORCE = 50  # Reduced force to move back towards the wall
const WALL_ATTACH_DELAY = 0.1  # Delay before reattaching to the wall
var wall_attach_timer = 0.0  # Timer for wall attach delay
const WALL_JUMP_COOLDOWN = 0.2  # Cooldown time before another wall jump
var wall_jump_cooldown_timer = 0.0  # Timer for wall jump cooldown
var is_attacking = false
	
func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")  # Declare direction variable
	if not is_attacking:
		sword_left.disabled = true
		sword_right.disabled = true
		sword_up.disabled = true
		sword_down.disabled = true
	# Cooldowns and timers
	update_dash_cooldown(delta)
	update_coyote_timer(delta)
	update_jump_buffer_timer(delta)
	update_wall_jump_cooldown(delta)
	update_wall_attach_timer(delta)
	update_attack_buffer_timer(delta)

	# Check landing
	handle_landing()

	# Apply gravity
	if not is_dashing and not is_on_ground:
		if is_jumping and not Input.is_action_pressed("jump"):
			velocity.y += JUMP_CUT_GRAVITY * delta  # Apply jump cut gravity if jump is cut short
		else:
			velocity.y += GRAVITY * delta  # Apply normal gravity

	# Dash or normal movement
	if is_dashing:
		handle_dash(delta)
	else:
		handle_movement_and_jump(delta)
		
	if Game.has_ability("wall_jump"):
		if is_on_wall() and Input.get_axis("ui_left", "ui_right"):
			velocity.y = min(velocity.y, wall_slide_gravity)

		# Wall jump logic
		if jump_buffer_timer > 0 and not is_jumping and is_on_wall_only() and wall_attach_timer <= 0:
			velocity = Vector2(get_wall_normal().x * WALL_JUMP_PUSHBACK, WALL_JUMP_VELOCITY.y)
			jump_buffer_timer = 0  # Reset jump buffer timer after wall jump
			wall_attach_timer = WALL_ATTACH_DELAY  # Start wall attach delay timer
			can_dash = true  # Reset can_dash after wall jump

		# Apply slight movement back towards the wall after wall jump
		if is_jumping and is_on_wall_only() and Input.get_axis("ui_left", "ui_right") == 0:
			velocity.x += get_wall_normal().x * WALL_JUMP_RETURN_FORCE * delta

		# Allow reattaching to the wall after the pushback
		if wall_attach_timer <= 0 and is_on_wall_only():
			velocity.x = 0  # Stop horizontal movement to allow reattachment

	if Input.is_action_just_pressed("projectile") and can_shoot_projectile:
		shoot_projectile()

	# Apply movement
	move_and_slide()

	if Input.is_action_just_pressed("attack"):
		attack_buffer_timer = ATTACK_BUFFER_TIME  # Reset buffer timer when attack is pressed

	if Input.is_action_just_pressed("jump"):
		jump_pressed = true  # Mark jump as pressed
		jump_buffer_timer = JUMP_BUFFER_TIME  # Reset buffer timer when jump is pressed

	if is_on_floor():
		can_dash = true  # Reset can_dash when on the floor

	if Game.has_ability("dash"):
		# Handle dash
		if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0 and (can_dash or is_on_wall()):
			start_dash()
			can_dash = false  # Disable further dashing until reset if not wall sliding

	if attack_buffer_timer > 0:
		start_attack()
		attack_buffer_timer = 0  # Reset attack buffer timer after attack

	if Input.is_action_just_pressed("attack"):
		start_attack()

	# Handle animations
	if is_on_floor() and not is_attacking:
		if direction != 0:
			animated_sprite_2d.play("run")
		else:
			animated_sprite_2d.play("default")
	elif not is_on_floor() and not is_attacking:
		if velocity.y < 0:
			animated_sprite_2d.play("jump")
		elif velocity.y > 0:
			animated_sprite_2d.play("fall")
	else:
		pass

func update_dash_cooldown(delta):
	if dash_cooldown_remaining > 0:
		dash_cooldown_remaining -= delta  # Frame-based cooldown

func update_coyote_timer(delta):
	# If on the floor, reset coyote timer
	if is_on_floor():
		coyote_timer = 0.2
	else:
		# Decrease coyote timer if in the air
		coyote_timer -= delta  # Frame-based coyote time

func update_jump_buffer_timer(delta):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta  # Decrease buffer timer
	else:
		jump_pressed = false  # Reset jump pressed state when buffer timer expires

func update_wall_jump_cooldown(delta):
	if wall_jump_cooldown_timer > 0:
		wall_jump_cooldown_timer -= delta  # Decrease wall jump cooldown timer

func update_wall_attach_timer(delta):
	if wall_attach_timer > 0:
		wall_attach_timer -= delta  # Decrease wall attach timer

func update_attack_buffer_timer(delta):
	if attack_buffer_timer > 0:
		attack_buffer_timer -= delta  # Decrease buffer timer

func handle_landing():
	var is_on_floor_now = is_on_floor()

	# Spawn dust only when landing
	if not was_on_floor and is_on_floor_now:
		spawn_dust()

	# Reset jump state if we land
	if is_on_floor_now:
		is_jumping = false  # Reset jump state when landing
		can_dash = true  # Reset can_dash when landing

	was_on_floor = is_on_floor_now
	is_on_ground = is_on_floor_now

func handle_movement_and_jump(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * MOVE_SPEED
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)

	# Buffer jump input
	if jump_pressed and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY  # Apply initial jump force
		is_jumping = true  # Mark as jumping
		jump_time = 0  # Reset jump time when jump is pressed
		coyote_timer = 0  # Reset coyote timer after a jump
		jump_buffer_timer = 0  # Reset jump buffer timer after jump
		jump_pressed = false  # Reset jump pressed state after jump
		can_dash = true  # Reset can_dash after jump

	# Gradual jump height increase
	if is_jumping:
		jump_time += delta  # Increment jump time
		if jump_time < JUMP_HOLD_TIME and Input.is_action_pressed("jump"):
			velocity.y = JUMP_VELOCITY  # Continue applying initial jump force
		else:
			is_jumping = false  # End jump when max hold time is reached or button is released

	# Wall jump logic
	if Game.has_ability("wall_jump"):
		if jump_buffer_timer > 0 and not is_jumping and is_on_wall_only() and wall_attach_timer <= 0:
			velocity = Vector2(get_wall_normal().x * WALL_JUMP_PUSHBACK, WALL_JUMP_VELOCITY.y)
			jump_buffer_timer = 0  # Reset jump buffer timer after wall jump
			wall_attach_timer = WALL_ATTACH_DELAY  # Start wall attach delay timer
			can_dash = true  # Reset can_dash after wall jump

		# Apply slight movement back towards the wall after wall jump
		if is_jumping and is_on_wall_only() and Input.get_axis("ui_left", "ui_right") == 0:
			velocity.x += get_wall_normal().x * WALL_JUMP_RETURN_FORCE * delta

		# Allow reattaching to the wall after the pushback
		if wall_attach_timer <= 0 and is_on_wall_only():
			velocity.x = 0  # Stop horizontal movement to allow reattachment

		if is_on_wall() and Input.get_axis("ui_left", "ui_right"):
			velocity.y = min(velocity.y, wall_slide_gravity)

	if Game.has_ability("dash"):
		# Handle dash
		if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0 and can_dash:
			start_dash()
			can_dash = false  # Disable further dashing until reset

	if attack_buffer_timer > 0:
		start_attack()
		attack_buffer_timer = 0  # Reset attack buffer timer after attack

	if Input.is_action_just_pressed("attack"):
		start_attack()

	# Handle animations
	if is_on_floor() and not is_attacking:
		if direction != 0:
			animated_sprite_2d.play("run")
		else:
			animated_sprite_2d.play("default")
	elif not is_on_floor() and not is_attacking:
		if velocity.y < 0:
			animated_sprite_2d.play("jump")
		elif velocity.y > 0:
			animated_sprite_2d.play("fall")
	else:
		pass

func start_attack():
	if is_attacking:
		return  # Ignore input if already attacking
		
	is_attacking = true  # Mark as attacking
	if Input.is_action_pressed("ui_up"):
		sword_up.disabled = false
		animated_sprite_2d.play("attack_up")
	elif Input.is_action_pressed("ui_down"):
		sword_down.disabled = false
		animated_sprite_2d.play("attack_down")
	else:
		if animated_sprite_2d.flip_h:  # If facing left
			sword_left.disabled = false
		else:  # If facing right
			sword_right.disabled = false
		animated_sprite_2d.play("attack")
	attack_timer.start()
	attack_buffer_timer = 0  # Reset attack buffer timer when attack starts

func start_dash():
	is_dashing = true
	dash_time_remaining = DASH_DURATION
	dash_cooldown_remaining = DASH_COOLDOWN

	# Reset vertical velocity to prevent gravity from affecting the dash
	velocity.y = 0

	# Determine dash direction and velocity
	if animated_sprite_2d.flip_h:
		velocity.x = -DASH_SPEED  # Dash left
		show_dash_effect("left")
	else:
		velocity.x = DASH_SPEED  # Dash right
		show_dash_effect("right")

	# Ensure can_dash is false after starting a dash
	can_dash = false

func handle_dash(delta):
	# Reduce the remaining dash time
	dash_time_remaining -= delta  # Frame-based dash time

	# Stop the dash when time runs out
	if dash_time_remaining <= 0:
		stop_dash()

func stop_dash():
	is_dashing = false
	velocity.x = 0  # Reset horizontal speed after dash

	# Hide dash effects
	hide_dash_effects()

	# Transition to appropriate animation
	if not is_on_floor():
		animated_sprite_2d.play("fall")
	else:
		animated_sprite_2d.play("default")

# Dash effect handling
func show_dash_effect(direction):
	if direction == "left":
		dash_effect_left.visible = true
		dash_effect_left.global_position = global_position
	elif direction == "right":
		dash_effect_right.visible = true
		dash_effect_right.global_position = global_position

func hide_dash_effects():
	dash_effect_left.visible = false
	dash_effect_right.visible = false

func spawn_dust():
	# Only spawn dust if the player is on the floor
	if is_on_floor():
		var dust_instance = DUST.instantiate()
		dust_instance.global_position = marker2d.global_position
		get_parent().add_child(dust_instance)
		
func shoot_projectile():
	can_shoot_projectile = false  # Disable further shooting for now
	var projectile = PROJECTILE.instantiate()  # Create the Vengeful Spirit
	get_parent().add_child(projectile)  # Add the projectile to the scene
	projectile.global_position = marker2d.global_position

	# Set the direction of the projectile
	if animated_sprite_2d.flip_h:
		projectile.direction = Vector2.LEFT  # Move left if facing left
		projectile.scale.x = -abs(projectile.scale.x)  # Flip horizontally
	else:
		projectile.direction = Vector2.RIGHT  # Move right if facing right
		projectile.scale.x = abs(projectile.scale.x)  # Ensure it's not flipped

	# After some time, allow the player to shoot again
	await get_tree().create_timer(1.0).timeout  # Cooldown for shooting the ability
	can_shoot_projectile = true  # Re-enable the ability
	
func die():
	if dead:
		return  # If already dead, do nothing
	dead = true
	velocity = Vector2.ZERO  # Stop all movement
	set_process(false)  # Disable `_process` and `_physics_process`
	set_physics_process(false)  # Specifically disable physics processing
	animated_sprite_2d.play("death")

func _on_attack_collision_area_entered(area):
	if area.is_in_group("enemies"):
		area.animated_sprite_2d.play("death")
		area.set_deferred("monitoring", false)  # Disable collision detection
		await area.animated_sprite_2d.animation_finished
		area.queue_free()

func _on_timer_timeout():
	sword_left.disabled = true
	sword_right.disabled = true
	sword_up.disabled = true
	sword_down.disabled = true
	is_attacking = false

