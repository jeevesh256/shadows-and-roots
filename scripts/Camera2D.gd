extends Camera2D

@export var smoothing_speed : float = 8.0  # How fast the camera follows the player
@export var horizontal_look_ahead : float = 100.0  # Horizontal look-ahead for anticipating player's movement
@export var vertical_look_ahead : float = 50.0  # Vertical look-ahead for jumps or falls
@export var camera_offset : Vector2 = Vector2(0, -50)  # Adjust the camera's vertical position

var player : Node2D = null  # Player node reference
var velocity : Vector2 = Vector2.ZERO  # Camera's current velocity (for damping)
var max_speed : float = 10.0  # Maximum speed of the camera

func _ready():
	# Find the player node (adjust this path if needed)
	player = get_parent().get_node("Player")

func _process(delta: float) -> void:
	if player:
		# Calculate the target camera position based on the player's position and offset
		var target_position = player.global_position + camera_offset
		
		# Add horizontal look-ahead if the player is moving fast
		if abs(player.velocity.x) > 10:  # Adjust this threshold based on your game
			target_position.x += sign(player.velocity.x) * horizontal_look_ahead
		
		# Add vertical look-ahead if the player is moving fast vertically (jump or fall)
		if abs(player.velocity.y) > 50:  # Adjust based on your player's jump/fall speed
			target_position.y += sign(player.velocity.y) * vertical_look_ahead
		
		# Smoothly interpolate the camera position using linear interpolation (lerp)
		global_position = global_position.lerp(target_position, smoothing_speed * delta)
		
		# Optional: Cap the camera's velocity to prevent too jerky movement
		velocity = global_position - global_position
		velocity = velocity.limit_length(max_speed)  # Limit the velocity for smooth transitions

		# Apply the velocity to the camera's position
		global_position += velocity
