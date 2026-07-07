extends Node2D

"

5000 60FPS !!
"

@export var tex: Texture2D = preload("res://icon.svg")
@export var is_rendering := true
@export var limbs_per_frame := 100
@export var spawn_delay := 0.25
@export var count := 100
@export var gravity := Vector2(0, 980)

var objects: Array = []  # Each entry: [body_rid, multimesh_index]
var spawn_timer := 0.0
var spawned := 0

var multimesh := MultiMesh.new()
var multimesh_instance := MultiMeshInstance2D.new()
var quad := QuadMesh.new()

func _ready():
	if is_rendering:
		add_child(multimesh_instance)
		multimesh_instance.texture = tex
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		#multimesh.color_format = MultiMesh.COLOR_NONE
		#multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_NONE
		multimesh.instance_count = count
		multimesh_instance.multimesh = multimesh
		quad.size = Vector2(16, 16)
		multimesh_instance.multimesh.mesh = quad

func _process_rigi(delta: float) -> void:
	if spawned >= count:
		return
	spawn_timer += delta
	if spawn_timer >= spawn_delay:
		spawn_timer = 0.0
		var x = randf_range(-200, 400)
		var y = randf_range(-200, -500)
		create_rigid_object(Vector2(x, y))
		spawned += 1

func create_rigid_object(pos: Vector2) -> void:
	var radius = 32
	var body_rid = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_RIGID)

	var shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(shape, radius)
	PhysicsServer2D.body_add_shape(body_rid, shape)

	var trans = Transform2D(0, pos)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, trans)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_CAN_SLEEP, true)
	PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_BOUNCE, true)
	PhysicsServer2D.body_set_space(body_rid, get_world_2d().space)

	var index = spawned
	objects.append([body_rid, index])

func _physics_process(delta: float) -> void:
	get_window().title = "FPS: " + str(Engine.get_frames_per_second()) + " | SPAWNED: " + str(spawned)
	_process_rigi(delta)

	if is_rendering:
		for object in objects:
			var trans: Transform2D = PhysicsServer2D.body_get_state(object[0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			multimesh.set_instance_transform_2d(object[1], trans)
			#if object[1] == 0:
				#print(object[1])
				#var tt: Transform2D = Transform2D(0, Vector2(10, 10), 0, get_global_mouse_position())
				#multimesh.set_instance_transform_2d(object[1], tt)


func _exit_tree() -> void:
	for object in objects:
		PhysicsServer2D.free_rid(object[0])
