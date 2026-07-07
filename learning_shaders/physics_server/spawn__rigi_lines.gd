extends Node2D

@export var is_rendering := true  # Toggle rendering here
var objects: Array = []
var line_canvas_items: Array = []  # Store canvas items for lines

# Spawning setup
var spawn_timer := 0.0
@export var spawn_delay := 0.25
@export var count := 100
var spawned := 0

# Bezier control points
@export var control_point_distance := 80.0  # Distance for control points
@export var line_width := 2.0
@export var line_segments := 20  # Number of segments per bezier curve

# Gravity parameters
@export var gravity := Vector2(0, 980)  # 9.8 m/s² downward

func _ready():
	if is_rendering:
		# Create canvas items for each potential line (count-1 lines)
		for i in range(count-1):
			var line_item = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(line_item, get_canvas_item())
			line_canvas_items.append(line_item)

func _process_stuff(delta: float) -> void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) + " SPAWNED: " + str(spawned)
	
	if spawned < count:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_timer = 0.0
			var x = randf_range(-200, 400)
			var y = randf_range(-200, -500)
			create_rigid_object(Vector2(x, y))
			spawned += 1
	
	# Update line drawing
	if is_rendering:
		update_bezier_lines()

func update_bezier_lines():
	# Clear all line canvas items
	for line_item in line_canvas_items:
		RenderingServer.canvas_item_clear(line_item)
	
	# Draw lines between physics objects
	for i in range(min(objects.size() - 1, line_canvas_items.size())):
		var start_pos = PhysicsServer2D.body_get_state(objects[i][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		var end_pos = PhysicsServer2D.body_get_state(objects[i+1][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		
		# Calculate control points
		var direction = (end_pos - start_pos).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)  # Perpendicular vector
		
		var cp1 = start_pos + direction * control_point_distance + perpendicular * randf_range(-40, 40)
		var cp2 = end_pos - direction * control_point_distance + perpendicular * randf_range(-40, 40)
		
		# Draw the cubic bezier using RenderingServer
		draw_bezier_with_rs(line_canvas_items[i], start_pos, cp1, cp2, end_pos, 
						 Color(randf(), randf(), randf(), 0.8), line_width)

func draw_bezier_with_rs(canvas_item, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color, width: float):
	# Calculate points along the bezier curve
	var points = []
	for i in range(line_segments + 1):
		var t = float(i) / line_segments
		points.append(cubic_bezier_point(p0, p1, p2, p3, t))
	
	# Draw line segments using RenderingServer
	for i in range(line_segments):
		RenderingServer.canvas_item_add_line(
			canvas_item,
			points[i],
			points[i+1],
			color,
			width
		)

func cubic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return (
		u * u * u * p0 +
		3.0 * u * u * t * p1 +
		3.0 * u * t * t * p2 +
		t * t * t * p3
	)


func create_rigid_object(pos: Vector2) -> void:
	var radius = 10
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
	
	# Store physics body
	objects.append([body_rid, null])
	
	# Add random velocity when creating
	var velocity = Vector2(randf_range(-100, 100), randf_range(-50, 50))
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func _physics_process(delta: float) -> void:
	_process_stuff(delta)
	# Apply gravity and update physics
	for object in objects:
		var velocity = PhysicsServer2D.body_get_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		velocity += gravity * delta
		PhysicsServer2D.body_set_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func _exit_tree() -> void:
	# Free physics bodies
	for object in objects:
		PhysicsServer2D.free_rid(object[0])
	
	# Free canvas items
	if is_rendering:
		for line_item in line_canvas_items:
			RenderingServer.free_rid(line_item)
