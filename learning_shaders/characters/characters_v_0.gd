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
const SUBSTEPS = 4  # Reduced from 8 to 4
const BOUNDS_RADIUS = 300.0
const BOUNDS_CENTER = Vector2(356, 90)

@onready var multimesh2d: MultiMeshInstance2D = $MultiMeshInstance2D
@onready var icon: Sprite2D = $Camera2D/CanvasLayer/Icon

# FPS monitoring variables
const TARGET_FPS = 30
var current_fps = 60
var fps_counter = 0
var fps_timer = 0
var can_spawn = true
var particles_per_click = 10
var warmup_frames = 3
var max_particles = 20000

# Spatial hash optimization
const CELL_SIZE = 25.0  # Increased cell size slightly
var spatial_hash = {}
var checked_pairs = {}  # Made this a class variable to avoid recreation
var particles: Array = []
var packed_particle_data : PackedFloat32Array



## - compute - ##





var rd: RenderingDevice
var shader : RID
var pipeline : RID
var rendering_pipeline : RID


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
#var vel_damp : float = .9999 ## looks good !
var vel_damp : float = .991

const MAX_PARTICLES : int = 10000
const FLOATS_PER_PARTICLE : int = 12
@onready var matt :ShaderMaterial= $MultiMeshInstance2D.material#multimesh.mesh.material
var t := 0.0
var mouse_left_down: bool = false
var particle_pos_texture_height := 100#800.0#128.0
var particle_pos_image_rid : RID
var particle_pos_tex = Texture2DRD.new()

var particle_color_texture_height := 100#800.0#128.0
var particle_color_image_rid : RID
var particle_color_tex = Texture2DRD.new()

#@export var cam : Camera2D

#func _draw():
	#draw_circle(Vector2(500, -1000), 1000, Color.GRAY)
	#draw_grid(Vector2i(720*.1, 312*.1),cam.global_position/.5 )

var multimesh := MultiMesh.new()
var multimesh_instance := MultiMeshInstance2D.new()
var quad := QuadMesh.new()
@export var tex: Texture2D = preload("res://solid-circle-png-thumb162.png")
@onready var my_camera: Camera2D = $scene
@onready var multi_mesh_instance_2d: MultiMeshInstance2D = $MultiMeshInstance2D


func _ready():

	#init_compute()
	RenderingServer.call_on_render_thread(init_compute)
	setup_multimesh_instances()
	prev_delta_time.append(.008)

	#set_multi_mesh()
#
	var matt := ShaderMaterial.new()
	matt.shader = preload("res://characters/multimesh.gdshader")
	matt.set_shader_parameter("particles_data", particle_pos_tex)
	matt.set_shader_parameter("vertex_positions_tex", particle_pos_tex)
	matt.set_shader_parameter("texture_width", float(particle_pos_texture_height))
	matt.set_shader_parameter("texture_height", float(particle_pos_texture_height))
	matt.set_shader_parameter("vertex_texture_width", float(particle_pos_texture_height))
	matt.set_shader_parameter("viewport_size", Vector2(get_viewport().size.x / my_camera.zoom.x, get_viewport().size.y / my_camera.zoom.y))
	multi_mesh_instance_2d.material = matt

func setup_multimesh_instances():
	#var count = multimesh_instance.multimesh.visible_instance_count
	var count = multi_mesh_instance_2d.multimesh.instance_count
	var grid_size: int = ceil(sqrt(count))
	var spacing = 16
	
	
	for i in count:
		var x = i % grid_size
		var y = i / grid_size
		var pos = Vector2(x * spacing, y * spacing)
		var angle = 0.0
		pos = Vector2(0, 0)
		multi_mesh_instance_2d.multimesh.set_instance_transform_2d(i, Transform2D(angle, pos))


func set_multi_mesh():
	#add_child(multimesh_instance)
	multi_mesh_instance_2d.texture = tex
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	#multimesh.color_format = MultiMesh.COLOR_NONE
	#multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_NONE
	multi_mesh_instance_2d.multimesh = multimesh
	multi_mesh_instance_2d.multimesh.instance_count = MAX_PARTICLES
	multi_mesh_instance_2d.multimesh.visible_instance_count = MAX_PARTICLES
	quad.size = Vector2(1, 1)
	multi_mesh_instance_2d.multimesh.mesh = quad

