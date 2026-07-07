extends Node2D


var rd : RenderingDevice

var particle_data := PackedFloat32Array()
var particle_count :int= 0


var _delta : float

var params_buffer : RID
# Buffers and Uniform Sets
#var storage_buffer : RID
#var uniform_set : RID


func add_particle(pos: Vector2):
	particle_data.push_back(pos.x)      # pos.x
	particle_data.push_back(pos.y)      # pos.y
	particle_data.push_back(pos.x)      # last_pos.x (same as pos initially)
	particle_data.push_back(pos.y)      # last_pos.y
	particle_data.push_back(0.0)        # accel.x
	particle_data.push_back(0.0)        # accel.y
	particle_count += 1


func _ready() -> void:
	#setup_compute()
	add_particle(Vector2(69, 69))
	add_particle(Vector2(420, 420))
	add_particle(Vector2(111, 111))

func _physics_process(delta: float) -> void:
	_delta = delta

	#particle_buffer = create_particle_buffer()
	#print(particle_data)

#func setup_compute2()->void:
	#rd = RenderingServer.create_local_rendering_device()
	## Create shader and pipeline
	#var shader_file = load("res://verlet/compute_shader.glsl")
	#var shader_spirv = shader_file.get_spirv()
	#var shader = rd.shader_create_from_spirv(shader_spirv)
	#var pipeline = rd.compute_pipeline_create(shader)
	#
	## Data for compute shaders has to come as an array of bytes
	#var pba = PackedByteArray()
	#pba.resize(64)
	#for i in range(16):
		#pba.encode_float(i*4, 2.0)
	#
	## Create storage buffer
	## Data not needed, can just create with length
	#var storage_buffer = rd.storage_buffer_create(64, pba)
	#
	## Create uniform set using the storage buffer
	#var u = RDUniform.new()
	#u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#u.binding = 5
	#u.add_id(storage_buffer)
	#var uniform_set = rd.uniform_set_create([u], shader, 0)
	#
	## Start compute list to start recording our compute commands
	#var compute_list = rd.compute_list_begin()
	## Bind the pipeline, this tells the GPU what shader to use
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	## Binds the uniform set with the data we want to give our shader
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	## Dispatch 1x1x1 (XxYxZ) work groups
	#rd.compute_list_dispatch(compute_list, 2, 1, 1)
	##rd.compute_list_add_barrier(compute_list)
	## Tell the GPU we are done with this compute task
	#rd.compute_list_end()
	## Force the GPU to start our commands
	#rd.submit()
	## Force the CPU to wait for the GPU to finish with the recorded commands
	#rd.sync()
	#
	## Now we can grab our data from the storage buffer
	#var byte_data = rd.buffer_get_data(storage_buffer)
	#for i in range(27):
		#print(byte_data.decode_float(i*4))
	#
#func setup_compute3():
	#
	## We will be using our own RenderingDevice to handle the compute commands
	#var rd = RenderingServer.create_local_rendering_device()
	#
	## Create shader and pipeline
	#var shader_file = load("res://verlet/compute_shader.glsl")
	#var shader_spirv = shader_file.get_spirv()
	#var shader = rd.shader_create_from_spirv(shader_spirv)
	#var pipeline = rd.compute_pipeline_create(shader)
	#
	## Data for compute shaders has to come as an array of bytes
	#var pba = PackedByteArray()
	#pba.resize(64)
	#for i in range(16):
		#pba.encode_float(i*4, 2.0)
	#
	## Create storage buffer
	## Data not needed, can just create with length
	#var storage_buffer = rd.storage_buffer_create(64, pba)
	#
	## Create uniform set using the storage buffer
	#var u = RDUniform.new()
	#u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#u.binding = 0
	#u.add_id(storage_buffer)
	#var uniform_set = rd.uniform_set_create([u], shader, 0)
	#
	## Start compute list to start recording our compute commands
	#var compute_list = rd.compute_list_begin()
	## Bind the pipeline, this tells the GPU what shader to use
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	## Binds the uniform set with the data we want to give our shader
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	## Dispatch 1x1x1 (XxYxZ) work groups
	#rd.compute_list_dispatch(compute_list, 2, 1, 1)
	##rd.compute_list_add_barrier(compute_list)
	## Tell the GPU we are done with this compute task
	#rd.compute_list_end()
	## Force the GPU to start our commands
	#rd.submit()
	## Force the CPU to wait for the GPU to finish with the recorded commands
	#rd.sync()
	#
	## Now we can grab our data from the storage buffer
	#var byte_data = rd.buffer_get_data(storage_buffer)
	#for i in range(16):
		#print(byte_data.decode_float(i*4))
	#
#func setup_compute() -> void:
	## We will be using our own RenderingDevice to handle the compute commands
	#rd = RenderingServer.create_local_rendering_device()
#
	## Create shader and pipeline
	#var shader_file = load("res://verlet/compute_shader.glsl")
	#var shader_spirv = shader_file.get_spirv()
	#var shader = rd.shader_create_from_spirv(shader_spirv)
	#var pipeline = rd.compute_pipeline_create(shader)
#
	#var pba = PackedByteArray()
	#pba.resize(64)
	#for i in range(16):
		#pba.encode_float(i*4, 2.0)
	#
	#var pd_data = PackedVector2Array()
	#for i in range(4):
		#pd_data.append(Vector2(69.0, 69.0))
#
#
	#pd_data.clear()
	#pd_data = PackedVector2Array()
	#pd_data.append(Vector2(69.0, 69.0))
	#pd_data.append(Vector2(100.0, 200.0))
	#pd_data.append(Vector2(300.0, 400.0))
	#pd_data.append(Vector2(500.0, 600.0))
	#var pos_buffer = _generate_vec2_buffer(pd_data)
