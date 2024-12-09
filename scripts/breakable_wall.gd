extends StaticBody2D

var attack_collision_count = 0

func _on_wall_collision_area_entered(area):
	if area.name == "attack_collision":
		attack_collision_count += 1
		if attack_collision_count >= 3:
			queue_free()