var time_accum = 0.0
#func _process(delta):
func _physics_process(delta: float) -> void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) + " PARTICLES: " + str(particles.size())
	#Engine.time_scale = game_speed

	#t += delta
	#matt.set_shader_parameter("time", t)
	
	#spawn_particle2(delta)
	#run_compute(delta)
	spawn_particle()
	RenderingServer.call_on_render_thread(_update_boids_gpu.bind(delta))

	#queue_redraw()
	#update_multimesh_from_gpu_data()
	prev_delta_time.clear()
	prev_delta_time.append(delta)
	$part_pos_debug.material.set_shader_parameter("boid_data", particle_pos_tex)
	#var storage_debug = rendering_device.buffer_get_data(storage_buffer)
	#var parti = rendering_device.buffer_get_data(read_buffer)
	if is_debugging:
		#rendering_device.sync()
		pass

	time_accum += delta
	if time_accum >= 1.0:  # every 1 second
		#print("prev delta : ", prev_delta_time[0], " current_delta : ", delta)
		time_accum = 0.0
	
 

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
				#particles.append(create_verlet_obj(get_global_mouse_position()))
				#spawn_particle()
		if event.button_index == 1 and not event.is_pressed():
				mouse_left_down = false
		elif event.button_index == 1 and event.is_pressed():
				mouse_left_down = true



func spawn_particle():
	if !mouse_left_down:
		return
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


