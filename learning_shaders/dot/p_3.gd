extends Marker2D


@export var keystart : Vector2
@export var dot_domain : Node2D
@export var t_vec : Vector2
@export var par : Node2D




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#queue_redraw()
	pass




func _drawssssss() -> void:
	var k_rot = par.to_global(keystart)

	# Get the flipped position
	var flipped_self_pos : Vector2 = flip_point_along_line(k_rot, dot_domain.line_p1, dot_domain.line_p2)

	var k_global = to_global(keystart.rotated(par.mid_point.angle_to_point(global_position)))

	# Get global positions for the line
	var line_p1_global = dot_domain.to_global(dot_domain.line_p1)
	var line_p2_global = dot_domain.to_global(dot_domain.line_p2)
	print(dot_domain.line_p2)

	# Flip in global space
	var flipped_global = flip_point_along_line(k_global, line_p1_global, line_p2_global)

	# Project the point in global space
	var proj_global = get_projection_point(k_global, line_p1_global, line_p2_global)

	# Convert back to local space for drawing
	var flipped_local = to_local(flipped_global)
	var proj_local = to_local(proj_global)

	# Draw circles
	draw_circle(keystart.rotated(par.mid_point.angle_to_point(position)), 8, Color.RED)  # Kept the original RED point
	#draw_circle(k_global, 8, Color.RED)  # Kept the original RED point
	draw_circle(flipped_local, 8, Color.PURPLE)
	draw_circle(proj_local, 8, Color.ORANGE)  # ORANGE is now correctly centered



func get_projection_point(point: Vector2, line_start: Vector2, line_end: Vector2) -> Vector2:
	# Vector from line start to end
	var line_vec = line_end - line_start
	if line_vec.length_squared() < 0.0001:
		return line_start
		
	# Calculate projection
	return line_start + line_vec * ((point - line_start).dot(line_vec) / line_vec.length_squared())


func flip_point_along_line(point1: Vector2, point_a: Vector2, point_c: Vector2) -> Vector2:
	# Vector from A to C
	var ac = point_c - point_a
	if ac.length_squared() < 0.0001:  # Check for near-zero length
		return point1
		
	# Project point1 onto the line AC
	var proj = point_a + ac * ((point1 - point_a).dot(ac) / ac.length_squared())
	# Reflect point1 across the line
	var flipped_point = proj * 2 - point1
	return flipped_point
