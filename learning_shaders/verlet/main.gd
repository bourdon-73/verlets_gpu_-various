extends Node2D



const buffer_set_index : int = 0


const storage_bind_index : int = 0
const params_bind_index : int = 1
const pos_bind_index : int = 2
const particles_bind_index : int = 3


var rd: RenderingDevice
var shader : RID
var pipeline : RID


var buffer_set : RID
var params_buffer : RID
var storage_buffer : RID
var pos_buffer : RID
var particles_buffer : RID

var pos_data_bytes : PackedByteArray
var param_data_bytes : PackedByteArray

var _delta : float

const MAX_PARTICLES : int = 10000


#func _ready():
	#init_compute()
	#fetch_and_process_compute_data()
#
#
#func  _physics_process(delta):
	##_delta = delta
	##fetch_and_process_compute_data()
	#pass
#
#
#func init_compute():
	#rd= RenderingServer.create_local_rendering_device()
	## Load compute shader
	#var shader_file : RDShaderFile = load("res://verlet/compute_shader2.glsl")
	#var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	#shader = rd.shader_create_from_spirv(shader_spirv)
	#
	## Create params buffer
	#var pba2 = PackedByteArray()
	#pba2.resize(500) # Fills with zeroes
#
	##var buffer = rd.storage_buffer_create(size, pba2)
#
	#var params_array = get_params_array()
	#var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	##print(pba2)
	##rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	##var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	##params_buffer = rd.storage_buffer_create(4, PackedByteArray([0, 0, 0, 0]))
	#params_buffer = rd.storage_buffer_create(500, pba2)
	#var params_uniform = init_uniform(params_buffer, params_bind_index,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)
#
	#
	#var pba = PackedByteArray()
	#pba.resize(64)
	#for i in range(16):
		#pba.encode_float(i*4, 2.0)
	#storage_buffer = rd.storage_buffer_create(64, pba)
	#var storage_uniform = init_uniform(storage_buffer, storage_bind_index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)
#
#
#
	#var pba3 = PackedByteArray()
	#pba3.resize(100) # Fills with zeroes
	#pos_buffer = rd.storage_buffer_create(100, pba3)
#
	#var pos_uniform = init_uniform(pos_buffer, pos_bind_index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)
#
#
	#var pba_part = PackedByteArray()
	#pba_part.resize(100) # Fills with zeroes
	#particles_buffer = rd.storage_buffer_create(100, pba_part)
#
	#var particles_uniform = init_uniform(particles_buffer, particles_bind_index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)
	### Create buffer setter and pipeline
	#var buffers = [storage_uniform, params_uniform, pos_uniform, particles_uniform]
	#buffer_set = rd.uniform_set_create(buffers, shader, buffer_set_index)
	#pipeline = rd.compute_pipeline_create(shader)
#
	#var compute_list = rd.compute_list_begin()
	## Bind the pipeline, this tells the GPU what shader to use
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	## Binds the uniform set with the data we want to give our shader
	#rd.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	## Dispatch 1x1x1 (XxYxZ) work groups
	#rd.compute_list_dispatch(compute_list, 4, 1, 1)
	##rd.compute_list_add_barrier(compute_list)
	## Tell the GPU we are done with this compute task
	#rd.compute_list_end()
	## Force the GPU to start our commands
	#rd.submit()
	## Force the CPU to wait for the GPU to finish with the recorded commands
	#rd.sync()
#
##func run_compute(pos : Vector2):
	### Update params buffer
	##var params_array = get_params_array()
	##var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	###var pos_bytes = PackedFloat32Array(params_array).to_byte_array()
	###rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	### ...
	###var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	##rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	###rd.buffer_update(pos_buffer, 0, params_bytes.size(), params_bytes)
	### Reset counter
	###var counter = [0]
	###var counter_bytes = PackedFloat32Array(counter).to_byte_array()
	###rd.buffer_update(counter_buffer,0,counter_bytes.size(), counter_bytes)
###
	###var MATcounter = [0]
	###var MATcounter_bytes = PackedFloat32Array(MATcounter).to_byte_array()
	###rd.buffer_update(mat_counter_buffer,0,MATcounter_bytes.size(), MATcounter_bytes)
##
##
	### Prepare compute list
	##var compute_list = rd.compute_list_begin()
	##rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	##rd.compute_list_bind_uniform_set(compute_list, buffer_set, buffer_set_index)
	##rd.compute_list_dispatch(compute_list, 2, 1, 1)
	##rd.compute_list_end()
	##
	### Run
	##rd.submit()
	###last_compute_dispatch_frame = frame
	###waiting_for_compute = true
#
#func fetch_and_process_compute_data():
	#rd.sync()
	##waiting_for_compute = false
	## Get output
	#var byte_data = rd.buffer_get_data(storage_buffer)
	#for i in range(16):
		#print(byte_data.decode_float(i*4))
	##print(pos_data_bytes)
	##triangle_data_bytes = rd.buffer_get_data(triangle_buffer)
	##counter_data_bytes = rd.buffer_get_data(counter_buffer)
	##MATcounter_data_bytes = rd.buffer_get_data(mat_counter_buffer)
	##surface_data_bytes = rd.buffer_get_data(surface_buffer)#.to_float32_array()
	##thread = Thread.new()
	##thread.start(process_mesh_data)
	##waiting_for_meshthread = true
	##last_meshthread_start_frame = frame
#
	##print(pos_data_bytes)
#
#func init_uniform(buffer, binding, type)->RDUniform:
	#
	#var uniform = RDUniform.new()
	#uniform.uniform_type = type#RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform.binding = binding
	#uniform.add_id(buffer)
	#return uniform
#
#func get_params_array():
	#var params = []
	##for agent in agents:
	#params.append(_delta)
		##params.append(noise_offset.z)
	#return params
