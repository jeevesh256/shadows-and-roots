extends CharacterBody2D

@onready var left = $sword/left
@onready var right = $sword/right
@onready var p_1 = $p1
@onready var p_2 = $p2
@onready var anim = $AnimatedSprite2D

var speed = 100
var direction = 1
var gravity = 980
var buffer = 5.0  # Small buffer for smoother direction changes

var left_marker
var right_marker

func _ready():
	left.disabled = true
	right.disabled = true
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
		# Simple patrol logic
		if position.x >= right_marker:
			direction = -1
			anim.flip_h = true
			anim.play("walk")
		elif position.x <= left_marker:
			direction = 1
			anim.flip_h = false
			anim.play("walk")
		
		velocity.x = direction * speed
		
		# Ensure walk animation is playing while moving
		if velocity.x != 0 and anim.animation != "walk":
			anim.play("walk")
	
	move_and_slide()
