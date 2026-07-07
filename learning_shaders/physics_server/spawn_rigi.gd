extends Node2D

"
gen record 
2700 - 60 fps - nothin changed
4800 - 60 fps - with rapier
"

@export var tex: Texture2D = preload("res://icon.svg")
@export var is_rendering := true  # Toggle rendering here

var objects: Array = []
# Lazy limb state
var lazy_index := 0
@export var limbs_per_frame := 100  # You can tweak this!

# Spawning setup
var spawn_timer := 0.0
@export var spawn_delay := 0.25
@export var count := 100
var spawned := 0

# Gravity parameters
@export var gravity := Vector2(0, 980)  # 9.8 m/s² downward

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

	var img = null
	if is_rendering:
		var rs = RenderingServer
		img = rs.canvas_item_create()
		rs.canvas_item_set_parent(img, get_canvas_item())
		rs.canvas_item_add_texture_rect(img, Rect2(16, -16, 32, 32), tex)
		rs.canvas_item_set_transform(img, trans)

	objects.append([body_rid, img])  # img might be null if rendering is disabled

func _physics_process(delta: float) -> void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) + "SPAWNED : " + str(spawned)
	
	_process_rigi(delta)
	if is_rendering:
		for object in objects:
			var trans = PhysicsServer2D.body_get_state(object[0], PhysicsServer2D.BODY_STATE_TRANSFORM)
			if object[1] != null:
				RenderingServer.canvas_item_set_transform(object[1], trans)

func _exit_tree() -> void:
	for object in objects:
		PhysicsServer2D.free_rid(object[0])
		if is_rendering and object[1] != null:
			RenderingServer.free_rid(object[1])
