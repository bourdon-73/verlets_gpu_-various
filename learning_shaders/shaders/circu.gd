@tool
extends Node2D

# Exported variables to modify the polygon dynamically
@export var polygon : Polygon2D
@export var num_verts : int = 32
@export var wobble_amount : float = 10.0
@export var radius : float = 100.0  # Now we can adjust the radius during runtime

var wobble_seed : int = 0

func _ready():
	generate_circle()  # Initialize the circle when the scene is ready
	wobble_edges()     # Apply wobble to the edges initially

# This function generates the circle points based on the current radius
func generate_circle():
	var points = PackedVector2Array()
	for i in range(num_verts):
		var angle = 2 * PI * i / num_verts
		points.append(Vector2(radius * cos(angle), radius * sin(angle)))
	polygon.polygon = points

# This function applies the wobble effect to the polygon's points
func wobble_edges():
	var points = polygon.polygon
	var wobble_points = PackedVector2Array()
	randomize()
	wobble_seed = randi()
	for i in range(points.size()):
		var angle = 2 * PI * i / points.size()
		var wobble_x = points[i].x + (randf_range(-wobble_amount, wobble_amount) * cos(angle + wobble_seed))
		var wobble_y = points[i].y + (randf_range(-wobble_amount, wobble_amount) * sin(angle + wobble_seed))
		wobble_points.append(Vector2(wobble_x, wobble_y))
	polygon.polygon = wobble_points

# This function updates the points based on the radius and number of vertices
func update_points():
	var points = PackedVector2Array()
	for i in range(num_verts):
		var angle = 2 * PI * i / num_verts
		points.append(Vector2(radius * cos(angle), radius * sin(angle)))  # Use current radius
	polygon.polygon = points  # Update the polygon's points

func _process(delta):
	#update_points()
	pass
