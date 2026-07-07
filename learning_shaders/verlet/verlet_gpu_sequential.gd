extends Node2D

"
gen record !
4003 - 60 fps
5400 - 257 fps - crashed 
6200 - 60 fps !!
3900 - 60 fps???? - visible multi mesh
4600 - invisible multimesh
7000 - correct multi meshing !!!
10 000 - without multimeshing !!!
25 000 - 3k fps no rendering !?!!
1k - 60 fps???????
"


@export_category("debugging")

@export var is_debugging : bool = true
@export var instance_idx : int = 0
@export var dbug_pos : bool = true
@export var dbug_last_pos : bool = true
@export var dbug_accel : bool = true

@export var pause = false :
	set(new_value):
		pause = new_value

@export_range(0.0, 1.0) var game_speed : float = .0

@export_category("rest")
@onready var viewport_size = get_viewport_rect().size
const GRAVITY = Vector2(0, 500)
const SUBSTEPS = 8  # Reduced from 8 to 4
const BOUNDS_RADIUS = 2000.0
const BOUNDS_CENTER = Vector2(0, -0)

@onready var multimesh2d: MultiMeshInstance2D = $MultiMeshInstance2D
@onready var icon: Sprite2D = $Camera2D/CanvasLayer/Icon

# FPS monitoring variables
var particles_per_click = 10

# Spatial hash optimization
const CELL_SIZE = 25.0  # Increased cell size slightly
var spatial_hash = {}
var checked_pairs = {}  # Made this a class variable to avoid recreation
var particles: Array = []
var packed_particle_data : PackedFloat32Array



## - compute - ##




const buffer_set_index : int = 0


const storage_bind_index : int = 0
const params_bind_index : int = 1
const pos_bind_index : int = 2
const read_bind_index : int = 3
const write_bind_index : int = 4


var rd: RenderingDevice
var shader : RID
var rendering_pipeline : RID
var uniform_set : RID

var sforces_compute : RID
var sforces_pipeline : RID


var sconstraints_compute : RID
var sconstraints_pipeline : RID

var buffer_set : RID
var params_buffer : RID
var storage_buffer : RID
var pos_buffer : RID
var read_buffer : RID
var write_buffer : RID
var collision_data_buffer : RID
var counter_buffer : RID

var pos_data_bytes : PackedByteArray
var param_data_bytes : PackedByteArray

var prev_delta_time : Array
var vel_damp : float = .999

const MAX_PARTICLES : int = 10000
const FLOATS_PER_PARTICLE : int = 12
@onready var matt :ShaderMaterial= $MultiMeshInstance2D.material#multimesh.mesh.material
var t := 0.0
var mouse_left_down: bool = false

#@export var cam : Camera2D

#func _draw():
	#draw_circle(Vector2(500, -1000), 1000, Color.GRAY)
	#draw_grid(Vector2i(720*.1, 312*.1),cam.global_position/.5 )

var multimesh := MultiMesh.new()
var multimesh_instance := MultiMeshInstance2D.new()
var quad := QuadMesh.new()
@export var tex: Texture2D = preload("res://solid-circle-png-thumb162.png")


func _ready():

	#init_computes()
	RenderingServer.call_on_render_thread(init_computes)
	
	prev_delta_time.append(.008)

	set_multi_mesh()
	#update_multimesh()
	#print($MultiMeshInstance2D.multimesh.)
	#if multimesh2d and multimesh2d.multimesh.instance_count < particles.size():


	#mini_mesh()
	#var trans = Transform2D(0, Vector2(0, 0))
	#mesh_inst.multimesh.set_instance_transform(0, trans)
	#update_multimesh()
	#fetch_and_process_compute_data()

func init_computes():
	rd = RenderingServer.create_local_rendering_device()

