extends Node2D



@export var path : Path2D
@export var p1 : LIMB
@export var p2 : Marker2D
@export var p3 : Marker2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_visuals()
	pass


func update_visuals():
	

	#path.curve.set_point_position(0,skelly.get_bone(0).global_position - parent_limb.global_position)
	path.curve.set_point_position(0,p1.global_position)
	

	path.curve.set_point_out(0, (p2.global_position))
	#path.curve.set_point_in(1, (p1.mid_point))

	path.curve.set_point_position(1,p3.global_position)

	#line.points = path.curve.get_baked_points()
	#points = path.curve.get_baked_points()
	#end_sprite.global_position = line.get_point_position(line.points.size()-1)
