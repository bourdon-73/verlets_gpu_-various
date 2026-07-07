extends Node2D

"""
	rootparent
		endParent
			root_child
				end_child
"""

"""
	pt your mission if you shall accept it
	draw a point from end_child mirrored of the normal of root_parent and end_parent
"""

@onready var root_parent: Marker2D = $root_parent
@onready var end_parent: Marker2D = $root_parent/end_parent
@onready var root_child: Marker2D = $root_parent/end_parent/root_child
@onready var end_child: Marker2D = $root_parent/end_parent/root_child/end_child

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Get global positions (absolute positions in the scene)
	var root_pos = root_parent.global_position
	var end_pos = end_parent.global_position
	var end_child_pos = end_child.global_position

	# Compute the direction of the mirror line and its normal
	var mirror_dir = (end_pos - root_pos).normalized()

	# Project end_child onto the mirror line and compute the mirrored position
	#var to_point = end_child_pos - root_pos
	#var projection_length = mirror_dir.dot(to_point)
	#var projection_point = root_pos + mirror_dir * projection_length
	#var mirrored_pos = projection_point - (end_child_pos - projection_point)
	var mirrored_pos = get_mirrored_pos(end_child_pos, root_pos, mirror_dir)

	# Draw the original and mirrored points
	draw_circle(end_child_pos, 5, Color.MAROON)  # Original point on end_child
	draw_circle(mirrored_pos, 5, Color.BLUE)  # Correctly mirrored point on opposite side
	#draw_line(root_pos, end_pos, Color.GREEN)  # Mirror line


func get_mirrored_pos(end_child_pos, root_pos, mirror_dir):
	var mirrored_pos
	var to_point = end_child_pos - root_pos ## ??? like an arrow calculating dist and direction
	var projection_length = mirror_dir.dot(to_point) ## ??? distance from mirror
	var projection_point = root_pos + mirror_dir * projection_length ## ???

	mirrored_pos = projection_point - (end_child_pos - projection_point)
	return mirrored_pos