## diff pipelines / aka compute shaders
	var shader_file := load("res://verlet/compute/solve_forces.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	sforces_compute = rd.shader_create_from_spirv(shader_spirv)
	sforces_pipeline = rd.compute_pipeline_create(sforces_compute)

	shader_file = load("res://verlet/compute/solve_constraints.glsl")
	shader_spirv = shader_file.get_spirv()
	sconstraints_compute = rd.shader_create_from_spirv(shader_spirv)
	sconstraints_pipeline = rd.compute_pipeline_create(sconstraints_compute)


## SHARED DATA 
	var pba2 = PackedByteArray()
	pba2.resize(4) # Fills with zeroes
	storage_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var storage_uniform = _generate_uniform(storage_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
		
	pba2.resize(8*4) # Fills with zeroes
	params_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
		
	pba2.resize(128) # Fills with zeroes
	pos_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var pos_uniform = _generate_uniform(pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	pba2.resize(MAX_PARTICLES * 12 * 4) # Fills with zeroes
	read_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var read_uniform = _generate_uniform(read_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)

	pba2.resize(MAX_PARTICLES * 12 * 4) # Fills with zeroes
	write_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var write_uniform = _generate_uniform(write_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)

	pba2.resize(MAX_PARTICLES * 12 * 4) # Fills with zeroes
	collision_data_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var col_uniform = _generate_uniform(collision_data_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)

	pba2.resize(80000) # Fills with zeroes
	counter_buffer = rd.storage_buffer_create(pba2.size(), pba2)
	var counter_uniform = _generate_uniform(counter_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 6)

	var bindings = [ 
				storage_uniform,
				params_uniform,
				pos_uniform,
				read_uniform,
				write_uniform,
				col_uniform,
				counter_uniform]
	
	uniform_set = rd.uniform_set_create(bindings, sforces_compute, 0)
	#uniform_set = rd.uniform_set_create(bindings, sconstraints_compute, 0)

	
	#pipeline = rd.compute_pipeline_create(sforces_compute)
#
	#var compute_list = rd.compute_list_begin()
	## Bind the pipeline, this tells the GPU what shader to use
	#rd.compute_list_bind_compute_pipeline(compute_list, sforces_pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	#rd.compute_list_dispatch(compute_list, 512, 1, 1)
	#rd.compute_list_end()
	#rd.submit()
	#rd.sync()



func set_multi_mesh():
	#add_child(multimesh_instance)
	multimesh2d.texture = tex
	#multimesh2d.transform_format = MultiMesh.TRANSFORM_2D
	#multimesh.color_format = MultiMesh.COLOR_NONE
	#multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_NONE
	#multimesh2d.multimesh = multimesh
	multimesh2d.multimesh.instance_count = MAX_PARTICLES
	multimesh2d.multimesh.visible_instance_count = MAX_PARTICLES
	quad.size = Vector2(1, 1)
	#multimesh2d.multimesh.mesh = quad

var time_accum = 0.0
#func _process(delta):
func _physics_process(delta: float) -> void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) + " PARTICLES: " + str(particles.size())
	
	spawn_particle2(delta)
	#run_compute(delta)
	#RenderingServer.call_on_render_thread(run_compute.bind(delta))
	_update_physics_gpu(delta)

	#var dat = rd.buffer_get_data(read_buffer).to_float32_array()
	
	#queue_redraw()
	update_multimesh_from_gpu_data()
	prev_delta_time.clear()
	prev_delta_time.append(delta)

	#print(dat.slice(0, 12))
	time_accum += delta
	if time_accum >= 1.0:  # every 1 second
		#print("prev delta : ", prev_delta_time[0], " current_delta : ", delta)
		
		time_accum = 0.0
	





 


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.is_pressed():
				#particles.append(create_verlet_obj(get_global_mouse_position()))
				#spawn_particle()
				mouse_left_down = true
		elif event.button_index == 1 and not event.is_pressed():
				mouse_left_down = false



func spawn_particle():
	#if !mouse_left_down:
		#return
	var start_idx = particles.size()
	particles.append(create_verlet_obj(get_global_mouse_position()))

		# 🟡 NOW update the GPU buffer for just the new particles
	var new_particle_data = PackedFloat32Array()
	for i in range(start_idx, particles.size()):
		var p = particles[i]
		new_particle_data.push_back(p["pos"].x)
		new_particle_data.push_back(p["pos"].y)
		new_particle_data.push_back(p["last_pos"].x)
		new_particle_data.push_back(p["last_pos"].y)

		new_particle_data.push_back(p["accel"].x)
		new_particle_data.push_back(p["accel"].y)
		new_particle_data.push_back(p["radius"])
		new_particle_data.push_back(0.0)

		new_particle_data.push_back(p["color"].r)
		new_particle_data.push_back(p["color"].g)
		new_particle_data.push_back(p["color"].b)
		new_particle_data.push_back(p["color"].a)


	var byte_data := PackedByteArray()
	byte_data.resize(new_particle_data.size() * 4) # 4 bytes per float

	# Convert float data to raw bytes
	for i in range(new_particle_data.size()):
		byte_data.encode_float(i * 4, new_particle_data[i])

	#(byte_data.to_float32_array())
	# Now update the buffer
	rd.buffer_update(
		read_buffer,
		start_idx * FLOATS_PER_PARTICLE * 4, # offset in bytes
		byte_data.size(),                    # size in bytes
		byte_data
	)
	if multimesh2d and multimesh2d.multimesh.instance_count < particles.size():
		multimesh2d.multimesh.instance_count = particles.size()
		multimesh2d.multimesh.visible_instance_count = particles.size()
		


func spawn_particle2(delta):
	if !mouse_left_down:
		return
	
	var start_idx = particles.size()
	
	# Add multiple particles per click
	for i in range(particles_per_click):
		# Create particle with slight variation in position for natural spread
		var offset = Vector2(
			randf_range(-10.0, 10.0),
			randf_range(-10.0, 10.0)
		)
		particles.append(create_verlet_obj(get_global_mouse_position() + offset))
	
	# 🟡 NOW update the GPU buffer for just the new particles
	var new_particle_data = PackedFloat32Array()
	
	for i in range(start_idx, particles.size()):
		var p = particles[i]
		new_particle_data.push_back(p["pos"].x)
		new_particle_data.push_back(p["pos"].y)
		new_particle_data.push_back(p["last_pos"].x)
		new_particle_data.push_back(p["last_pos"].y)
		new_particle_data.push_back(p["accel"].x)
		new_particle_data.push_back(p["accel"].y)
		new_particle_data.push_back(p["radius"])
		new_particle_data.push_back(0.0)
		new_particle_data.push_back(p["color"].r)
		new_particle_data.push_back(p["color"].g)
		new_particle_data.push_back(p["color"].b)
		new_particle_data.push_back(p["color"].a)
	
	# Convert to byte array for buffer update
	var byte_data := PackedByteArray()
	byte_data.resize(new_particle_data.size() * 4) # 4 bytes per float
	
	# Convert float data to raw bytes
	for i in range(new_particle_data.size()):
		byte_data.encode_float(i * 4, new_particle_data[i])
	
	# Update only the portion of the buffer containing new particles
	rd.buffer_update(
		read_buffer,
		start_idx * FLOATS_PER_PARTICLE * 4, # offset in bytes
		byte_data.size(),                    # size in bytes
		byte_data
	)
	
	# Update particle count parameter in params buffer
	var params_data = PackedFloat32Array([delta, float(particles.size())])
	var params_byte_data := PackedByteArray()
	params_byte_data.resize(params_data.size() * 4)
	for i in range(params_data.size()):
		params_byte_data.encode_float(i * 4, params_data[i])
	
	rd.buffer_update(
		params_buffer,
		0,
		params_byte_data.size(),
		params_byte_data
	)
		# Only update instance count when necessary
	#if multimesh2d and multimesh2d.multimesh.instance_count < particles.size():
		#multimesh2d.multimesh.instance_count = particles.size()
		#multimesh2d.multimesh.visible_instance_count = particles.size()


func _update_physics_gpu(delta):
	# Calculate substep delta time
	var substep_dt = delta / SUBSTEPS
	
	for i in range(SUBSTEPS):
		# Update parameters with current substep time
		var params_array = get_params_array(delta)
		var params_bytes = PackedFloat32Array(params_array).to_byte_array()
		rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
		
		# Run your sequential pipeline with smaller timestep
		_run_compute_shader(sforces_pipeline)
		_run_compute_shader(sconstraints_pipeline)


func run_compute(_delta):
	# Update params buffer
	#rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)
	var params_array = get_params_array(_delta)
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)



	# Prepare compute list
	#var compute_list = rd.compute_list_begin()
	#rd.compute_list_bind_compute_pipeline(compute_list, sforces_pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set , 0)
	#rd.compute_list_dispatch(compute_list, 512, 1, 1)
	#rd.compute_list_end()
#
	#rd.compute_list_bind_compute_pipeline(compute_list, sconstraints_pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set , 0)
	#rd.compute_list_dispatch(compute_list, 512, 1, 1)
	#rd.compute_list_end()

	#for i in range(SUBSTEPS):
	_run_compute_shader(sforces_pipeline)
	_run_compute_shader(sconstraints_pipeline)




#func _update_boids_gpu(delta, mouse):
	#var params_buffer_bytes = _generate_parameter_buffer(delta,mouse)
	#rd.buffer_update(params_buffer, 0, params_buffer_bytes.size(), params_buffer_bytes)
	#
	##_run_compute_shader(bin_sum_pipeline)
	##_run_compute_shader(bin_prefix_sum_pipeline)

func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 512, 1, 1)
	rd.compute_list_end()



