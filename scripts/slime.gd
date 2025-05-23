extends Area2D

var previous_position = Vector2.ZERO
@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready():
	previous_position = position

func _process(_delta):
	var velocity = (position - previous_position).normalized()
	if velocity.x < 0:
		animated_sprite_2d.flip_h = true
	elif velocity.x > 0:
		animated_sprite_2d.flip_h = false
	previous_position = position

func _on_body_entered(body):
	if body.name == "player":
		body.damage(1)
