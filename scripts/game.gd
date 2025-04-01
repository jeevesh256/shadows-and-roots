extends Node2D

# Reference to the player
var player = null

signal health_changed(current: int, maximum: int)

# Abilities dictionary
var abilities = {
	"wall_jump": false,
	"dash": true,
	"projectile": true
}

# Health system
var max_health = 5
var current_health = 5
var is_dead = false

var current_respawn_point = null

func _ready():
	# Ensure this node persists across scenes
	set_process_unhandled_input(true)
	get_tree().set_auto_accept_quit(true)

	# Connect the "node_removed" signal properly
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))
	
	# Initial health UI update
	emit_signal("health_changed", current_health, max_health)

func _on_node_removed(node):
	if node == self:
		get_tree().root.add_child(self)

# Function to unlock abilities
func obtain_ability(ability_name: String):
	if abilities.has(ability_name):
		abilities[ability_name] = true

# Check if a specific ability is unlocked
func has_ability(ability_name: String) -> bool:
	return abilities.get(ability_name, false)

# Function to modify health
func modify_health(amount: int):
	current_health = clamp(current_health + amount, 0, max_health)
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0 and not is_dead:
		is_dead = true
		if is_instance_valid(player):
			# Make sure player dies before respawning
			player.die()
			if current_respawn_point == null:
				push_error("No respawn point set!")

# Function to handle player death
func die():
	if is_dead:
		return
	is_dead = true
	if is_instance_valid(player):
		player.die()

func register_respawn_point(point):
	current_respawn_point = point

func respawn():
	if not current_respawn_point:
		push_error("Cannot respawn - no respawn point set")
		return
		
	is_dead = false
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	if is_instance_valid(player):
		player.global_position = current_respawn_point.global_position
		player.respawn()

func get_current_health() -> int:
	return current_health

func reset_health():
	current_health = max_health
	is_dead = false

# Handle quitting the game
func _on_quit_requested():
	get_tree().quit()

# Function to change scenes and spawn player at marker position
func change_scene(scene_path: String, marker_name: String):
	var new_scene = load(scene_path).instantiate()

	# Safely clean up the previous scene
	if get_tree().current_scene:
		get_tree().current_scene.queue_free()

	# Add the new scene to the root and set it as the current scene
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	# Reassign the player reference in the new scene
	player = new_scene.get_node_or_null("player")

	if not player:
		print("Player node not found in the new scene")
		return

	# Safely find the spawn marker in the new scene
	var marker = new_scene.get_node_or_null(marker_name)

	if marker:
		# Ensure we only access the position if the marker exists
		if is_instance_valid(player) and is_instance_valid(marker):
			player.global_position = marker.global_position
		else:
			print("Player or marker instance is no longer valid")
	else:
		print("Spawn marker not found: " + marker_name)
