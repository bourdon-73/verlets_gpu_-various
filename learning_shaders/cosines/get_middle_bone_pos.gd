extends Node2D


@onready var p1: Marker2D = $p1
@onready var p3: Marker2D = $p1/p3


func _process(delta: float) -> void:
	queue_redraw()
	pass


# Given triangle information (example values)
var a = 100.0  # Distance from p1 to p2
var b = 120.0  # Distance from p1 to p3
var theta_deg = 60.0  # Angle at p1 in degrees

func _draw() -> void:
	draw_circle(p1.global_position, 8, Color.RED)
	draw_circle(p3.global_position, 8, Color.BLUE)
	
	var root_angle = p3.get_angle_to(p1.global_position)
	var end_angle = 0.0
	var root_lenght = 160.0

	var p2 = get_middle_bone_position(p1.global_position, p3.global_position, root_angle, end_angle, root_lenght)
	draw_circle(p2, 4, Color.YELLOW)

func get_middle_bone_position(root_pos: Vector2, end_pos: Vector2, root_angle: float, end_angle: float, root_length: float) -> Vector2:
	# Calculate midpoint between root and end positions
	#var midpoint_pos = root_pos.lerp(end_pos, 0.5)
	var midpoint_pos = lerp(root_pos, end_pos, .5)
	
	# Average the angles for a smooth middle bone rotation estimate
	var middle_angle = (root_angle + end_angle) / 2
	
	# Calculate the middle bone offset from the midpoint
	var middle_offset = Vector2(cos(middle_angle), sin(middle_angle)) * (root_length / 2)
	
	# Compute final position by applying the offset to the midpoint
	return midpoint_pos + middle_offset
