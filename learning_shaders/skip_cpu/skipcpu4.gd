extends Node2D

const PARTICLE_COUNT := 100
const TEX_WIDTH := 64 # Make sure it's >= PARTICLE_COUNT * 2 / height
@onready var multimesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D

var rd: RenderingDevice
var output_texture_rid: RID
var shader: RID
var pipeline: RID
var uniform_set: RID

var params_buffer: RID
var storage_buffer: RID

var texture_width = 400
var texture_height = 400

# Use Texture2DRD for direct GPU texture access
var tex: Texture2DRD

var frame: int = 1

func _ready():
	# Setup MultiMesh instance positions
	var count = multimesh_instance.multimesh.instance_count
	var grid_size: int = ceil(sqrt(count))
	var spacing = 16

	for i: int in count:
		var x = i % grid_size
		var y = i / grid_size
		var pos = Vector2(x * spacing, y * spacing)
		multimesh_instance.multimesh.set_instance_transform_2d(i, Transform2D(0.0, pos))

	setup_compute_shader()
	
	# Assign shader material using the GPU texture directly
	var matt := ShaderMaterial.new()
	matt.shader = preload("res://skip_cpu/verletshader.gdshader")
	matt.set_shader_parameter("particles_data", tex)
	matt.set_shader_parameter("texture_width", float(TEX_WIDTH))
	matt.set_shader_parameter("particles_count", float(PARTICLE_COUNT))
	
	multimesh_instance.material = matt

func setup_compute_shader():
	# Setup rendering device
	rd = RenderingServer.create_local_rendering_device()
	
	# Create the output texture with proper format for GPU storage and sampling
	var tformat = RDTextureFormat.new()
	tformat.width = texture_width
	tformat.height = texture_height
	tformat.depth = 1
	tformat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tformat.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	tformat.mipmaps = 1
	var tview = RDTextureView.new()
	output_texture_rid = rd.texture_create(tformat, tview, [])
	
	# Initial clear with compute shader
	var shader_file = load("res://skip_cpu/image_compute.glsl")
	var spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	# Setup uniform bindings
	var uni_outimage = RDUniform.new()
	uni_outimage.binding = 0
	uni_outimage.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uni_outimage.add_id(output_texture_rid)

	# Parameter buffer (use float32 for frame counter and other params)
	var params_bytes = PackedFloat32Array(get_params_array(frame)).to_byte_array()
	params_buffer = rd.storage_buffer_create(max(params_bytes.size(), 2048), params_bytes)
	var params_uniform = init_uniform(params_buffer, 1, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	# Additional storage buffer if needed
	var storage_pba = PackedByteArray()
	storage_pba.resize(4)
	storage_buffer = rd.storage_buffer_create(4, storage_pba)
	var storage_uniform = init_uniform(storage_buffer, 2, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	# Create the uniform set
	uniform_set = rd.uniform_set_create([uni_outimage, params_uniform, storage_uniform], shader, 0)
	
	# Run compute shader once to initialize
	dispatch_compute()
	
	# Create the Texture2DRD that directly refers to the GPU texture
	tex = Texture2DRD.new()
	tex.texture_rd_rid = output_texture_rid

func _physics_process(_delta: float) -> void:
	# Update parameters for this frame
	var params_array = get_params_array(frame)
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	
	# Dispatch the compute shader
	dispatch_compute()
	
	# No need to sync or copy data back to CPU
	frame += 1

func dispatch_compute() -> void:
	var cl = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	rd.compute_list_dispatch(cl, 128, 128, 1)
	rd.compute_list_end()
	rd.submit()
	# No sync needed here! The GPU will process this when it can

func init_uniform(buffer, binding, type) -> RDUniform:
	var uniform = RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform

func get_params_array(frame):
	var params = []
	params.append(frame)
	# Add any other parameters your compute shader needs
	return params