func fetch_and_process_compute_data():
	#waiting_for_compute = false
	# Get output
	var byte_data = rd.buffer_get_data(read_buffer)
	#for i in range(16):
	#for i in range(0, 26):

	#(particles.size())
	
	if !particles.size() >= 1:
		return
	#(byte_data.to_float32_array())
	for i in range(16): ## get the size bitch 
		#(byte_data.decode_float(i*4))
		#byte_data.decode_float(i*12)
		#(byte_data[i])
		pass

func pull_acceleration_from_gpu():
	var byte_data = rd.buffer_get_data(read_buffer).to_float32_array()
	#for i in range(particles.size()):
	for i in range(particles.size()):
		#(byte_data.decode_float(i*4))
		var index = i * 12  # Assuming your particle has 10 floats: pos(2), last_pos(2), accel(2), radius(1), pad(1), color(4) = 12, but aligned, maybe padded to 16
		var accel_x = byte_data[index + 4] - 1
		var accel_y = byte_data[index + 5] - 1
		var accel = Vector2(accel_x, accel_y)
		
		var pos_x = byte_data[index + 0]
		var pos_y = byte_data[index + 1]
		var pos = Vector2(pos_x, pos_y)
#
		var last_pos_x = byte_data[index + 2]
		var last_pos_y = byte_data[index + 3]
		var last_pos = Vector2(last_pos_x, last_pos_y)
		var det = byte_data[index + 6]
