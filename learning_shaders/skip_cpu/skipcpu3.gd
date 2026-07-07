extends Node2D

var rd: RenderingDevice
var output_texture_rid: RID
var shader: RID
var pipeline: RID
var uniform_set: RID

var texture_width = 400
var texture_height = 400

var data: PackedByteArray#: PackedByteArray = rd.texture_get_data(output_texture_rid, 0)
var img #= Image.create_from_data(texture_width, texture_height, false, Image.FORMAT_RGBA8, data)
var tex #= ImageTexture.create_from_image(img)

func _ready():
	rd = RenderingServer.create_local_rendering_device()
	
	# Create the output texture.
	var tformat = RDTextureFormat.new()
	tformat.width = texture_width
	tformat.height = texture_height
	tformat.depth = 1
	tformat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tformat.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	tformat.mipmaps = 1
	var tview = RDTextureView.new()
	output_texture_rid = rd.texture_create(tformat, tview, [])
	
	# Load and create the compute shader that fills the texture with neon pink.
	var shader_file = load("res://skip_cpu/image_compute.glsl")
	var spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	# Bind the output texture to the shader (set 0, binding 0).
	var uni_outimage = RDUniform.new()
	uni_outimage.binding = 0
	uni_outimage.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uni_outimage.add_id(output_texture_rid)
	uniform_set = rd.uniform_set_create([uni_outimage], shader, 0)
	
	# Dispatch the compute shader.
	var cl = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	
	# Define a workgroup size that matches the shader (16x16) and compute group counts.
	var local_size = 16
	var groups_x = int(ceil(texture_width / float(local_size)))
	var groups_y = int(ceil(texture_height / float(local_size)))
	rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()  # Wait for GPU to finish
	data = rd.texture_get_data(output_texture_rid, 0)
	img = Image.create_from_data(texture_width, texture_height, false, Image.FORMAT_RGBA8, data)
	tex = ImageTexture.create_from_image(img)

	queue_redraw()

func _draw():
	# Read back the texture and draw it.
	#var data: PackedByteArray = rd.texture_get_data(output_texture_rid, 0)
	#var img = Image.create_from_data(texture_width, texture_height, false, Image.FORMAT_RGBA8, data)
	#var tex = ImageTexture.create_from_image(img)
	
	#img.save_png("res://test_output.png")
	#tex = preload("res://test_output.png")
	
	draw_texture_rect(tex, Rect2(Vector2(50, 50), tex.get_size()), false)
