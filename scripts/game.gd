extends Node2D

# Reference to the player
var player = null

# Abilities dictionary
var abilities = {
	"wall_jump": false,
	"dash": true,
	"projectile": true
}

func _ready():
	# Ensure this node persists across scenes
	set_process_unhandled_input(true)
	get_tree().set_auto_accept_quit(true)

	# Connect the "node_removed" signal properly
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))

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
