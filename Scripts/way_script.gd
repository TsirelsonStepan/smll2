extends Path2D

@onready var left_line = $Line2DLeft
@onready var right_line = $Line2DRight

var length = 300.0
var width = 100.0
var max_angle = 45.0 / 180.0 * PI
var min_angle = 15.0 / 180.0 * PI
var rotation_side = 0.5 # 0.0 = right, 1.0 = left

const N_TO_KEEP_BEFORE = 10
const N_TO_KEEP_AFTER = 10
var curve_k = 0.4

var current_point
var current_direction

func _ready():
	_initialize_path()
	var segment_length = curve.get_baked_length() / curve.point_count
	for i in curve.point_count:
		segments_length.append(segment_length)
	for i in curve.point_count:
		_build_borders(i)
		_build_border_colliders(i)
	current_point = curve.get_point_position(curve.point_count - 1)
	current_direction = (current_point - curve.get_point_position(curve.point_count - 2)).normalized()

var features = {}
func _initialize_path():
	features[0.5] = null
	features[0.9] = preload("res://Zones/acceleration_zone.tscn")
	features[1.0] = preload("res://Zones/chaser_spawn.tscn")

func _prolong_road(prob):
	var n = curve.point_count
	current_point += current_direction * length
	var new_direction = current_direction.rotated((min_angle + randf() * (max_angle - min_angle)) * sign((randf() - rotation_side) * 10.0))
	var new_point = current_point + new_direction * length
	var curve_line = (new_point - curve.get_point_position(curve.point_count - 1)).normalized()
	curve.add_point(current_point, -curve_line * (new_point - current_point).length() * curve_k, curve_line * (curve.get_point_position(curve.point_count - 1) - current_point).length() * curve_k)
	var total_length = 0.0
	for i in n: total_length += segments_length[i]
	segments_length.append(curve.get_baked_length() - total_length)
	current_direction = new_direction
	_build_borders(n)
	if (randf() < prob):
		_draw_red_line(n, left_line, false)
	if (randf() < prob):
		_draw_red_line(n, right_line, true)
	_build_border_colliders(n)
	_put_feature_on_path(n)

func _put_feature_on_path(n):
	var prob = randf()
	var feature
	var index = 0
	for i in features:
		if prob <= i:
			feature = features[i]
			break
		index += 1
	
	if feature != null:
		var new_feature = feature.instantiate()
		if randf() > 0.8 && index == 1: new_feature.is_random = true
		var total_length = 0.0
		for i in n: total_length += segments_length[i]
		var tran = curve.sample_baked_with_rotation(total_length + randf() * segments_length[n])
		var side_shift = Vector2(0, (sign((randf() - 0.5) * 10.0) * (width / 2.0))).rotated(tran.get_rotation())
		if get_parent() != $"/root/Main/Game": new_feature.position = (tran.get_origin() + side_shift).rotated(get_parent().rotation) + get_parent().position
		else: new_feature.position = (tran.get_origin() + side_shift).rotated(rotation) + position
		if index == 1: new_feature.path_direction = tran.get_rotation() + get_parent().rotation
		$"/root/Main/Game".add_child(new_feature)
		tree_exited.connect(new_feature._on_path_destroyed)

func _shorten_road():
	curve.remove_point(0)
	segments_length.remove_at(0)
	if left_line.get_point_position(0) in red_lines_points: red_lines_points[left_line.get_point_position(0)].queue_free()
	if right_line.get_point_position(0) in red_lines_points: red_lines_points[right_line.get_point_position(0)].queue_free()
	for i in n_of_points_per_segment:
		left_line.remove_point(0)
		right_line.remove_point(0)
		red_colliders[i * 2].queue_free()
		red_colliders[i * 2 + 1].queue_free()
	red_colliders = red_colliders.slice(n_of_points_per_segment * 2, red_colliders.size())

var segments_length = []
var n_of_points_per_segment = 10.0
func _build_borders(n):
	var total_length = 0.0
	for i in n: total_length += segments_length[i]
	for i in n_of_points_per_segment:
		var point = curve.sample_baked(total_length + i / n_of_points_per_segment * segments_length[n])
		var dir = get_angle_to(curve.sample_baked(total_length + (i + 1) / n_of_points_per_segment * segments_length[n]) - point + get_parent().position + position) + get_parent().rotation
		var left_point_to_add = point + Vector2(0, width).rotated(dir)
		var right_point_to_add = point + Vector2(0, -width).rotated(dir)
		left_line.add_point(left_point_to_add)
		right_line.add_point(right_point_to_add)

func _draw_red_line(n, line, is_right):
	var red_line = Line2D.new()
	red_line.default_color = Color.RED
	red_line.position = line.get_point_position(line.get_point_count() - n_of_points_per_segment)
	if n > 0: red_line.add_point(line.get_point_position(line.get_point_count() - n_of_points_per_segment - 1) - red_line.position)
	for i in n_of_points_per_segment:
		red_line.add_point(line.get_point_position(line.get_point_count() - n_of_points_per_segment + i) - red_line.position)
	line.add_child(red_line)
	red_lines_points[red_line.position] = red_line
	if is_right: is_right_wall = true
	else: is_left_wall = true

var is_left_wall = false
var is_right_wall = false
var red_lines_points = {}
var red_colliders = []
func _build_border_colliders(n):
	var m = 0
	if n == 0:
		m = 1
	for i in range(m, n_of_points_per_segment):
		var left_part = CollisionShape2D.new()
		var right_part = CollisionShape2D.new()
		left_part.shape = SegmentShape2D.new()
		right_part.shape = SegmentShape2D.new()
		left_part.shape.a = left_line.points[n * n_of_points_per_segment + i - 1]
		right_part.shape.a = right_line.points[n * n_of_points_per_segment + i - 1]
		left_part.shape.b = left_line.points[n * n_of_points_per_segment + i]
		right_part.shape.b = right_line.points[n * n_of_points_per_segment + i]
		if is_left_wall: $StaticBody2D2.add_child(left_part)
		else: $StaticBody2D.add_child(left_part)
		if is_right_wall: $StaticBody2D2.add_child(right_part)
		else: $StaticBody2D.add_child(right_part)
		red_colliders.append(left_part)
		red_colliders.append(right_part)
	is_left_wall = false
	is_right_wall = false
