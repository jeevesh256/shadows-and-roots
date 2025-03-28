extends CharacterBody2D

# Constants
const JUMP_VELOCITY = -450.0  # Slightly stronger initial jump
const DASH_SPEED = 800.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.5
const MOVE_SPEED = 250.0
const GRAVITY = 1400.0  # Reduced from 1800.0 for more floatiness
const JUMP_FALL_GRAVITY = 1100.0  # Reduced from 1400.0 for more floaty falls
const TERMINAL_VELOCITY = 600.0  # Reduced from 700.0 for slower max fall speed
const JUMP_BUFFER_TIME = 0.1
const ATTACK_BUFFER_TIME = 0.1
const JUMP_CUT_GRAVITY = 4000.0  # Increased for snappier jump cuts
const JUMP_HOLD_GRAVITY = 1300.0  # Reduced from 1500.0 for slightly higher jumps
const AIR_ACCELERATION = 3000.0  # Increased for much better air control
const AIR_DECELERATION = 2000.0  # Increased for more responsive stopping
const AIR_MOVE_SPEED = 230.0  # New constant for air movement speed
const POGO_BOUNCE_FORCE = -700.0  # Increased from -600 for higher bounce
const PUSHBACK_FORCE = 150.0  # Reduced from 300 for gentler pushback
const PUSHBACK_DURATION = 0.1  # Slightly reduced pushback duration
const WALL_SLIDE_SPEED = 50.0  # Initial slower wall slide speed
const WALL_SLIDE_MAX_SPEED = 200.0  # Maximum wall slide speed
const WALL_SLIDE_ACCELERATION = 800.0  # Faster acceleration while sliding
const WALL_SLIDE_GRAVITY = 400.0  # Custom gravity while wall sliding
const JUMP_HOLD_TIME = 0.45  # Slightly longer hold time for more control
const JUMP_ACCELERATION = -1500.0  # Much stronger upward acceleration
const JUMP_MAX_VELOCITY = -850.0  # Higher maximum jump velocity
var pushback_timer = 0.0  # Track pushback duration

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
var attack_buffer_timer = 0.0  # Timer for attack buffering
var can_dash = true  # State variable to track if the player can dash

# Jump variables
var is_jumping = false
var jump_time = 0.0  # Time the jump button is held down
var jump_buffer_timer = 0.0  # Timer for jump buffering
var jump_pressed = false  # Track if jump was pressed

# Wall jump constants - adjusted for variable height
const WALL_JUMP_VELOCITY = Vector2(300, -400)  # Reduced initial vertical boost
const WALL_JUMP_HOLD_VELOCITY = -600  # Maximum vertical velocity when holding jump
const WALL_JUMP_HOLD_TIME = 0.2  # How long you can hold to gain height
var wall_jump_hold_timer = 0.0
var is_wall_jumping = false
const WALL_JUMP_PUSHBACK = 200.0  # Significantly reduced pushback
const WALL_JUMP_RETURN_FORCE = 15.0  # Reduced return force for smoother wall attachment
const WALL_ATTACH_DELAY = 0.1  # Delay before reattaching to the wall
var wall_attach_timer = 0.0  # Timer for wall attach delay
const WALL_JUMP_COOLDOWN = 0.2  # Cooldown time before another wall jump
var wall_jump_cooldown_timer = 0.0  # Timer for wall jump cooldown
var is_attacking = false
var attacks = 0

var invincible = false  
var iframe_duration = 1  # Short I-frame duration
var blink_speed = 0.1  # Faster blinking
	
