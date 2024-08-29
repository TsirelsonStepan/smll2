extends Area2D

var chaser_scene

func _ready():
	chaser_scene = preload("res://Scenes/chaser.tscn")

func _on_path_destroyed():
	queue_free()

func _on_collide(body):
	if body == $"/root/Main/Game/Player":
		$Timer.start(0.3)
		await $Timer.timeout
		var chaser = chaser_scene.instantiate()
		chaser.position = position
		$"/root/Main/Game".add_child(chaser)
