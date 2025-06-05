extends Area2D

var previous_position = Vector2.ZERO
@onready var animated_sprite_2d = $AnimatedSprite2D
var attacks = 0
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

func _on_area_entered(area):
	# Check if the area is any of the sword hitboxes
	if area.is_in_group("player_attack"):
		attacks += 1
		if attacks == 3:
			animated_sprite_2d.play("death")
			await animated_sprite_2d.animation_finished
			queue_free()
