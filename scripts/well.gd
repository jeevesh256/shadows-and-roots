extends Area2D

var marker = "default_marker"
func _on_body_entered(body):
	if body.is_in_group("players"):
		Game.change_scene("res://wilted_hollow.tscn",marker)
