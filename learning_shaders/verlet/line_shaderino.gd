extends Node2D

const NUM_LINES = 100
const SEGMENTS_PER_CURVE = 10
const TOTAL_INSTANCES = NUM_LINES * SEGMENTS_PER_CURVE

var multimesh := MultiMesh.new()
var mm_instance := MultiMeshInstance2D.new()
var _scale := 1.0
const LINES_PER_FRAME = 10


func _ready():
	#start_line_gen()
	pass

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
	await generate_lines_async()  # <- COROUTINE for real now!
	print("All lines generated!")


func generate_lines_async():
	var instance_idx = 0
	for i in NUM_LINES:
		var a = Vector2(randf_range(-1400, 1800), randf_range(0, 1600))
		var b = Vector2(randf_range(0, 1800), randf_range(-110, 1600))
		var cp1 = a + Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		var cp2 = b + Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		instance_idx = add_bezier_curve(a, cp1, cp2, b, instance_idx)
		#if i % 100 == 0:
			#await get_tree().process_frame  # Yield to avoid freezing
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
		#var xform := Transform2D(angle, Vector2(length, 1) * _scale, center)
		#var xform :Transform2D= Transform2D(angle, Vector2(1, 1) * _scale, 0, center )
		var xform :Transform2D = Transform2D(angle, Vector2(length, 1) * _scale,0,  center)
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
