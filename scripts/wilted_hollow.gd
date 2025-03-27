extends Node2D

const enemy_scene = preload("res://skeleton.tscn")
const BOSS_1 = preload("res://boss_1.tscn")
var has_spawned = false
var has_spawned2 = false
var player_in_treasure_wj_area = false
var player_in_treasure_dash_area = false
var game
var attack_collision_count = 0
var boss_spawned = false  # Add this new variable
@onready var treasure1 = $treasure_wj
@onready var treasure2 = $treasure_dash
@onready var wall_jump_ability = $wall_jump_ability
@onready var treasure_animation1 = $treasure_wj/treasure_animation
@onready var treasure_animation2 = $treasure_dash/treasure_animation
@onready var breakable_wall_3_collision = $"hidden walls/Breakable_wall3/static_shape"
@onready var breakable_wall_4_collision = $"hidden walls/Breakable_wall4/static_shape"
@onready var breakable_wall_3_sprite = $"hidden walls/Breakable_wall3/Sprite2D"
@onready var breakable_wall_4_sprite = $"hidden walls/Breakable_wall4/Sprite2D"
@onready var boss_mkr = $boss_area/boss_mkr
@onready var dash_ability = $dash_ability
@onready var tile_map = $TileMap
@onready var health_ui = $UI/Control
@onready var camera_2d = $player/Marker_drag/Camera2D


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
		treasure_animation1.play("opened")  # Play the "opened" animation if the player already has the wall jump ability
	if Game.has_ability("dash"):
		treasure_animation2.play("opened")

func _process(delta):
	if player_in_treasure_wj_area and not Game.has_ability("wall_jump"):
		if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_up"):
			wall_jump_ability.show()
			treasure_animation1.play("open")
			await treasure_animation1.animation_finished
			print("you have got the wall jump ability")
			Game.obtain_ability("wall_jump")
			treasure1.queue_free()
	if player_in_treasure_dash_area and not Game.has_ability("dash"):
		if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("ui_up"):
			dash_ability.show()
			treasure_animation2.play("open")
			await treasure_animation2.animation_finished
			print("you have got the dash ability")
			Game.obtain_ability("dash")
			treasure2.queue_free()
	health_ui.position = Vector2(230, 23)  # Adjust (x, y) for padding if needed



func _on_ghost_spawn_body_entered(body):
	if body.name == "player" and not has_spawned:
		has_spawned = true
		var enemy_instance = enemy_scene.instantiate()
		enemy_instance.position = Vector2(1500, -920)  # Fixed position for single skeleton
		get_parent().add_child(enemy_instance)

func _on_treasure_body_entered(body):
	if body.name == "player":
		player_in_treasure_wj_area = true

func _on_treasure_body_exited(body):
	if body.name == "player":
		player_in_treasure_wj_area = false

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

func _on_treasure_dash_body_entered(body):
	if body.name == "player":
		player_in_treasure_dash_area = true
		
func _on_treasure_dash_body_exited(body):
	if body.name == "player":
		player_in_treasure_dash_area = false


func _on_area_2d_body_entered(body):
	if body.name == "player": 
		tile_map.set_layer_enabled(3,false)


func _on_ghost_spawn_2_body_entered(body):
	if body.name == "player" and not has_spawned2:
		has_spawned2 = true
		var enemy_instance = enemy_scene.instantiate()
		enemy_instance.position = Vector2(1982, -849)  # Fixed position for single skeleton
		get_parent().add_child(enemy_instance)
