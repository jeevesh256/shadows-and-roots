extends CharacterBody2D

@onready var left = $sword/left
@onready var right = $sword/right
@onready var p_1 = $p1
@onready var p_2 = $p2

var speed = 100
var direction = 1
var gravity = 980
var buffer = 5.0  # Small buffer for smoother direction changes

var left_marker
var right_marker

func _ready():
	left.visible = false
	right.visible = true
	# Determine which marker is left and right
	if p_1.position.x < p_2.position.x:
		left_marker = p_1.position.x
		right_marker = p_2.position.x
	else:
		left_marker = p_2.position.x
		right_marker = p_1.position.x

func _physics_process(delta):
	# Apply gravity
	velocity.y += gravity * delta
	
	if is_on_floor():
		# Check position relative to markers with buffer
		if position.x >= (right_marker - buffer):
			direction = -1
			velocity.x = 0  # Reset velocity when changing direction
		elif position.x <= (left_marker + buffer):
			direction = 1
			velocity.x = 0  # Reset velocity when changing direction
			
		velocity.x = direction * speed
		
		# Update sword visibility
		left.visible = (direction < 0)
		right.visible = (direction > 0)
	
	move_and_slide()
