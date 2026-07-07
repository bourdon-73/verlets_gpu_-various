extends Node2D



"
2800 instances - 60 fps 
"

@export var is_rendering := true  # Toggle rendering here
var objects: Array = []
var line_canvas_items: Array = []  # Store canvas items for lines
var bezier_points_cache: Array = []  # Cache for bezier curve points

# Spawning setup
var spawn_timer := 0.0
@export var spawn_delay := 0.25
@export var count := 100
var spawned := 0

# Bezier control points
@export var control_point_distance := 80.0  # Distance for control points
@export var line_width := 8.0
@export var line_segments := 20  # Number of segments per bezier curve
@export var update_frequency := 0.1  # How often to update bezier lines (seconds)
var update_timer := 0.0

# Gravity parameters
@export var gravity := Vector2(0, 980)  # 9.8 m/s² downward

# Pre-calculated factorial values for optimization
var factorials := [1, 1, 2, 6]  # 0!, 1!, 2!, 3!

# Object visibility culling
@export var visible_rect := Rect2(-500, -600, 1000, 1200)
var active_objects := []  # Objects currently visible and being rendered

func _ready():
	if is_rendering:
		# Pre-allocate bezier points cache
		for i in range(count-1):
			bezier_points_cache.append([])
			for j in range(line_segments + 1):
				bezier_points_cache[i].append(Vector2.ZERO)
			
		# Create canvas items for each potential line (count-1 lines)
		for i in range(count-1):
			var line_item = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(line_item, get_canvas_item())
			line_canvas_items.append(line_item)

func process_lines(delta: float) -> void:
	
	if spawned < count:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_timer = 0.0
			var x = randf_range(-200, 400)
			var y = randf_range(-200, -500)
			create_rigid_object(Vector2(x, y))
			spawned += 1
	
	# Update line drawing at reduced frequency
	if is_rendering:
		update_timer += delta
		if update_timer >= update_frequency:
			update_timer = 0.0
			update_active_objects()
			update_bezier_lines()

# Update which objects are visible and should be rendered
func update_active_objects() -> void:
	active_objects.clear()
	
	for i in range(min(objects.size(), count)):
		var pos = PhysicsServer2D.body_get_state(objects[i][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		#if visible_rect.has_point(pos):
		active_objects.append(i)

func update_bezier_lines() -> void:
	# Hide all line canvas items first
	for line_item in line_canvas_items:
		RenderingServer.canvas_item_clear(line_item)
	
	# Only process visible objects
	var processed_lines = 0
	var prev_visible_index = -1
	
	for i in range(active_objects.size()):
		var obj_index = active_objects[i]
		
		# Skip first object since we need pairs
		if prev_visible_index == -1:
			prev_visible_index = obj_index
			continue
			
		# Don't connect objects that are too far apart in the array
		if obj_index - prev_visible_index > 3:
			prev_visible_index = obj_index
			continue
			
		# Draw line between consecutive visible objects
		var start_pos = PhysicsServer2D.body_get_state(objects[prev_visible_index][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		var end_pos = PhysicsServer2D.body_get_state(objects[obj_index][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		
		# Don't draw if objects are too far apart
		var distance = start_pos.distance_to(end_pos)
		if distance > 300:
			prev_visible_index = obj_index
			continue
		
		# Calculate control points with less randomness
		var direction = (end_pos - start_pos).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)
		
		var perp_offset = sin(Time.get_ticks_msec() * 0.001 + obj_index * 0.5) * 30
		var cp1 = start_pos + direction * control_point_distance + perpendicular * perp_offset
		var cp2 = end_pos - direction * control_point_distance + perpendicular * perp_offset
		
		# Draw the cubic bezier using RenderingServer
		if processed_lines < line_canvas_items.size():
			draw_bezier_with_rs(
				line_canvas_items[processed_lines], 
				start_pos, cp1, cp2, end_pos,
				Color(0.5 + 0.5 * sin(obj_index * 0.3), 
					  0.5 + 0.5 * cos(obj_index * 0.4), 
					  0.5 + 0.5 * sin(obj_index * 0.5), 0.8),
				line_width,
				processed_lines
			)
			processed_lines += 1
		
		prev_visible_index = obj_index

func draw_bezier_with_rs(canvas_item, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color, width: float, cache_index: int):
	# Update bezier curve points in the cache
	update_bezier_points(p0, p1, p2, p3, cache_index)
	
	# Draw line segments using RenderingServer in batches
	var points = bezier_points_cache[cache_index]
	
	# Use a single primitive call instead of multiple lines when possible
	var vertices = PackedVector2Array()
	var colors = PackedColorArray()
	
	for i in range(line_segments):
		vertices.append(points[i])
		vertices.append(points[i+1])
		colors.append(color)
		colors.append(color)
	
	RenderingServer.canvas_item_add_polyline(
		canvas_item,
		vertices,
		colors,
		width
	)

# More efficient bezier calculation that updates the points cache
func update_bezier_points(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, cache_index: int) -> void:
	var points = bezier_points_cache[cache_index]
	
	# Pre-calculate coefficients for the bezier formula
	var coeff0 = p0
	var coeff1 = 3.0 * (p1 - p0)
	var coeff2 = 3.0 * (p2 - 2.0 * p1 + p0)
	var coeff3 = p3 - 3.0 * p2 + 3.0 * p1 - p0
	
	for i in range(line_segments + 1):
		var t = float(i) / line_segments
		var t_squared = t * t
		var t_cubed = t_squared * t
		
		# Horner's method for polynomial evaluation
		points[i] = coeff0 + t * (coeff1 + t * (coeff2 + t * coeff3))

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
	
	process_lines(delta)
	# Apply gravity and update physics
	for object in objects:
		var velocity = PhysicsServer2D.body_get_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		velocity += gravity * delta
		PhysicsServer2D.body_set_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
	get_window().title = " / FPS : " + str(Engine.get_frames_per_second()) + (" : ")+ " SPAWNED: " + str(spawned)

func _exit_tree() -> void:
	# Free physics bodies
	for object in objects:
		PhysicsServer2D.free_rid(object[0])
	
	# Free canvas items
	if is_rendering:
		for line_item in line_canvas_items:
			RenderingServer.free_rid(line_item)
