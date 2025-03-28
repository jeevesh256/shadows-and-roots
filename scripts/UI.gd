extends CanvasLayer

@onready var health_container = $Control/hearts_container

func _ready():
	# Connect to the Game singleton's health_changed signal
	Game.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, maximum: int):
	# Hide all sprites first
	for sprite in health_container.get_children():
		sprite.visible = false
	
	# Show sprites based on current health
	for i in range(current):
		if i < health_container.get_child_count():
			health_container.get_child(i).visible = true