func _ready():
	Game.player = self
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")  # Declare direction variable
	if pushback_timer > 0:
		pushback_timer -= delta
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
		elif velocity.y > 0:  # If falling
			velocity.y += GRAVITY * delta  # Natural falling
		else:  # If moving upward or at peak of jump
			velocity.y += JUMP_FALL_GRAVITY * delta  # Gentler fall during jump

	# Dash or normal movement
	if is_dashing:
		handle_dash(delta)
		move_and_slide()
		return  # Exit early if dashing, preventing all other actions
	else:
		handle_movement_and_jump(delta)
		
	if Game.has_ability("wall_jump"):
		# Simplified wall jump logic - only handle the jump, no sliding
		if jump_buffer_timer > 0 and not is_jumping and is_on_wall_only():
			velocity = Vector2(get_wall_normal().x * WALL_JUMP_PUSHBACK, WALL_JUMP_VELOCITY.y)
			jump_buffer_timer = 0
			can_dash = true

	if Game.has_ability("projectile") and Input.is_action_just_pressed("projectile") and can_shoot_projectile:
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
		if Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0 and can_dash:
			start_dash()
			can_dash = false  # Disable further dashing until reset

	if attack_buffer_timer > 0:
		start_attack()
		attack_buffer_timer = 0  # Reset attack buffer timer after attack

	if Input.is_action_just_pressed("attack"):
		start_attack()

	# Handle animations - modify the animation handling section
	if is_dashing:
		animated_sprite_2d.play("run")  # Always run animation while dashing
	elif is_on_floor() and not is_attacking:
		if direction != 0:
			animated_sprite_2d.play("run")
		else:
			animated_sprite_2d.play("default")
	elif not is_on_floor() and not is_attacking:
		if velocity.y < 0:
			animated_sprite_2d.play("jump")
		elif velocity.y > 0:
			animated_sprite_2d.play("fall")

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
		is_wall_jumping = false
		is_jumping = false  # Reset jump state when landing
		can_dash = true  # Reset can_dash when landing

	was_on_floor = is_on_floor_now
	is_on_ground = is_on_floor_now

func handle_movement_and_jump(delta):
	if is_dashing:  # Prevent movement control while dashing
		return
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Only allow normal movement if not in pushback
	if pushback_timer <= 0:
		# Different acceleration in air vs ground
		if is_on_floor():
			if direction != 0:
				velocity.x = direction * MOVE_SPEED
			else:
				velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
		else:
			 # Enhanced air control
			if direction != 0:
				# Faster acceleration in air while maintaining max speed
				velocity.x = move_toward(velocity.x, direction * AIR_MOVE_SPEED, AIR_ACCELERATION * delta)
				# Additional micro-adjustments during fall
				if velocity.y > 0:  # If falling
					velocity.x = move_toward(velocity.x, direction * AIR_MOVE_SPEED, AIR_ACCELERATION * 0.5 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, AIR_DECELERATION * delta)
	
	if direction != 0:
		animated_sprite_2d.flip_h = direction < 0

	# Apply gravity with terminal velocity and wall slide
	if not is_dashing and not is_on_ground:
		if is_wall_sliding():
			 # More nuanced wall slide physics
			if velocity.y < 0:  # If moving upward, use normal gravity
				velocity.y += GRAVITY * delta
			else:
				# Start with a gentle slide and accelerate
				var target_speed = WALL_SLIDE_SPEED
				if Input.is_action_pressed("ui_down"):
					target_speed = WALL_SLIDE_MAX_SPEED  # Faster slide when pressing down
				
				# Gradually increase fall speed
				velocity.y = move_toward(velocity.y, target_speed, WALL_SLIDE_ACCELERATION * delta)
				velocity.y += WALL_SLIDE_GRAVITY * delta
				velocity.y = min(velocity.y, WALL_SLIDE_MAX_SPEED)
		elif is_jumping and not Input.is_action_pressed("jump"):
			velocity.y += JUMP_CUT_GRAVITY * delta
		elif velocity.y > 0:  # If falling
			velocity.y += GRAVITY * delta  # Natural falling
		else:  # If moving upward or at peak of jump
			velocity.y += JUMP_FALL_GRAVITY * delta  # Gentler fall during jump
		
		# Limit falling speed
		velocity.y = min(velocity.y, TERMINAL_VELOCITY)

	# Buffer jump input
	if jump_pressed and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY  # Initial smaller jump force
		is_jumping = true
		jump_time = 0
		coyote_timer = 0
		jump_buffer_timer = 0
		jump_pressed = false
		can_dash = true

	# Gradual jump height increase
	if is_jumping:
		jump_time += delta
		if jump_time < JUMP_HOLD_TIME and Input.is_action_pressed("jump"):
			# Apply stronger upward force while holding jump
			velocity.y += JUMP_ACCELERATION * delta
			velocity.y = max(velocity.y, JUMP_MAX_VELOCITY)  # Cap at higher maximum velocity
		else:
			is_jumping = false

	# Wall jump logic with variable height
	if Game.has_ability("wall_jump"):
		if jump_buffer_timer > 0 and not is_jumping and is_on_wall_only():
			velocity = Vector2(get_wall_normal().x * WALL_JUMP_PUSHBACK, WALL_JUMP_VELOCITY.y)
			is_wall_jumping = true
			wall_jump_hold_timer = 0
			jump_buffer_timer = 0
			can_dash = true  # Reset dash specifically after wall jump
		
		# Variable wall jump height control
		if is_wall_jumping:
			wall_jump_hold_timer += delta
			if wall_jump_hold_timer < WALL_JUMP_HOLD_TIME and Input.is_action_pressed("jump"):
				velocity.y = move_toward(velocity.y, WALL_JUMP_HOLD_VELOCITY, 2000 * delta)
			else:
				is_wall_jumping = false

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

