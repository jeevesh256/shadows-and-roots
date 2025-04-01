extends StaticBody2D

var attack_collision_count = 0
var player_in_area = false

func _on_wall_collision_area_entered(area):
	if area.name == "attack_collision" and player_in_area:
		attack_collision_count += 1
		if attack_collision_count >= 3:
			queue_free()

func _on_wall_collision_body_entered(body):
	if body.name == "player":
		player_in_area = true

func _on_wall_collision_body_exited(body):
	if body.name == "player":
		player_in_area = false
