extends Node2D
@export var tex: Texture2D = preload("res://icon.svg")
var objects: Array = []
# Lazy limb state
var lazy_index := 0
@export var limbs_per_frame := 100  # You can tweak this!
# Spawning setup
var spawn_timer := 0.0
@export var spawn_delay := 0.05
@export var count := 3000
var spawned := 0
# Gravity parameters
@export var gravity := Vector2(0, 980)  # 9.8 m/s² downward

func _process(delta: float) -> void:
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
	var radius = 30
	var body_rid = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_KINEMATIC)
	var shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(shape, radius)
	PhysicsServer2D.body_add_shape(body_rid, shape)
	var trans = Transform2D(0, pos)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, trans)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_CAN_SLEEP, true)
	PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_BOUNCE, true)
	PhysicsServer2D.body_set_space(body_rid, get_world_2d().space)
	var rs = RenderingServer
	var img = rs.canvas_item_create()
	rs.canvas_item_set_parent(img, get_canvas_item())
	rs.canvas_item_add_texture_rect(img, Rect2(-32, -32, 64, 64), tex)
	rs.canvas_item_set_transform(img, trans)
	# Add velocity to the object data structure
	objects.append([body_rid, img, Vector2.ZERO])  # The third element stores velocity

func _physics_process(delta: float) -> void:
	for object in objects:
		var body_rid = object[0]
		var canvas_item = object[1]
		var velocity = object[2]  # Get current velocity
		
		# Apply gravity to velocity
		velocity += gravity * delta
		object[2] = velocity  # Store updated velocity
		
		# Get current transform
		var trans = PhysicsServer2D.body_get_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM)
		
		# Apply velocity to position
		trans.origin += velocity * delta
		
		# Simple ground collision check
		if trans.origin.y > 600:  # Assuming ground is at y=600
			trans.origin.y = 600
			# Bounce with some energy loss
			velocity.y = -velocity.y * 0.7
			object[2] = velocity
		
		# Update physics body position
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, trans)
		
		# Update visual representation
		RenderingServer.canvas_item_set_transform(canvas_item, trans)

func _exit_tree() -> void:
	for object in objects:
		PhysicsServer2D.free_rid(object[0])
		RenderingServer.free_rid(object[1])
