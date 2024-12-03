extends Area2D

func _on_body_entered(body):
	print("you are dead")
	body.get_node("CollisionShape2D").queue_free()
