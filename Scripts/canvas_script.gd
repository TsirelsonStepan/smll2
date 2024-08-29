extends CanvasLayer

var game

func _ready():
	game = preload("res://Scenes/game.tscn")

func _on_restart_button_pressed():
	$"../Game".queue_free()
	var new_game = game.instantiate()
	new_game.get_node("Player").is_game_over = true
	$Panel.visible = false
	$"..".add_child(new_game)
	
	$Timer.start(1.0)
	await $Timer.timeout
	
	new_game.name = "Game"
	new_game.get_node("Player").is_game_over = false
