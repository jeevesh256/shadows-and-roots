extends StaticBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var marker_2d = $Marker2D
const PROJECTILE = preload("res://projectile.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	animated_sprite_2d.frame_changed.connect(_on_frame_changed)

func _on_frame_changed():
	if animated_sprite_2d.frame == 3:  # Frame 4 (0-based index)
		var projectile = PROJECTILE.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = marker_2d.global_position
		projectile.direction = Vector2.RIGHT


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
