extends Area2D

const enemy_scene = preload("res://skeleton.tscn")
var has_spawned = false

func _on_body_entered(body):
	if body.name == "player" and not has_spawned:
		has_spawned = true
		for i in range(5):
			var enemy_instance = enemy_scene.instantiate()
			var random_offset = Vector2(randi() % 800 - 400, randi() % 800 - 400)
			enemy_instance.position = body.position + random_offset
			get_parent().add_child(enemy_instance)