#
		##var accel_x = byte_data[index + 4]
		##var accel_y = byte_data[index + 5]
#
		var temp = Vector2(pos_x, pos_y)#p["pos"]
		#(det)
		particles[i]["pos"] = pos
		particles[i]["last_pos"] = last_pos
		particles[i]["accel"] = accel
		#particles[i]["accel"] = Vector2.ZERO
		#(det)
		var debug_floats = rd.buffer_get_data(storage_buffer).to_float32_array()
		#("DEBUG pos.y[0] = ", debug_floats[0])


		pass
	#(byte_data)
	#(byte_data[0 + 4])
	#(byte_data[0 + 5])


func init_uniform(buffer, binding, type)->RDUniform:
	
	var uniform = RDUniform.new()
	uniform.uniform_type = type#RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform

func get_params_array(_delta:float):
	var params = []
	#for agent in agents:
	params.append(_delta)
	params.append(prev_delta_time[0])
	params.append(vel_damp)
	params.append(particles.size())
	params.append(BOUNDS_RADIUS)
	params.append(BOUNDS_CENTER.x)
	params.append(BOUNDS_CENTER.y)
	params.append(pause)
		#params.append(noise_offset.z)
	return params



func create_verlet_obj(pos: Vector2, radius := 2.0, color := Color.WHITE) -> Dictionary:
	return {
		"pos": pos,
		"last_pos": pos,
		"accel": Vector2.ZERO,
		#"radius": radius,
		#"radius": 16.0,
		"radius": randf_range(48, 64),
		"color": color,
	}


