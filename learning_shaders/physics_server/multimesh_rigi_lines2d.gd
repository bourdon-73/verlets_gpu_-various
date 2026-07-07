extends Node2D



"

4100 instances - 60 fps 

"

const NUM_LINES := 100
const SEGMENTS_PER_CURVE := 10
const TOTAL_INSTANCES := NUM_LINES * SEGMENTS_PER_CURVE
const LINES_PER_FRAME := 10

var multimesh := MultiMesh.new()
var mm_instance := MultiMeshInstance2D.new()
var _scale := 1.0
@export var is_rendering := true
var objects: Array = []
var bezier_segments: Array = []  # [start_idx, from, cp1, cp2, to]

var spawn_timer := 0.0
@export var spawn_delay := 0.25
@export var count := 100
var spawned := 0

@export var control_point_distance := 80.0
@export var line_width := 8.0
@export var line_segments := 20
@export var update_frequency := 0.1
var update_timer := 0.0

@export var gravity := Vector2(0, 980)
@export var visible_rect := Rect2(-500, -600, 1000, 1200)
var active_objects := []

func _ready():
	start_line_gen()

func start_line_gen():
	var line_mesh := QuadMesh.new()
	line_mesh.size = Vector2(1, 2)

	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = TOTAL_INSTANCES
	multimesh.mesh = line_mesh

	mm_instance.multimesh = multimesh
	add_child(mm_instance)

	start_generation()

func start_generation():
	await generate_lines_async()
	print("✅ All lines generated!")

func generate_lines_async():
	var instance_idx = 0
	for i in NUM_LINES:
		var a = Vector2(randf_range(-1400, 1800), randf_range(0, 1600))
		var b = Vector2(randf_range(0, 1800), randf_range(-110, 1600))
		var cp1 = a + Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		var cp2 = b + Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))

		bezier_segments.append([instance_idx, a, cp1, cp2, b])
		instance_idx = add_bezier_curve(a, cp1, cp2, b, instance_idx)

		if i % LINES_PER_FRAME == 0:
			await get_tree().process_frame

func add_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, start_idx: int) -> int:
	var last_point = p0
	for j in SEGMENTS_PER_CURVE:
		var t := float(j + 1) / SEGMENTS_PER_CURVE
		var point = cubic_bezier(p0, p1, p2, p3, t)
		var dir = point - last_point
		var length := dir.length()
		if length < 1.0:
			continue

		var angle := dir.angle()
		var center = (last_point + point) * 0.5
		var xform = Transform2D(angle, Vector2(length * _scale, 1.0), 0, center)

		multimesh.set_instance_transform_2d(start_idx, xform)
		var color = Color.from_hsv(float(start_idx) / TOTAL_INSTANCES, 0.8, 1.0)
		multimesh.set_instance_color(start_idx, color)

		start_idx += 1
		last_point = point

	return start_idx

func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return (
		u * u * u * p0 +
		3.0 * u * u * t * p1 +
		3.0 * u * t * t * p2 +
		t * t * t * p3
	)

func _physics_process(delta: float) -> void:
	process_lines(delta)
	for object in objects:
		var velocity = PhysicsServer2D.body_get_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		velocity += gravity * delta
		PhysicsServer2D.body_set_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
	get_window().title = " / FPS : " + str(Engine.get_frames_per_second()) + " : SPAWNED: " + str(spawned)

func process_lines(delta: float) -> void:
	if spawned < count:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_timer = 0.0
			var x = randf_range(-200, 400)
			var y = randf_range(-200, -500)
			create_rigid_object(Vector2(x, y))
			spawned += 1

	if is_rendering:
		update_timer += delta
		if update_timer >= update_frequency:
			update_timer = 0.0
			update_active_objects()
			update_dynamic_beziers()

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

	objects.append([body_rid, null])
	var velocity = Vector2(randf_range(-100, 100), randf_range(-50, 50))
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func update_active_objects() -> void:
	active_objects.clear()
	for i in range(min(objects.size(), count)):
		var pos = PhysicsServer2D.body_get_state(objects[i][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		if visible_rect.has_point(pos):
			active_objects.append(i)

func update_dynamic_beziers() -> void:
	var processed = 0
	var prev = -1

	for i in range(active_objects.size()):
		var curr = active_objects[i]
		if prev == -1:
			prev = curr
			continue
		if curr - prev > 3:
			prev = curr
			continue

		var p0 = PhysicsServer2D.body_get_state(objects[prev][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		var p3 = PhysicsServer2D.body_get_state(objects[curr][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin

		if p0.distance_to(p3) > 300:
			prev = curr
			continue

		var direction = (p3 - p0).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)
		var offset = sin(Time.get_ticks_msec() * 0.001 + curr * 0.5) * 30
		var cp1 = p0 + direction * control_point_distance + perpendicular * offset
		var cp2 = p3 - direction * control_point_distance + perpendicular * offset

		var start_idx = processed * SEGMENTS_PER_CURVE
		if start_idx >= TOTAL_INSTANCES:
			break
		add_bezier_curve(p0, cp1, cp2, p3, start_idx)

		processed += 1
