extends Area2D

const SPEED = 200.0
var direction
var is_random
var path_direction

func _ready():
	var dir_texture = load("res://Sprites/dir_acceleration.svg")
	var rand_texture = load("res://Sprites/rand_acceleration.svg")
	
	var raw_x = randi_range(-1, 1)
	var raw_y = (1 - abs(raw_x)) * randi_range(-1, 1)
	direction = Vector2(raw_x, raw_y).normalized().rotated(path_direction)
	if is_random:
		$Sprite2D.texture = rand_texture
	else:
		$Sprite2D.rotation = direction.angle() + PI/2.0
		$Sprite2D.texture = dir_texture

func _on_path_destroyed():
	queue_free()

func _on_collide(body):
	if body == $"/root/Main/Game/Player":
		$"/root/Main/Game/Player".speed_modifier += direction * SPEED
		$Timer.start(1.0)
		await $Timer.timeout
		$"/root/Main/Game/Player".speed_modifier -= direction * SPEED
