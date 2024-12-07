extends Node2D

const enemy_scene = preload("res://skeleton.tscn")
var has_spawned = false
var player_in_treasure_area = false
var game
var attack_collision_count = 0
@onready var treasure = $treasure
@onready var wall_jump_ability = $wall_jump_ability
@onready var treasure_animation = $treasure/treasure_animation
@onready var wall_collision = $"breakable wall/wall_collision"
@onready var breakable_wall = $"breakable wall"

func _ready():
	game = get_tree().root.get_node("game")

func _process(delta):
	if player_in_treasure_area and not Game.has_ability("wall_jump"):
		if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_up"):
			wall_jump_ability.show()
			treasure_animation.play("open")
			await treasure_animation.animation_finished
			print("you have got the wall jump ability")
			Game.obtain_ability("wall_jump")
			treasure.queue_free()
			

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

func _on_wall_collision_area_entered(area):
	if area.name == "attack_collision":
		attack_collision_count += 1
		if attack_collision_count >= 3:
			breakable_wall.queue_free()

