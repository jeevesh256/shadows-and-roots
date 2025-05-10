extends CharacterBody2D

@onready var left = $sword/left
@onready var right = $sword/right
@onready var p_1 = $p1
@onready var p_2 = $p2
@onready var anim = $AnimatedSprite2D
@onready var hitbox = $hitbox
@onready var detection_area = $detection_area

var speed = 100
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

func _ready():
	left.disabled = true
	right.disabled = true
	anim.animation_finished.connect(_on_animation_finished)
	# Determine which marker is left and right
	if p_1.position.x < p_2.position.x:
		left_marker = p_1.position.x
		right_marker = p_2.position.x
	else:
		left_marker = p_2.position.x
		right_marker = p_1.position.x

func _physics_process(delta):
	velocity.y += gravity * delta
	
	if is_on_floor():
		if player_in_range and current_player:
			if can_attack and not is_attacking:
				direction = sign(current_player.position.x - position.x)
				anim.flip_h = (direction < 0)
				start_attack()
			elif is_attacking:
				velocity.x = 0
		else:
			# Resume patrol if no player or player left detection area
			is_attacking = false
			if position.x >= right_marker:
				direction = -1
				anim.flip_h = true
				anim.play("walk")
			elif position.x <= left_marker:
				direction = 1
				anim.flip_h = false
				anim.play("walk")
			
			velocity.x = direction * speed
			if velocity.x != 0 and anim.animation != "walk":
				anim.play("walk")

	move_and_slide()

func start_attack():
	is_attacking = true
	velocity.x = 0
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

func _on_detection_area_body_exited(body):
	if body.is_in_group("players"):
		player_in_range = false
		current_player = null
		# Reset attack state when player leaves
		is_attacking = false
		left.disabled = true
		right.disabled = true
