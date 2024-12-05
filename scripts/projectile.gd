extends Area2D

# Constants
const SPEED = 1000  # Speed of the spirit
const LIFETIME = 3.0  # Time before the projectile disappears

# Variables
var direction = Vector2.ZERO  # Direction of the projectile

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var timer = $Timer

func _ready():
	timer.wait_time = LIFETIME
	timer.start()

func _process(delta):
	# Move the projectile
	position += direction * SPEED * delta

func _on_Timer_timeout():
	queue_free()  # Destroy the projectile after it has existed for LIFETIME

# Collision detection
func _on_area_entered(area):
	print(area.name)
	if area.is_in_group("enemies"):
		area.queue_free()
