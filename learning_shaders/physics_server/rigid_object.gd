extends Node2D
class_name RigidObject

@onready var box_shape = RectangleShape2D.new()
@export var tex: Texture2D = preload("res://icon.svg")
@export var pos: Vector2 = Vector2.ZERO


var radius = 30

var img
var body_transforms: Array[Transform2D] = []  # Positions of the physics bodies
var body_rid

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if body_rid.is_valid():
		var trans = PhysicsServer2D.body_get_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		draw_circle(trans.origin, radius, Color(1, 0, 0, 0.5))  # RED circle, semi-transparent

#func _ready() -> void:
	#create_rigid_object(pos, get_world_2d())

func create_rigid_object(pos:Vector2, world2d) -> void:
	#for i in range(10):
		# Create the physics body 🥥
		body_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_RIGID)
		PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_BOUNCE, .5)

		# Create a collision shape for the body 🌐
		var shape = PhysicsServer2D.circle_shape_create()
		PhysicsServer2D.shape_set_data(shape, radius)
		PhysicsServer2D.body_add_shape(body_rid, shape)

		# Create and set transform 🗺
		#var pos = Vector2(50 + i * 40, 100)
		var trans = Transform2D(0, pos)
		
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, trans)
		PhysicsServer2D.body_set_space(body_rid, world2d.space)


# set rendering
		var rs = RenderingServer
		img = rs.canvas_item_create()
		rs.canvas_item_set_parent(img, get_canvas_item())
		rs.canvas_item_add_texture_rect(img, Rect2(-32, -32, 64, 64),tex)
		rs.canvas_item_set_transform(img, trans)

func _physics_process(delta: float) -> void:
	var trans = PhysicsServer2D.body_get_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
	RenderingServer.canvas_item_set_transform(img, trans)

func _exit_tree() -> void:
	PhysicsServer2D.free_rid(body_rid)
	RenderingServer.free_rid(img)
