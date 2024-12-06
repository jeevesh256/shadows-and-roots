extends Node2D

const enemy_scene = preload("res://skeleton.tscn")
var has_spawned = false
var player_in_treasure_area = false
var game

func _ready():
	game = get_tree().root.get_node("game")

func _process(delta):
	if player_in_treasure_area and not Game.has_ability("wall_jump"):
		if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_up"):
			print("you have got the wall jump ability")
			Game.obtain_ability("wall_jump")

func _on_ghost_spawn_body_entered(body):
	if body.name == "player" and not has_spawned:
		has_spawned = true
		for i in range(5):
			var enemy_instance = enemy_scene.instantiate()
			var random_offset = Vector2(randi() % 800 - 400, randi() % 1500 - 750)
			enemy_instance.position = body.position + random_offset
			get_parent().add_child(enemy_instance)

func _on_treasure_body_entered(body):
	if body.name == "player":
		player_in_treasure_area = true

func _on_treasure_body_exited(body):
	if body.name == "player":
		player_in_treasure_area = false
