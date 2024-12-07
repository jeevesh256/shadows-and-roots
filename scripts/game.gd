extends Node2D

var abilities = {
	"wall_jump": false,
	"dash": false
}

func _ready():
	# Ensure this node persists across scenes
	set_process_unhandled_input(true)
	# Enable auto accept quit to avoid blocking application exit
	get_tree().set_auto_accept_quit(true)
	# Connect the "node_removed" signal properly using Callable
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))

func _on_node_removed(node):
	# If this autoload node is removed, re-add it to the root
	if node == self:
		get_tree().root.add_child(self)

func obtain_ability(ability_name: String):
	# Unlock a specific ability
	if abilities.has(ability_name):
		abilities[ability_name] = true

func has_ability(ability_name: String) -> bool:
	# Check if a specific ability is unlocked
	return abilities.get(ability_name, false)

func _on_quit_requested():
	# Handle the quit logic if needed
	get_tree().quit()
