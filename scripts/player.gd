extends CharacterBody2D

# Constants
const JUMP_VELOCITY = -400.0  # Base jump velocity (fixed)
const DASH_SPEED = 800.0  # Dash speed (fixed)
const DASH_DURATION = 0.2  # Dash duration (in seconds)
const DASH_COOLDOWN = 0.5  # Dash cooldown (in seconds)
const MOVE_SPEED = 300.0  # Movement speed (fixed)
const GRAVITY = 1200.0  # Fixed gravity (constant per frame)

# Nodes
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var marker2d = $Marker_dust
@onready var dash_effect_left = $dash2
@onready var dash_effect_right = $dash1
const DUST = preload("res://dust.tscn")
const PROJECTILE = preload("res://projectile.tscn")
@onready var attack_timer = $attack_collision/Timer

# State variables
var was_on_floor = false
var is_dashing = false
var dash_time_remaining = 0.0
var dash_cooldown_remaining = 0.0
var coyote_timer = 0.0  # Timer for coyote time
var is_on_ground = false
var can_shoot_projectile = true
var dead=false
var wall_slide_gravity = 100

# Jump variables
var is_jumping = false
var jump_time = 0.0  # Time the jump button is held down
const JUMP_HOLD_TIME = 0.1  # Max time to hold the jump for a higher jump

const WALL_JUMP_VELOCITY = Vector2(1500, -400)  # Adjust this to your desired pushback and jump power
const wall_jump_pushback = 300  # Horizontal pushback when wall jumping
const jump_power = -400  # The vertical jump force
@onready var sword_left = $attack_collision/sword_left
@onready var sword_right = $attack_collision/sword_right
@onready var sword_up = $attack_collision/sword_up
@onready var sword_down = $attack_collision/sword_down
var is_attacking = false

func _physics_process(delta):
	if not is_attacking:
		sword_left.disabled = true
		sword_right.disabled = true
		sword_up.disabled = true
		sword_down.disabled = true
	# Cooldowns and timers
	update_dash_cooldown(delta)
	update_coyote_timer(delta)

	# Check landing
	handle_landing()

	# Apply gravity
	if not is_dashing and not is_on_ground:
		velocity.y += GRAVITY * delta  # Apply gravity consistently per frame

	# Dash or normal movement
	if is_dashing:
		handle_dash(delta)
	else:
		handle_movement_and_jump(delta)
		
	if is_on_wall() and Input.get_axis("ui_left", "ui_right"):
		velocity.y = min(velocity.y, wall_slide_gravity)  
	
	if Input.is_action_just_pressed("projectile") and can_shoot_projectile:
		shoot_projectile()

	# Apply movement
	move_and_slide()

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

func handle_landing():
	var is_on_floor_now = is_on_floor()

	# Spawn dust only when landing
	if not was_on_floor and is_on_floor_now:
		spawn_dust()

	# Reset jump state if we land
	if is_on_floor_now:
		is_jumping = false  # Reset jump state when landing

	was_on_floor = is_on_floor_now
	is_on_ground = is_on_floor_now

func handle_movement_and_jump(delta):
	# Handle horizontal movement
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * MOVE_SPEED
		animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)

	# Prevent double jump by checking if already jumping or in air
	if Input.is_action_just_pressed("jump") and not is_jumping and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY  # Apply fixed initial jump force
		is_jumping = true  # Mark as jumping
		jump_time = 0  # Reset jump time when jump is pressed
		coyote_timer = 0  # Reset coyote timer after a jump
		
	# Wall jump logic
	if Input.is_action_just_pressed("jump"):  # If jump button is pressed
		if is_on_floor():  # Regular jump when on the floor
			velocity.y = JUMP_VELOCITY
		elif is_on_wall_only():  # Wall jump logic
			velocity = Vector2(get_wall_normal().x * WALL_JUMP_VELOCITY.x, WALL_JUMP_VELOCITY.y)


	# While in the air, check for jump height control
	if is_jumping:
		if Input.is_action_pressed("jump") and jump_time < JUMP_HOLD_TIME:
			# Apply fixed jump force while holding jump
			velocity.y = JUMP_VELOCITY
			jump_time += delta  # Frame-based jump time
		elif not Input.is_action_pressed("jump"):
			# Start falling faster if jump button is released
			velocity.y += GRAVITY * delta  # Apply gravity per frame

	# Handle dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0:
		start_dash()
		
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
		
	is_attacking = true  # Mark as attackin
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
	dead = true
	velocity = Vector2.ZERO  # Stop all movement
	set_process(false)  # Disable `_process` and `_physics_process`
	set_physics_process(false)  # Specifically disable physics processing
	animated_sprite_2d.play("death")

func _on_attack_collision_area_entered(area):
	if area.is_in_group("enemies"):
		area.queue_free()

func _on_timer_timeout():
	sword_left.disabled = true
	sword_right.disabled = true
	sword_up.disabled = true
	sword_down.disabled = true
	is_attacking = false

