extends Node2D

const NUM_LINES = 1
const SEGMENTS_PER_CURVE = 25
const TOTAL_INSTANCES = NUM_LINES * SEGMENTS_PER_CURVE

var multimesh := MultiMesh.new()
var mm_instance := MultiMeshInstance2D.new()
var _scale := 5.0
const LINES_PER_FRAME = 1

var line_start_point := Vector2.ZERO
var first_line_end_point := Vector2.ZERO

# NEW: Cache transforms manually
var cached_transforms: Array = []

# Control how many instances to update per frame
var update_batch_size := 20
var update_offset := 0

func _ready():
	start_line_gen()
	line_start_point = Vector2(400, 300)  # Set an initial position
	first_line_end_point = line_start_point + Vector2(100, 0)


func _physics_process(delta: float) -> void:
	#move_line()
	pass

func move_line():
	var mouse_pos = get_global_mouse_position()
	first_line_end_point = mouse_pos
	
	if cached_transforms.size() == 0:
		return
	
	# Handle first line specially
	var dir = first_line_end_point - line_start_point
	var length = dir.length()
	var angle = dir.angle()
	var center = (line_start_point + first_line_end_point) * 0.5
	
	var xform = Transform2D(angle, Vector2(length, 1) * _scale, 0, center)
	cached_transforms[0] = xform
	multimesh.set_instance_transform_2d(0, xform)
	multimesh.set_instance_color(0, Color.GREEN)  # First line is green
	
	# Move a batch of lines each frame to spread work over frames
	for _i in range(update_batch_size):
		var i = 1 + (update_offset + _i) % (TOTAL_INSTANCES - 1)
		if i >= cached_transforms.size():
			break
		
		var current_xform = cached_transforms[i]
		var current_pos = current_xform.origin
		
		var offset = (mouse_pos - current_pos).normalized() * 10.0
		var new_pos = current_pos + offset * randf_range(0.1, 0.5)
		
		var new_xform = Transform2D(
			current_xform.x,
			current_xform.y,
			new_pos
		)
		
		cached_transforms[i] = new_xform
		multimesh.set_instance_transform_2d(i, new_xform)
	
	# Advance offset so next frame moves different lines
	update_offset = (update_offset + update_batch_size) % (TOTAL_INSTANCES - 1)


func start_line_gen():
	var line_mesh = QuadMesh.new()
	line_mesh.size = Vector2(1, 2)
	
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = TOTAL_INSTANCES
	
	mm_instance.multimesh = multimesh
	mm_instance.multimesh.mesh = line_mesh
	call_deferred("add_child", mm_instance)

	start_generation()

func start_generation():
	await generate_lines_async()
	print("All lines generated!")

func generate_lines_async():
	var instance_idx = 0
	for i in NUM_LINES:
		var a = Vector2(randf_range(-1400, 1800), randf_range(-1400, 1800))
		var b = Vector2(randf_range(-1400, 1800), randf_range(-1400, 1800))
		var cp1 = a + Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		var cp2 = b + Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		instance_idx = add_bezier_curve(a, cp1, cp2, b, instance_idx)
		
		if i % LINES_PER_FRAME == 0:
			await get_tree().process_frame

func add_bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, start_idx: int) -> int:
	var last_point = p0
	for j in SEGMENTS_PER_CURVE:
		var t = float(j + 1) / SEGMENTS_PER_CURVE
		var point = cubic_bezier(p0, p1, p2, p3, t)
		var dir = point - last_point
		var length = dir.length()
		if length < 1.0:
			continue  # Skip tiny segments
		var angle = dir.angle()
		var center = (last_point + point) * 0.5
		
		var xform = Transform2D(angle, Vector2(length, 1) * _scale, 0, center)
		
		# Cache transform
		if cached_transforms.size() <= start_idx:
			cached_transforms.resize(start_idx + 1)
		
		cached_transforms[start_idx] = xform
		
		multimesh.set_instance_transform_2d(start_idx, xform)
		multimesh.set_instance_color(start_idx, Color.RED)
		
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

func _input(event: InputEvent) -> void:
	pass
