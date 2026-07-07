extends Node2D

@onready var p1: Marker2D = $p1
@onready var p3: Marker2D = $p1/p3

# Given triangle information
@export var root_distance: float = 100.0  # Distance from p1 to p2
@export var theta_deg: float = 80.0  # Angle at p1 in degrees

func _process(_delta: float) -> void:
	# Update the angle based on p3's position
	var dir_to_p3 = p3.global_position - p1.global_position
	var base_angle = dir_to_p3.angle()
	
	# Update root_distance based on p3's distance if needed
	var distance_to_p3 = dir_to_p3.length()
	
	# Ensure root_distance doesn't exceed the distance to p3
	root_distance = min(root_distance, distance_to_p3)
	
	# Update theta_deg based on the current triangle formation
	theta_deg = rad_to_deg(acos(root_distance / distance_to_p3))
	
	queue_redraw()

func _draw() -> void:
	# Draw p1 (root point)
	draw_circle(p1.global_position, 8, Color.RED)
	
	# Draw p3 (target point)
	draw_circle(p3.global_position, 8, Color.BLUE)
	
	# Calculate base angle to p3
	var dir_to_p3 = p3.global_position - p1.global_position
	var base_angle = dir_to_p3.angle()
	
	# Calculate p2 position
	var p2_angle = base_angle - deg_to_rad(theta_deg)
	var p2 = p1.global_position + Vector2(cos(p2_angle), sin(p2_angle)) * root_distance
	
	# Draw p2 (intermediate point)
	draw_circle(p2, 4, Color.YELLOW)
	
	# Draw lines to show the triangle
	draw_line(p1.global_position, p2, Color.WHITE, 2.0)
	draw_line(p2, p3.global_position, Color.WHITE, 2.0)
	draw_line(p3.global_position, p1.global_position, Color.WHITE, 2.0)
