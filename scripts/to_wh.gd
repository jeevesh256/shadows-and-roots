extends Area2D

func _on_body_entered(body):
	if body.name == "player":
		Game.change_scene("res://wilted_hollow.tscn", "from_hf")
