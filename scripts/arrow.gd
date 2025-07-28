extends StaticBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var marker_2d = $Marker2D
const PROJECTILE = preload("res://projectile.tscn")

func _ready():
	animated_sprite_2d.frame_changed.connect(_on_frame_changed)

func _on_frame_changed():
	if animated_sprite_2d.frame == 3:
		var projectile = PROJECTILE.instantiate()
		get_tree().current_scene.add_child(projectile)
		
		projectile.global_position = marker_2d.global_position
		
		# Assuming arrow sprite points DOWN by default
		projectile.direction = Vector2.DOWN.rotated(global_rotation).normalized()
		projectile.rotation = projectile.direction.angle()

func _process(delta):
	pass