func is_wall_sliding():
	if not Game.has_ability("wall_jump"):
		return false
	
	if not is_on_wall_only():
		return false
		
	# Check if pressing towards the wall
	var direction = Input.get_axis("ui_left", "ui_right")
	var wall_normal = get_wall_normal()
	
	# If pressing in the opposite direction of the wall normal
	return direction * wall_normal.x < 0

func start_attack():
	if is_attacking or is_dashing:  # Prevent attacking while dashing
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
	animated_sprite_2d.play("run")

	velocity.y = 0

	var dash_direction = 0
	
	# If wall sliding, dash in the direction of the wall normal (away from wall)
	if is_wall_sliding():
		dash_direction = get_wall_normal().x
		animated_sprite_2d.flip_h = dash_direction < 0  # Flip sprite to face dash direction
	else:
		# Normal dash direction logic
		dash_direction = Input.get_axis("ui_left", "ui_right")
		if dash_direction == 0:
			dash_direction = -1 if animated_sprite_2d.flip_h else 1
	
	velocity.x = dash_direction * DASH_SPEED
	show_dash_effect("left" if dash_direction < 0 else "right")
	
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
	if is_dashing:  # Prevent shooting while dashing
		return
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
	set_process_input(false)  # Disable input processing
	set_physics_process(false)  # Disable physics processing
	animated_sprite_2d.play("death")

func _on_animation_finished():
	if animated_sprite_2d.animation == "death":
		pass

func _on_attack_collision_area_entered(area):
	if area.is_in_group("enemies"):
		area.animated_sprite_2d.play("death")
		area.set_deferred("monitoring", false)
		
		handle_pogo_or_pushback()
		await area.animated_sprite_2d.animation_finished
		area.queue_free()
	elif area.is_in_group("can_pogo") and sword_down.disabled == false:
		handle_pogo_or_pushback()

func _on_attack_collision_body_entered(body):
	if body.is_in_group("enemies"):
		attacks += 1
		if attacks == 15:
			body.animated_sprite_2d.play("death")
			body.queue_free()
			attacks = 0
	
	if body.is_in_group("mushroom"):
		get_health(1)
		handle_pogo_or_pushback()		

	elif body.is_in_group("can_pogo") and sword_down.disabled == false:
		handle_pogo_or_pushback()

# Add this new helper function
func handle_pogo_or_pushback():
	if sword_down.disabled == false:  # If down attacking (pogo)
		velocity.y = POGO_BOUNCE_FORCE
		var horizontal_input = Input.get_axis("ui_left", "ui_right")
		if horizontal_input != 0:
			velocity.x = horizontal_input * MOVE_SPEED * 0.8
	else:  # For all other attacks
		var direction = -1 if animated_sprite_2d.flip_h else 1
		velocity.x = -PUSHBACK_FORCE * direction
		pushback_timer = PUSHBACK_DURATION

func _on_timer_timeout():
	sword_left.disabled = true
	sword_right.disabled = true
	sword_up.disabled = true
	sword_down.disabled = true
	is_attacking = false

func damage(point):
	if invincible:
		return
	
	Game.modify_health(-point)
	start_invincibility()

func start_invincibility():
	if dead:
		return
	invincible = true
	collision_layer = 0
	get_tree().create_timer(iframe_duration).timeout.connect(end_invincibility)
	blink_sprite()

func blink_sprite():
	if invincible:
		animated_sprite_2d.self_modulate = Color.NAVY_BLUE if animated_sprite_2d.self_modulate == Color.WHITE else Color.WHITE
		get_tree().create_timer(blink_speed).timeout.connect(blink_sprite)

func get_health(point):
	Game.modify_health(point)
	print("+1 health")

func end_invincibility():
	invincible = false
	animated_sprite_2d.self_modulate = Color.WHITE  # Reset sprite color
	collision_layer = 1  # Reset collision layer to original value