func update_multimesh_from_gpu_data():
	# Create objects once
	var byte_data = rd.buffer_get_data(read_buffer).to_float32_array()
	#var storage_byte_data = rd.buffer_get_data(storage_buffer).to_float32_array()
	#var mm := multimesh2d.multimesh
	var mm := multimesh2d.multimesh
	var tmp_trans := Transform2D()
	var tmp_color := Color()
	var index : int

	for i in range(MAX_PARTICLES):
		index = i * FLOATS_PER_PARTICLE
		
		tmp_trans = Transform2D(0, Vector2(1, 1)*(byte_data[index + 6]*1), 0, Vector2(byte_data[index + 0], byte_data[index + 1]))
		mm.set_instance_transform_2d(i, tmp_trans)

		#var c1 = byte_data[index + 8]
		#var c2 = byte_data[index + 9]
		#var c3 = byte_data[index + 10]
		#var c4 = byte_data[index + 11]
		#var color = Vector4(c1, c2, c3, c4)
		#mm.set_instance_color(i, Color(c1, c2, c3, c4))

func update_multimesh_from_gpu_data2():
	# Fetch the updated particle data from the GPU buffer
	var byte_data = rd.buffer_get_data(read_buffer).to_float32_array()
	#var storage_byte_data = rd.buffer_get_data(storage_buffer).to_float32_array()
	var mm := multimesh2d.multimesh
	#(byte_data[0])
	#(byte_data[1])
	#(byte_data[2])
	
	#(byte_data.slice(0, 12))
	for i in range(12):
		#(byte_data[i])
		pass
	for i in range(particles.size()):
		var index = i * FLOATS_PER_PARTICLE
		var p = particles[i]
		var pos_x = byte_data[index + 0]
		var pos_y = byte_data[index + 1]
		var radius = byte_data[index + 6]
		var pos = Vector2(pos_x, pos_y)


		var c1 = byte_data[index + 8]
		var c2 = byte_data[index + 9]
		var c3 = byte_data[index + 10]
		var c4 = byte_data[index + 11]
		var color = Vector4(c1, c2, c3, c4)
		# Apply the new position to the MultiMesh instance
		#var trans = Transform2D(0.0, pos)
		#var scal =  (Vector2(16, 16)) 
		#mm.mesh.size = scal
		var trans : Transform2D = Transform2D(0, Vector2(1, 1)*(radius*1), 0, pos)
		mm.set_instance_transform_2d(i, trans)
		mm.set_instance_color(i, Color(c1, c2, c3, c4))


func update_multimesh():
	var mm := multimesh2d.multimesh
	var count = particles.size()
	
	for i in count:
		var p = particles[i]
		# Remove the scale Vector2(10, 10)
		mm.set_instance_transform_2d(i, Transform2D(0, Vector2(1, 1), 0, p["pos"]))
		#mm.set_instance_transform_2d(i, Transform2D(0, Vector2(p["radius"], p["radius"]), 0, p["pos"]))
		mm.set_instance_color(i, p["color"])

func update_multimesh2():
	var amount_x = 150
	var amount_y = 150
	var spacing = 32
	var total = amount_x * amount_y

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count = total
	multimesh2d.multimesh = mm

	var mesh : Mesh = QuadMesh.new()
	mesh.size = Vector2(16, 16)
	mm.mesh = mesh


	for x in range(amount_x):
		for y in range(amount_y):
			var index = y * amount_x + x
			var pos = Vector2(x * spacing, y * spacing)
			var angle = 0.0  # You can randomize this for rotation flair
			var xform = Transform2D(angle, pos)
			mm.set_instance_transform_2d(index, xform)


func draw_grid(resolution: Vector2i, origin: Vector2 = Vector2.ZERO, cell_size: Vector2 = Vector2(32, 32), color: Color = Color(1, 1, 1, 0.2)) -> void:
	var width = resolution.x * cell_size.x
	var height = resolution.y * cell_size.y

	# Vertical lines
	for x in range(resolution.x + 1):
		var start = origin + Vector2(x * cell_size.x, 0)
		var end = start + Vector2(0, height)
		draw_line(start, end, color)

	# Horizontal lines
	for y in range(resolution.y + 1):
		var start = origin + Vector2(0, y * cell_size.y)
		var end = start + Vector2(width, 0)
		draw_line(start, end, color)