func init_compute():
	rd = RenderingServer.get_rendering_device()
	# Load compute shader
	var shader_file : RDShaderFile = load("res://characters/PBD3.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)


# Blend
	var blend = RDPipelineColorBlendState.new()
	blend.attachments.push_back(RDPipelineColorBlendStateAttachment.new())
	var render_shader_file = load("res://verlet/shaders/base_blue.gdshader")
	var render_shader_spirv = shader_file.get_spirv()
	var draw_shader = rd.shader_create_from_spirv(shader_spirv)
	#rendering_pipeline = rendering_device.render_pipeline_create(draw_shader)
	rendering_pipeline = rd.render_pipeline_create(
	shader,
	rd.screen_get_framebuffer_format(),
	0,
	RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
	RDPipelineRasterizationState.new(),
	RDPipelineMultisampleState.new(),
	RDPipelineDepthStencilState.new(), 
	blend, 
	0)
	
	#var pipeline = rd.render_pipeline_create(draw_shader, ...)


	# Create params buffer
	var pba2 = PackedByteArray()
	pba2.resize(2048) # Fills with zeroes
	params_buffer = rd.storage_buffer_create(2048, pba2)
	var params_uniform = init_uniform(params_buffer, 1,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	
	#var pba = PackedByteArray()
	#pba.resize(64)
	##for i in range(16):
		##pba.encode_float(i*4, 2.0)
	#storage_buffer = rendering_device.storage_buffer_create(64, pba)

	var storage_pba = PackedByteArray()
	storage_pba.resize(5120)
	storage_buffer = rd.storage_buffer_create(5120, storage_pba)
	var storage_uniform = init_uniform(storage_buffer, 0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)



	var pba3 = PackedByteArray()
	pba3.resize(128) # Fills with zeroes
	pos_buffer = rd.storage_buffer_create(128, pba3)

	var pos_uniform = init_uniform(pos_buffer, 2, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)


	var pba_part = PackedByteArray()
	pba_part.resize(MAX_PARTICLES * FLOATS_PER_PARTICLE * 4) # Fills with zeroes
	#pba_part.insert(0, 1)
	read_buffer = rd.storage_buffer_create(pba_part.size(), pba_part)
	var particles_uniform = init_uniform(read_buffer, 3, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)
	var pba_write_buffer = PackedByteArray()
	pba_write_buffer.resize(MAX_PARTICLES * FLOATS_PER_PARTICLE * 4)
	#pba_part.insert(0, 1)
	write_buffer = rd.storage_buffer_create(pba_write_buffer.size(), pba_write_buffer)
	var write_only_uniform = init_uniform(write_buffer, 4, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)


	pba_write_buffer.resize(MAX_PARTICLES * 2 * 4)
	collision_data_buffer = rd.storage_buffer_create(pba_write_buffer.size(), pba_write_buffer)
	var col_data_uniform = init_uniform(collision_data_buffer, 5, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	pba_write_buffer.resize(80000)
	counter_buffer = rd.storage_buffer_create(pba_write_buffer.size(), pba_write_buffer)
	var counter_buffer_uniform = init_uniform(collision_data_buffer, 6, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)


# - // image buffer 1
	var buf1 = create_image_buffer_only(rd, particle_pos_texture_height)
	particle_pos_image_rid = buf1["rid"]
	particle_pos_tex = buf1["texture"]
	var uni_ppos_outimage = _generate_uniform(particle_pos_image_rid, RenderingDevice.UNIFORM_TYPE_IMAGE, 7)
# - // image buffer 1
	var buf2 = create_image_buffer_only(rd, particle_color_texture_height)
	particle_color_image_rid = buf2["rid"]
	particle_color_tex = buf2["texture"]
	var uni_pcolor_outimage = _generate_uniform(particle_color_image_rid, RenderingDevice.UNIFORM_TYPE_IMAGE, 8)


	## Create buffer setter and pipeline
	var buffers = [storage_uniform, 
	params_uniform, 
	pos_uniform, 
	particles_uniform, 
	write_only_uniform, 
	col_data_uniform, 
	counter_buffer_uniform,
	uni_ppos_outimage, 
	uni_pcolor_outimage]
	buffer_set = rd.uniform_set_create(buffers, shader, 0)
	
#
	#var compute_list = rd.compute_list_begin()
	## Bind the pipeline, this tells the GPU what shader to use
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	## Binds the uniform set with the data we want to give our shader
	#rd.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	## Dispatch 1x1x1 (XxYxZ) work groups
	#rd.compute_list_dispatch(compute_list, 1024, 1, 1)
	##rd.compute_list_add_barrier(compute_list)
	## Tell the GPU we are done with this compute task
	#rd.compute_list_end()
	## Force the GPU to start our commands
	#rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	#rendering_device.sync()

#func run_compute(_delta):
	## Update params buffer
	#rd.barrier(RenderingDevice.BARRIER_MASK_COMPUTE)
	#var params_array = get_params_array(_delta)
	#var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	#rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
#
	## Prepare compute list
	#var compute_list = rd.compute_list_begin()
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	#rd.compute_list_dispatch(compute_list, 1024, 1, 1)
	#rd.compute_list_end()


#region compute shader boilerplate


func _update_boids_gpu(delta):
	var params_array = get_params_array( delta)
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)

	#var cam_params_array = get_cam_params_array()
	#var cam_params_bytes = PackedFloat32Array(cam_params_array).to_byte_array()
	#rd.buffer_update(camera_params_buffer, 0, cam_params_bytes.size(), cam_params_bytes)

	_run_compute_shader()

func _run_compute_shader():
	var cl = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, buffer_set, 0)
	# Compute dispatch size
	var local_size : int = 4
	var groups_x = int(ceil(float(particle_pos_texture_height) / local_size)) # → 25
	var groups_y = int(ceil(float(particle_pos_texture_height) / local_size)) # → 25

	#print(particle_pos_texture_height / local_size)
	rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
	#rd.compute_list_dispatch(cl, 20, 20, 1)
	rd.compute_list_end()

func create_image_buffer_only(rd: RenderingDevice, texture_height: int) -> Dictionary:
	var fmt := RDTextureFormat.new()
	fmt.width = texture_height
	fmt.height = texture_height
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT

	var view := RDTextureView.new()
	var texture_rid := rd.texture_create(fmt, view, [])

	var tex := Texture2DRD.new()
	tex.texture_rd_rid = texture_rid

	return {
		"rid": texture_rid,
		"texture": tex
	}


func _generate_uniform(data_buffer, type, binding):
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform

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
	params.append(get_global_mouse_position().x)
	params.append(get_global_mouse_position().y)
		#params.append(noise_offset.z)
	return params

#func _run_compute_shader(pipeline):
	#var compute_list := rendering_device.compute_list_begin()
	#rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	#rendering_device.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	#rendering_device.compute_list_dispatch(compute_list, 1024, 1, 1)
	#rendering_device.compute_list_end()
	#rendering_device.submit()
#endregion


func create_verlet_obj(pos: Vector2, radius := 2.0, color := Color.WHITE) -> Dictionary:
	return {
		"pos": pos,
		"last_pos": pos,
		"accel": Vector2.ZERO,
		#"radius": radius,
		#"radius": 16.0,
		"radius": randf_range(8, 16),
		"color": color,
	}


func update_multimesh_from_gpu_data():
	# Create objects once
	var byte_data = rd.buffer_get_data(read_buffer).to_float32_array()
	#var storage_byte_data = rendering_device.buffer_get_data(storage_buffer).to_float32_array()
	#var mm := multimesh2d.multimesh
	var mm := multi_mesh_instance_2d.multimesh
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




#region draw debug


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
	#print(storage_byte_data.slice(0, 500))
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
		draw_circle(pos, 4, p["color"])
#endregion
