extends Node

@onready var health_ui = $UI/Control

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if health_ui:
		health_ui.position = Vector2(230, 23)


func _on_to_wh_body_entered(body):
	if body.name == "player":
		Game.change_scene("res://wilted_hollow.tscn", "player_from_cr")
