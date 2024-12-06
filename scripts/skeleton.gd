extends Area2D

@onready var skeleton = $"."
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var player = null  # This will be assigned in _ready()
const SPEED = 100.0

func _on_body_entered(body):
	if body.is_in_group("players"):
		print("dead")
		if body.has_method("die"):
			body.die()

func _ready():
	# Find the player node in the scene tree
	player = get_tree().get_nodes_in_group("players")[0]

func _physics_process(delta):
	if player:
		# Calculate direction towards the player
		var direction = (player.global_position - global_position).normalized()
		
		# Calculate the distance to the player
		var distance = global_position.distance_to(player.global_position)
		
		# Move the enemy towards the player
		if distance > 0:
			var move_amount = SPEED * delta
			var move_vector = direction * min(move_amount, distance)
			global_position += move_vector

	
