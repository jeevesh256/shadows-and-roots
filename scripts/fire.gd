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
	if !timer:
		timer = Timer.new()
		add_child(timer)
		timer.timeout.connect(_on_Timer_timeout)
	timer.wait_time = LIFETIME
	timer.start()

func _process(delta):
	# Move the projectile
	position += direction * SPEED * delta

func _on_Timer_timeout():
	queue_free()  # Destroy the projectile after it has existed for LIFETIME

# Collision detection
func _on_area_entered(area):
	if area.is_in_group("enemies"):
		area.queue_free()

func _on_body_entered(body):
	if body is TileMap:
		queue_free()
	elif body.is_in_group("enemies"):
		body.queue_free()
	elif body.is_in_group("mushroom"):
		queue_free()
