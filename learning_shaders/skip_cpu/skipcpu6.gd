extends Node2D


const PARTICLE_COUNT := 100
const TEX_WIDTH := 800 # Make sure it's >= PARTICLE_COUNT * 2 / height
@onready var multimesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D
@export var my_camera : Camera2D

var rd: RenderingDevice
var output_texture_rid: RID
var shader: RID
var pipeline: RID
var uniform_set: RID

var params_buffer : RID
var storage_buffer : RID
var camera_params_buffer : RID

var texture_width = 800
var texture_height = 800

var data: PackedByteArray#: PackedByteArray = rd.texture_get_data(output_texture_rid, 0)
var img #= Image.create_from_data(texture_width, texture_height, false, Image.FORMAT_RGBA8, data)
var tex #= ImageTexture.create_from_image(img)

func _ready():


	#print(get_viewport().size.y)
	var count = multimesh_instance.multimesh.instance_count
	var grid_size : int = ceil(sqrt(count)) # Number of items per row/column
	var spacing = 16

	for  i : int in count:
		var x = i % grid_size
		var y = i / grid_size
		var pos = Vector2(x * spacing, y * spacing)
		var angle = 0.0 # Change if you want rotation
		multimesh_instance.multimesh.set_instance_transform_2d(i, Transform2D(angle, pos))


	rd = RenderingServer.create_local_rendering_device()
	
	# Create the output texture.
	var tformat = RDTextureFormat.new()
	tformat.width = texture_width
	tformat.height = texture_height
	tformat.depth = 1
	tformat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	#tformat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT

	#tformat.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	tformat.usage_bits = (
	RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |    # Compute shader writes
	RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |   # Shader reads
	RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | # Can copy data from
	RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	#tformat.mipmaps = 1
	#tformat.filter = false
	#tformat.mipmaps = false
	var tview = RDTextureView.new()
	output_texture_rid = rd.texture_create(tformat, tview, [])
	
	# Load and create the compute shader that fills the texture with neon pink.
	var shader_file = load("res://skip_cpu/image_compute1.glsl")
	var spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	# Bind the output texture to the shader (set 0, binding 0).
	var uni_outimage = RDUniform.new()
	uni_outimage.binding = 0
	uni_outimage.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uni_outimage.add_id(output_texture_rid)


	var pba2 = PackedByteArray()
	pba2.resize(2048) # Fills with zeroes
	params_buffer = rd.storage_buffer_create(2048, pba2)
	var params_uniform = init_uniform(params_buffer, 1,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	var storage_pba = PackedByteArray()
	storage_pba.resize(4) # one byte == 4 == 1 float
	storage_buffer = rd.storage_buffer_create(4, storage_pba)
	var storage_uniform = init_uniform(storage_buffer, 2, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)


	pba2 = PackedByteArray()
	pba2.resize(100) # Fills with zeroes
	camera_params_buffer = rd.storage_buffer_create(100, pba2)
	var camera_params_uniform = init_uniform(camera_params_buffer, 3,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)



	uniform_set = rd.uniform_set_create([uni_outimage, params_uniform, storage_uniform, camera_params_uniform], shader, 0)
	
	# Dispatch the compute shader.
	var cl = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	
	# Define a workgroup size that matches the shader (16x16) and compute group counts.
	var local_size = 16
	var groups_x = int(ceil(texture_width / float(local_size)))
	var groups_y = int(ceil(texture_height / float(local_size)))
	rd.compute_list_dispatch(cl, 16, 16, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()  # Wait for GPU to finish
	data = rd.texture_get_data(output_texture_rid, 0)
	img = Image.create_from_data(texture_width, texture_height, false, Image.FORMAT_RGBA8, data)
	tex = ImageTexture.create_from_image(img)


# On init only:
	tex = Texture2DRD.new()
	tex.texture_rd_rid = output_texture_rid
	#matt.set_shader_parameter("particles_data", tex)


	#rd = RenderingServer.get_rd()
	#var fmt := RDTextureFormat.new()
	#fmt.width = 128
	#fmt.height = 128
	#fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	#fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
#
	#var view := RDTextureView.new()
#
	#output_texture_rid = rd.texture_create(fmt, view) # ← GPU texture (RID)
	#tex = Texture2DRD.new()        # ← Godot resource wrapper
	#tex.texture_rd_rid = output_texture_rid # Link them

	#queue_redraw()

	#sprint(data)

	# Step 3: Assign the shader material
	var matt := ShaderMaterial.new()
	matt.shader = preload("res://skip_cpu/verletshader.gdshader")
	matt.set_shader_parameter("particles_data", tex)
	matt.set_shader_parameter("viewport_size", Vector2(get_viewport().size.x/my_camera.zoom.x, get_viewport().size.y/my_camera.zoom.y))
	matt.set_shader_parameter("texture_width", float(TEX_WIDTH))
	matt.set_shader_parameter("particles_count", float(PARTICLE_COUNT))

	multimesh_instance.material = matt


var frame : int = 1
#func _process(_delta):
func _physics_process(delta: float) -> void:
	#get_window().title = " / FPS: " + str(Engine.get_frames_per_second())# + " PARTICLES: " + str(particles.size())

	var params_array = get_params_array(frame, delta)
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)

	var cam_params_array = get_cam_params_array()
	var cam_params_bytes = PackedFloat32Array(cam_params_array).to_byte_array()
	rd.buffer_update(camera_params_buffer, 0, cam_params_bytes.size(), cam_params_bytes)

	frame += 1
	# Dispatch compute to update particle positions
	var local_size = 16
	var groups_x = int(ceil(texture_width / float(local_size)))
	var groups_y = int(ceil(texture_height / float(local_size)))
	var cl = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	#rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
	rd.compute_list_dispatch(cl, 16, 16, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()  # Wait for GPU to finish


	# hwo do we remove this ???/
	#data = rd.texture_get_data(output_texture_rid, 0)
	#var data1 = rd.buffer_get_data(storage_buffer).to_float32_array()
	data = rd.texture_get_data(output_texture_rid, 0)
	img = Image.create_from_data(texture_width, texture_height, false, Image.FORMAT_RGBA8, data)
	tex = ImageTexture.create_from_image(img)
	multimesh_instance.material.set_shader_parameter("particles_data", tex)
	$Sprite2D.texture = tex
	#print(data.slice(0, 16))
	#print(data)
	#print(data1)
	#print(cam_params_bytes.to_float32_array())
	#$Sprite2D2.material.set_shader_parameter("boid_data", tex)

func init_uniform(buffer, binding, type)->RDUniform:
	
	var uniform = RDUniform.new()
	uniform.uniform_type = type#RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform

#region params buffers

func get_params_array(frame, delta):
	var params = []
	#for agent in agents:
	params.append(frame)
	params.append(delta)
	params.append(get_global_mouse_position().x)
	params.append(get_global_mouse_position().y)
		#params.append(noise_offset.z)
	return params

func get_cam_params_array():
	var params = []
	#for agent in agents:
	params.append(my_camera.global_position.x)
	params.append(my_camera.global_position.y)
	params.append(my_camera.zoom.x)
	params.append(my_camera.zoom.y)
	params.append(get_viewport().size.x)
	params.append(get_viewport().size.y)
		#params.append(noise_offset.z)
	return params
#endregion


func _update_boids_gpu(delta, mouse):
	#var params_buffer_bytes = _generate_parameter_buffer(delta,mouse)
	#rd.buffer_update(params_buffer, 0, params_buffer_bytes.size(), params_buffer_bytes)

	var params_array = get_params_array(frame, delta)
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)

	var cam_params_array = get_cam_params_array()
	var cam_params_bytes = PackedFloat32Array(cam_params_array).to_byte_array()
	rd.buffer_update(camera_params_buffer, 0, cam_params_bytes.size(), cam_params_bytes)

	_run_compute_shader(output_texture_rid)
	_run_compute_shader(storage_buffer)
	#_run_compute_shader(bin_prefix_sum_pipeline)
	#_run_compute_shader(bin_reindex_pipeline)
	#_run_compute_shader(boid_pipeline)

func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list,16, 16, 1)
	rd.compute_list_end()
