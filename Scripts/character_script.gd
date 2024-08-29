extends RigidBody2D

const SPEED = 500.0

var speed_modifier = Vector2(0, 0)
var past_points = []
var current_index

@onready var main_way = $"../MainWay"
var path_points = 30
var way_scene
var split_scene
var path_length = 30

func _ready():
	contact_monitor = true
	max_contacts_reported = 2
	way_scene = preload("res://Scenes/way.tscn")
	split_scene = preload("res://Scenes/split_2.tscn")
	current_index = 2
	position = main_way.curve.get_point_position(current_index)
	past_points.append(position)

func _physics_process(_delta):
	if !is_game_over: linear_velocity = speed_modifier + Vector2(SPEED, 0).rotated(rotation)
	var mouse_position = get_global_mouse_position()
	if !is_game_over: look_at(mouse_position)
	
	#var offset = main_way.curve.get_closest_offset(position.rotated(main_way.rotation) - main_way.position)
	#var dir = main_way.curve.sample_baked_with_rotation(offset).get_rotation() - rotation
	#if (dir - rotation) < -1.8*PI: print("Achievement")

	var distance_to_current_point = (position - main_way.curve.get_point_position(current_index) - main_way.position).length()
	var distance_to_next_point = (position - main_way.curve.get_point_position(current_index + 1) - main_way.position).length()
	if distance_to_current_point > distance_to_next_point && potential_paths.size() == 0:
		if path_points >= path_length:
			await _split_road()
			path_points = 0
		else:
			main_way._prolong_road(0.5)
			main_way._shorten_road()
			for i in to_remove: i.queue_free()
			to_remove = []
		path_points += 1

func _split_road():
	var split = split_scene.instantiate()
	split.position = main_way.position + main_way.current_point
	var line_length = main_way.get_node("Line2DRight").points.size() - 1
	var rotat = (main_way.get_node("Line2DRight").get_point_position(line_length) - main_way.get_node("Line2DLeft").get_point_position(line_length)).rotated(PI/2.0)
	split.rotation = (rotat.rotated(main_way.rotation + PI/2.0)).angle()
	$"..".add_child(split)
	var curve1 = split.get_node("Way").curve
	var curve2 = split.get_node("Way2").curve
	split.get_node("Way").curve = Curve2D.new()
	split.get_node("Way2").curve = Curve2D.new()
	for i in curve1.point_count: split.get_node("Way").curve.add_point(curve1.get_point_position(i), curve1.get_point_in(i), curve1.get_point_out(i))
	for i in curve2.point_count: split.get_node("Way2").curve.add_point(curve2.get_point_position(i), curve2.get_point_in(i), curve2.get_point_out(i))
	
	var left_last_point = main_way.position + main_way.left_line.get_point_position(main_way.left_line.points.size() - 1)
	var right_last_point = main_way.position + main_way.right_line.get_point_position(main_way.right_line.points.size() - 1)
	
	split.get_node("Line2D3").set_point_position(0, split.get_node("Way/Line2DLeft").get_point_position(0))
	split.get_node("Line2D3").set_point_position(2, split.get_node("Way2/Line2DRight").get_point_position(0))
	
	split.get_node("Line2DRight").set_point_position(0, (left_last_point - split.position).rotated(-split.rotation))
	split.get_node("Line2DLeft").set_point_position(0, (right_last_point - split.position).rotated(-split.rotation))
	split.get_node("Line2DLeft").set_point_position(1, split.get_node("Way/Line2DRight").get_point_position(0))
	split.get_node("Line2DRight").set_point_position(1, split.get_node("Way2/Line2DLeft").get_point_position(0))

	split.get_node("StaticBody2D/LeftUpperCollider").shape.a = split.get_node("Line2D3").get_point_position(1)
	split.get_node("StaticBody2D/LeftUpperCollider").shape.b = split.get_node("Line2D3").get_point_position(0)
	split.get_node("StaticBody2D/RightUpperCollider").shape.a = split.get_node("Line2D3").get_point_position(1)
	split.get_node("StaticBody2D/RightUpperCollider").shape.b = split.get_node("Line2D3").get_point_position(2)
	
	split.get_node("StaticBody2D/LeftCollider").shape.a = split.get_node("Line2DLeft").get_point_position(0)
	split.get_node("StaticBody2D/LeftCollider").shape.b = split.get_node("Line2DLeft").get_point_position(1)
	split.get_node("StaticBody2D/RightCollider").shape.a = split.get_node("Line2DRight").get_point_position(0)
	split.get_node("StaticBody2D/RightCollider").shape.b = split.get_node("Line2DRight").get_point_position(1)
	
	for i in 3:
		split.get_node("Way")._prolong_road(0.0)
		split.get_node("Way2")._prolong_road(0.0)

	potential_paths.append_array([split.get_node("Way"), split.get_node("Way2")])
	await _wait_for_path_change()
	
var potential_paths = []
var to_remove = []
func _wait_for_path_change():
	var stop = false
	while !stop:
		var past_dist = (position - main_way.curve.get_point_position(current_index).rotated(main_way.rotation) - main_way.position).length()
		for i in potential_paths:
			var dist = (position - i.curve.get_point_position(current_index + 1).rotated(i.get_parent().rotation) - i.get_parent().position).length()
			if dist < past_dist:
				var new_way = way_scene.instantiate()
				var angle = i.get_parent().rotation
				new_way.position = i.get_parent().position
				new_way.curve = Curve2D.new()
				for j in i.curve.point_count:
					new_way.curve.add_point(i.curve.get_point_position(j).rotated(angle), i.curve.get_point_in(j).rotated(angle), i.curve.get_point_out(j).rotated(angle))
				new_way.width = i.width
				to_remove.append(main_way)
				to_remove.append(i.get_parent())
				i.queue_free()
				
				$"..".add_child(new_way)
				main_way = new_way
				
				potential_paths = []
				stop = true
				break
		await get_tree().process_frame

func _on_collide(body):
	if body.name == "StaticBody2D2":
		_gameend()

var score = 0
func _on_timer():
	past_points.append(position)
	$"../Line2D".add_point(position)
	if (past_points.size() > 20):
		past_points.remove_at(0)
		$"../Line2D".remove_point(0)
	$"../../CanvasLayer/Label".text = str(int(score))
	if is_game_over: return
	var dist_past = (past_points[past_points.size() - 1] - past_points[past_points.size() - 2]).length()
	score += dist_past / SPEED
	if (dist_past > SPEED / 9.0):
		$"../../CanvasLayer/Label".label_settings.font_color = Color.YELLOW
		score += 0.1
	else: $"../../CanvasLayer/Label".label_settings.font_color = Color.WHITE

var is_game_over = false
func _gameend():
	is_game_over = true
	$"../../CanvasLayer/Panel".visible = true
	
	var max_score = 0
	if (ResourceLoader.exists("user://savegame.tres")):
		max_score = load("user://savegame.tres").score
	if score > max_score:
		max_score = score
		var score_to_save:score_save = score_save.new()
		score_to_save.score = max_score
		ResourceSaver.save(score_to_save, "user://savegame.tres")
	$"../../CanvasLayer/Panel/Label3".text = str(int(max_score))

func _chaser_defeated():
	if is_game_over: return
	score += 10
	$"../../CanvasLayer/Label2".text = "+10"
	$"../../CanvasLayer/Label2/Timer".start(0.5)
	await $"../../CanvasLayer/Label2/Timer".timeout
	$"../../CanvasLayer/Label2".text = ""
