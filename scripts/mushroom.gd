extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var respawn = $respawn
var is_hit = false

func _ready():
	animated_sprite_2d.play("idle")
	Game.register_respawn_point(respawn)

func _on_area_2d_area_entered(area):
	if area.is_in_group("player_attack") and not is_hit:
		var attack_position = area.global_position
		animated_sprite_2d.flip_h = attack_position.x > global_position.x
		handle_hit()

func handle_hit():
	if is_hit:
		return
		
	is_hit = true
	animated_sprite_2d.sprite_frames.set_animation_loop("hit", false)
	animated_sprite_2d.play("hit")
	
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("idle")
	is_hit = false






