extends Node2D
class_name LIMB

@export var p3: Marker2D 
@export var flip_middle: bool 
@export var parent_limb: LIMB 
@export_range(0, 360, 0.01, "degrees") var roll: float = 0.0

# Bone lengths
@export var bone1_length: float = 100.0
@export var bone2_length: float = 100.0
@export var bone_color: Color = Color.ALICE_BLUE

var parent_abs
var mid_point: Vector2  # This will be our p2
var mid_point_flipped: Vector2  # This will be our p2
var pos2: Vector2  
var p5: Vector2  

func _process(_delta: float) -> void:
	solve_ik()
	queue_redraw()
	roll_limb(roll)

func solve_ik() -> void:
	# Get the target position (p3) relative to the root (p1)
	var target_pos = p3.global_position
	var root_pos = global_position
	
	# Get the total distance to target
	var to_target = target_pos - root_pos
	var distance_to_target = to_target.length()
	
	# Get the maximum reach of our chain
	var max_reach = bone1_length + bone2_length
	
	# If target is too far, extend the bones towards it
	if distance_to_target > max_reach:
		var direction = to_target.normalized()
		mid_point = root_pos + direction * bone1_length
		mid_point_flipped = mid_point
	else:
		# Law of cosines to find the angle for the first bone
		var a = bone1_length
		var b = bone2_length
		var c = distance_to_target
		
		# Calculate angles using law of cosines
		var cos_alpha = (b * b - a * a - c * c) / (-2 * a * c)
		cos_alpha = clamp(cos_alpha, -1.0, 1.0)
		var alpha = acos(cos_alpha)
		
		# Calculate the base angle to the target
		var base_angle = to_target.angle()
		
		# Calculate the mid point
		var mid_dir = Vector2.from_angle(base_angle + alpha)
		mid_point = root_pos + mid_dir * bone1_length
		
		# Calculate flipped mid point if needed
		if flip_middle:
			var mid_dir_flipped = Vector2.from_angle(base_angle - alpha)
			mid_point_flipped = root_pos + mid_dir_flipped * bone1_length
			mid_point = mid_point_flipped

func roll_limb(roll_value):
	if flip_middle:

		var value = roll_value
		if value >= 0 and value <= 180:
			p5 = lerp(mid_point - global_position, pos2, value / 180.0)

		elif value >= 180 and value <= 360:
			p5 = lerp(pos2, mid_point - global_position, (value - 180) / 180.0)




func _draw() -> void:
	# Draw the bones
	draw_line(Vector2.ZERO, mid_point - global_position, bone_color, 2.0)
	draw_line(mid_point - global_position, p3.global_position - global_position, bone_color, 2.0)
	
	# Draw the points
	draw_circle(Vector2.ZERO, 8, Color.RED)  # Root
	draw_circle(mid_point - global_position, 4, Color.YELLOW)  # Mid point
	draw_circle(p3.global_position - global_position, 8, Color.BLUE)  # Target
	#if flip_middle:
		#draw_circle(p5 , 8, Color.LAVENDER_BLUSH)  # Target
	
	if flip_middle:
		var local_middle = mid_point - global_position
		if parent_limb:
			var mid = to_local(parent_limb.mid_point)
			var root = Vector2.ZERO
			pos2 = flip_point_along_line(local_middle, mid, root)
			draw_circle(pos2, 4, Color.PURPLE)

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

func get_mirrored_pos(end_child_pos: Vector2, root_pos: Vector2, mirror_dir: Vector2) -> Vector2:
	if mirror_dir.length_squared() < 0.0001:  # Check for near-zero length
		return end_child_pos
		
	var to_point = end_child_pos - root_pos
	var projection_length = mirror_dir.dot(to_point)
	var projection_point = root_pos + mirror_dir * projection_length
	var mirrored_pos = projection_point * 2 - end_child_pos
	return mirrored_pos
