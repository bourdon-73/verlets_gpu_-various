extends Node2D

var rd : RenderingDevice
var tex_storage : RID

func _ready():
	rd = RenderingServer.create_local_rendering_device()

	# Step 1: Create empty texture
	var width = 128
	var height = 128

	var fmt = RDTextureFormat.new()
	fmt.width = width
	fmt.height = height
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT

	tex_storage = rd.texture_create(fmt, RDTextureView.new())

	# Step 2: Setup compute shader
	var shader_file = load("res://pixel_render/calcu_shader.glsl")
	var shader_spirv = shader_file.get_spirv()
	var shader = rd.shader_create_from_spirv(shader_spirv)
	var pipeline = rd.compute_pipeline_create(shader)

	# Step 3: Uniform binding
	var img_uniform = RDUniform.new()
	img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	img_uniform.binding = 0
	img_uniform.add_id(tex_storage)

	var uniform_set = rd.uniform_set_create([img_uniform], shader, 0)

	# Step 4: Dispatch compute
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, width / 8, height / 8, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	var ttt = rd.buffer_get_data(tex_storage)

	# Step 5: Show texture using ShaderMaterial
	
var agent_image : Image
var agent_texture : ImageTexture
var image_size : Vector2i = Vector2i(512, 512)
func _read_image_buffers(compute_stage: int) -> void:
	var start_time = Time.get_ticks_usec()
	#if (compute_stage == stage.MOTOR_SENSORY):
	var agent_image_data := rd.texture_get_data(tex_storage, 0)
	print(agent_image_data)
	agent_image = Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RF, agent_image_data)
	#var trail_image_data := rd.texture_get_data(trail_map_out_buffer, 0)
	#trail_image = Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RF, trail_image_data)
	emit_signal('buffer_read_time_updated', (Time.get_ticks_usec() - start_time) / 1000.0)