func _draw():
	#draw_circle(Vector2.ZERO, 16, Color.PALE_VIOLET_RED)
	draw_circle(BOUNDS_CENTER , BOUNDS_RADIUS, Color.DARK_GRAY)
	#for cell in spatial_hash.keys():
		#var top_left = cell * CELL_SIZE
		#draw_rect(Rect2(top_left, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.2, 0.8, 1.0, 0.2), false, 1.0)
	##draw_debugging()
	#draw_particles()

func draw_debugging():

	if !is_debugging:
		return
	if !particles.size() > instance_idx:
		return


	rd.sync()
	var particle : Dictionary = particles[instance_idx]
	var dbug_radius : float = 4

	var byte_data = rd.buffer_get_data(read_buffer).to_float32_array()
#for i in range(particles.size()):
	#print(byte_data.decode_float(i*4))
	var index = instance_idx * 12  # Assuming your particle has 10 floats: pos(2), last_pos(2), accel(2), radius(1), pad(1), color(4) = 12, but aligned, maybe padded to 16
	var accel_x = byte_data[index + 4] - 1
	var accel_y = byte_data[index + 5] - 1
	var accel = Vector2(accel_x, accel_y)
	
	var pos_x = byte_data[index + 0]
	var pos_y = byte_data[index + 1]
	var pos = Vector2(pos_x, pos_y)
#
	var last_pos_x = byte_data[index + 2]
	var last_pos_y = byte_data[index + 3]
	var last_pos = Vector2(last_pos_x, last_pos_y)
	var det = byte_data[index + 6]
#
	##var accel_x = byte_data[index + 4]
	##var accel_y = byte_data[index + 5]
#
	var temp = Vector2(pos_x, pos_y)#p["pos"]
	#print(det)
	#particles[i]["pos"] = pos
	#particles[i]["last_pos"] = last_pos
	#particles[i]["accel"] = accel
	#particles[i]["accel"] = Vector2.ZERO

	if dbug_pos:
		draw_circle(pos,dbug_radius, Color.GREEN )
	if dbug_last_pos:
		draw_circle(last_pos,dbug_radius, Color.YELLOW )
	if dbug_accel:
		#print(accel)
		draw_circle(accel,dbug_radius, Color.PURPLE)
	#print("p : ", pos, "l : ", last_pos )
	pass
	
func draw_particles():

	var byte_data = rd.buffer_get_data(read_buffer).to_float32_array()
	var storage_byte_data = rd.buffer_get_data(storage_buffer).to_float32_array()
	var mm := multimesh2d.multimesh
	#(byte_data[0])
	#(byte_data[1])
	#(byte_data[2])
	
	#(byte_data.slice(0, 12))
	for i in range(12):
		#(byte_data[i])
		pass
	for i in range(particles.size()):
		var index = i * FLOATS_PER_PARTICLE
		var p = particles[i]
		var pos_x = byte_data[index + 0]
		var pos_y = byte_data[index + 1]
		var radius = byte_data[index + 6]
		var pos = Vector2(pos_x, pos_y)

		# Apply the new position to the MultiMesh instance
		#var trans = Transform2D(0, Vector2(p["radius"], p["radius"]), 0, p["pos"])
		var trans = Transform2D(0.0, pos)
		#var trans = Transform2D(0, Vector2(radius, radius)*2, 0, pos-Vector2(316, radius*radius))
		var scal =  (Vector2(16, 16)) 
		#var trans = Transform2D(
		#Vector2(radius, 0),     # x basis (scaled by radius)
		#Vector2(0, radius),     # y basis (scaled by radius)
		#pos                     # position
		#)
		#var trans = Transform2D(0,scal, 0, pos-Vector2(32, 32))
		#var trans = Transform2D()
		#multimesh2d.multimesh.set_instance_transform_2d(i, trans)
		draw_circle(pos, radius, p["color"])


func _generate_uniform(data_buffer, type, binding):
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform
