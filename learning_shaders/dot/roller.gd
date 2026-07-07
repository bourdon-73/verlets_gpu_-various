extends Node2D
@export var dot_domain : Node2D
@export var p1 : Node2D
@export var t_vec : Vector2
@export_range(0, 360, 0.01, "degrees") var body_yaw: float = 0.0

func _process(delta: float) -> void:
	queue_redraw()
	pass

func _draw() -> void:
	var k_rot = p1.par.to_global(p1.keystart)
	var mid_point = p1.par.mid_point 
	var rotated_keystart = p1.keystart.rotated(mid_point.angle_to_point(p1.global_position)) 

	var k_global = (rotated_keystart + p1.position)

	var line_p1_global = (dot_domain.line_p1)
	var line_p2_global = (dot_domain.line_p2)

	#var proj_global = get_projection_point(t_vec, line_p1_global, line_p2_global)
	var proj_global = project_point_on_line(k_global, line_p1_global, line_p2_global)

	draw_circle(to_local(p1.to_global(rotated_keystart)), 8, Color.ALICE_BLUE)
	draw_circle(proj_global, 8, Color.PEACH_PUFF)
	print(proj_global)

	## flip across main line
	var correct_rotated_keystart = p1.to_global(rotated_keystart)
	#var flip_across_line = flip_point_along_line(correct_rotated_keystart,line_p1_global, line_p2_global)
	#draw_circle(flip_across_line, 8, Color.CHARTREUSE)

	## flip across the limb in direction of the main line
	var line_direction = (line_p2_global - line_p1_global).normalized() #* 50  # 50 is an arbitrary distance

	var flip_limb = flip_point_along_line(correct_rotated_keystart, p1.global_position, p1.global_position + line_direction)
	draw_circle(flip_limb, 8, Color.LIME)


func project_point_on_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> Vector2:
	var line_direction = (line_end - line_start).normalized()
	var point_vector = point - line_start
	var projection_length = point_vector.dot(line_direction)
	return line_start + (line_direction * projection_length)

func get_projection_point(point: Vector2, line_start: Vector2, line_end: Vector2) -> Vector2:
	var line_vec = line_end - line_start
	if line_vec.length_squared() < 0.0001:
		return line_start
	return line_start + line_vec * ((point - line_start).dot(line_vec) / line_vec.length_squared())

func flip_point_along_line(point1: Vector2, point_a: Vector2, point_c: Vector2) -> Vector2:
	var ac = point_c - point_a
	if ac.length_squared() < 0.0001:
		return point1
	
	var proj = point_a + ac * ((point1 - point_a).dot(ac) / ac.length_squared())
	var flipped_point = proj * 2 - point1
	return flipped_point
