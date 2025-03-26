extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
var is_hit = false

func _ready():
	animated_sprite_2d.play("idle")

func _on_area_2d_area_entered(area):
	if area.is_in_group("player_attack") and not is_hit:
		handle_hit()

func handle_hit():
	is_hit = true
	# Set animation to NOT loop and play it once
	animated_sprite_2d.sprite_frames.set_animation_loop("hit", false)
	animated_sprite_2d.play("hit")
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("idle")
	is_hit = false






