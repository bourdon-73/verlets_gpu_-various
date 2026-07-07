extends Node2D


@export_range(0, 360, 0.01, "degrees") var body_orientation: float = 0.0

var line_p1 : Vector2
var line_p2 : Vector2

func _process(delta: float) -> void:
	queue_redraw()

func _draw():
	# Convert the angle from degrees to radians
	var dist : float = 100

	var angle_rad = deg_to_rad(body_orientation)
	
	# Length of the line is 20, so we will draw two points at a distance of 20
	var start_x = cos(angle_rad) * -dist # Point at -20
	var start_y = sin(angle_rad) * -dist
	
	var end_x = cos(angle_rad) * dist  # Point at 20
	var end_y = sin(angle_rad) * dist
	var height_extra : float = 0
	start_y += height_extra
	end_y += height_extra
	line_p1 = Vector2(start_x, start_y)
	line_p2 = Vector2(end_x, end_y)
	# Draw the line centered at (0, 0)
	draw_line(line_p1, line_p2, Color(1, 0, 0), 2)  # Red line with width 2




#