#
	## Add non-zero acceleration to see movement
	##accel_data
	#var accel_data = PackedVector2Array()
	#accel_data.clear()
	#accel_data.append(Vector2(-1.0, -1.0))
	#accel_data.append(Vector2(0.0, 2.0))
	#accel_data.append(Vector2(-1.0, -1.0))
	#accel_data.append(Vector2(5.0, 5.0))
	#var accel_buffer = _generate_vec2_buffer(accel_data)
#
	##accel_data.append(Vector2(1.0, 0.0))
	##accel_data.append(Vector2(0.0, 2.0))
	##accel_data.append(Vector2(-1.0, -1.0))
	##accel_data.append(Vector2(5.0, 5.0))
	#
	## Create storage buffer
	## Data not needed, can just create with length
	#var storage_buffer = rd.storage_buffer_create(64, pba)
	#
	## Create uniform set using the storage buffer
	#var u = RDUniform.new()
	#u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#u.binding = 0
	#u.add_id(storage_buffer)
	##var uniform_set = rd.uniform_set_create([u], shader, 0)
#
	##var pos_buffer = _generate_vec2_buffer([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	#var last_pos_data := PackedVector2Array()
	#for i in range(particle_count):
		#last_pos_data.append(Vector2(0, 0))  # Start same as initial position
#
	#var last_pos_buffer :=  rd.storage_buffer_create(
		#last_pos_data.size() * 8, last_pos_data.to_byte_array()
	#)
	#var delta := 1.0 / 60.0  # or use actual delta later
	#var delta_bytes := PackedFloat32Array([delta]).to_byte_array()
	#var delta_buffer := rd.storage_buffer_create(delta_bytes.size(), delta_bytes)
	##var accel_buffer = _generate_vec2_buffer([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	#var debug_before = rd.buffer_get_data(last_pos_buffer)
	#print("Before:", debug_before)
#
#
	## Create uniform set using the storage buffers
	##var color_uniform = _generate_uniforms(color_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	#var pos_uniform = _generate_uniforms(pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	#var accel_uniform = _generate_uniforms(accel_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	#var last_pos_uniform = _generate_uniforms(last_pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	#var delta_uniform = _generate_uniforms(delta_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	#var uniform_set = rd.uniform_set_create([u, pos_uniform, accel_uniform], shader, 0)
#
	## Start compute list to start recording our compute commands
	#var compute_list = rd.compute_list_begin()
	## Bind the pipeline, this tells the GPU what shader to use
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	## Binds the uniform set with the data we want to give our shader
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	## Dispatch 1x1x1 (XxYxZ) work groups
	##rd.compute_list_dispatch(compute_list, 2, 1, 1)
	#rd.compute_list_dispatch(compute_list, 1, 1, 1) # 1 group of 8 threads
#
	## Tell the GPU we are done with this compute task
	#rd.compute_list_end()
	## Force the GPU to start our commands
	#rd.submit()
	## Force the CPU to wait for the GPU to finish with the recorded commands
	#rd.sync()
#
	## Now we can grab our data from the storage buffers
	##var color_data = rd.buffer_get_data(color_buffer)
	#var pos_data = rd.buffer_get_data(last_pos_buffer)
	##var accel_data = rd.buffer_get_data(accel_buffer)
	#var debug_after = rd.buffer_get_data(last_pos_buffer)
	#print("After:", debug_after)
#
	## Print the data from the storage buffers
	##for i in range(8):
		###print("Color: ", color_data.decode_float(i * 4))
		##print("Position: ", pos_data.decode_float(i * 4))
		###print("Acceleration: ", accel_data.decode_float(i * 4))
#
	#for i in range(4):
		#var x = pos_data.decode_float(i * 8)
		#var y = pos_data.decode_float(i * 8 + 4)
		#print("Position [", i, "]: (", x, ", ", y, ")")
		##print(pos_data)
#
	##var byte_data = rd.buffer_get_data(storage_buffer)
	##for i in range(16):
		##print(byte_data.decode_float(i*4))
	#



func _generate_vec2_buffer2(data: Array) -> RID:
	var pba := PackedByteArray()
	for v in data:
		if typeof(v) == TYPE_VECTOR2:
			pba.encode_float(pba.size(), v.x)
			pba.encode_float(pba.size(), v.y)
		elif typeof(v) == TYPE_FLOAT:
			pba.encode_float(pba.size(), v)
	var buffer := rd.storage_buffer_create(pba.size(), pba)
	return buffer


func _generate_vec2_buffer(data) -> RID:
	var data_buffer_bytes := PackedVector2Array(data).to_byte_array()
	var data_buffer := rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer


func _generate_uniforms(data_buffer, type, binding):
	var data_uniform := RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform

func get_params_array(pos: Vector2):
	var params = []
	#for agent in agents:
	params.append(get_process_delta_time())
	#params.append(noise_scale)
	#params.append(iso_level)
	#params.append(float(num_voxels_per_axis))
	#params.append(chunk_scale)
	#params.append(pos.x +200)
	#params.append(pos.y)
	##params.append(agent.position.z)
	#params.append(noise_offset.x)
	#params.append(noise_offset.y)
		##params.append(noise_offset.z)
	return params

# Function to create a buffer for particle data
func create_particle_buffer() -> RID:
	# Convert particle data to byte array
	var particle_bytes := particle_data.to_byte_array()
	# Create a storage buffer for the particles
	var buffer := rd.storage_buffer_create(particle_bytes.size(), particle_bytes)
	return buffer
