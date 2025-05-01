extends AnimatedSprite2D

@onready var collision_shape_2d = $Area2D/CollisionShape2D
@onready var collision_shape_2d_2 = $Area2D/CollisionShape2D2
@onready var collision_shape_2d_3 = $Area2D/CollisionShape2D3

func _ready():
	frame_changed.connect(_on_frame_changed)
	# Set initial collision state
	collision_shape_2d.disabled = false
	collision_shape_2d_2.disabled = true
	collision_shape_2d_3.disabled = true

func _on_frame_changed():
	# Reset all collisions
	collision_shape_2d.disabled = true
	collision_shape_2d_2.disabled = true
	collision_shape_2d_3.disabled = true
	
	# Set appropriate collision based on frame
	if frame == sprite_frames.get_frame_count(animation) - 1:
		collision_shape_2d_3.disabled = false
	elif frame in [0, 1]:
		collision_shape_2d_2.disabled = false
	else:
		collision_shape_2d.disabled = false

func _process(delta):
	pass


func _on_area_2d_body_entered(body):
	if body.name == "player":
		print("die")
		body.damage(1)
