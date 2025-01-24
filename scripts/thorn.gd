extends Area2D

func _on_body_entered(body):
	if body.is_in_group("players"):
		if body.has_method("die"):
			body.die()


func _on_area_entered(area):
	if area.is_in_group("enemies"):
		area.queue_free()
