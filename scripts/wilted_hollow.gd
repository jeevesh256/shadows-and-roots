extends Node2D

const enemy_scene = preload("res://skeleton.tscn")
const BOSS_1 = preload("res://boss_1.tscn")
var has_spawned = false
var player_in_treasure_area = false
var game
var attack_collision_count = 0
var boss_spawned = false  # Add this new variable
@onready var treasure = $treasure
@onready var wall_jump_ability = $wall_jump_ability
@onready var treasure_animation = $treasure/treasure_animation
@onready var breakable_wall_3_collision = $"hidden walls/Breakable_wall3/static_shape"
@onready var breakable_wall_4_collision = $"hidden walls/Breakable_wall4/static_shape"
@onready var breakable_wall_3_sprite = $"hidden walls/Breakable_wall3/Sprite2D"
@onready var breakable_wall_4_sprite = $"hidden walls/Breakable_wall4/Sprite2D"
@onready var boss_mkr = $boss_area/boss_mkr

func _ready():
	game = get_tree().root.get_node("game")
	breakable_wall_3_sprite.visible = false
	breakable_wall_4_sprite.visible = false
	breakable_wall_3_collision.set_disabled(true)
	breakable_wall_4_collision.set_disabled(true)
	# Ensure the collision is disabled when the scene is loaded
	breakable_wall_3_collision.call_deferred("set_disabled", true)
	breakable_wall_4_collision.call_deferred("set_disabled", true)
	if Game.has_ability("wall_jump"):
		treasure_animation.play("opened")  # Play the "opened" animation if the player already has the wall jump ability
	

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
			var random_offset = Vector2(randi() % 800 - 400, randi() % 800 - 400)  # Offset around the point (1563, -1032)
			enemy_instance.position = Vector2(1563, -1032) + random_offset
			get_parent().add_child(enemy_instance)

func _on_treasure_body_entered(body):
	if body.name == "player":
		player_in_treasure_area = true

func _on_treasure_body_exited(body):
	if body.name == "player":
		player_in_treasure_area = false

func _on_hf_body_entered(body):
	if body.name == "player":
		Game.change_scene("res://haunted-farmlands.tscn", "player_from_wh")

func _on_boss_area_body_entered(body):
	if body.name == "player" and not boss_spawned:  # Check if boss hasn't spawned yet
		boss_spawned = true  # Set the flag
		if is_instance_valid(breakable_wall_3_sprite):
			breakable_wall_3_sprite.visible = true
		if is_instance_valid(breakable_wall_4_sprite):
			breakable_wall_4_sprite.visible = true
		if is_instance_valid(breakable_wall_3_collision):
			breakable_wall_3_collision.set_disabled(false)
			breakable_wall_3_collision.call_deferred("set_disabled", false)
		if is_instance_valid(breakable_wall_4_collision):
			breakable_wall_4_collision.set_disabled(false)
			breakable_wall_4_collision.call_deferred("set_disabled", false)
		var boss = BOSS_1.instantiate()
		boss.position = boss_mkr.position
		get_parent().add_child(boss)

