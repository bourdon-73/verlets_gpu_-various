extends Node2D

const PARTICLE_COUNT := 100
const TEX_WIDTH := 32 # Make sure it's >= PARTICLE_COUNT * 2 / height

@onready var multimesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D

func _ready():
	var count = multimesh_instance.multimesh.instance_count
	var grid_size : int = ceil(sqrt(count)) # Number of items per row/column
	var spacing = 16

	for  i : int in count:
		var x = i % grid_size
		var y = i / grid_size
		var pos = Vector2(x * spacing, y * spacing)
		var angle = 0.0 # Change if you want rotation
		multimesh_instance.multimesh.set_instance_transform_2d(i, Transform2D(angle, pos))


	# Step 2: Build the texture with particle data
	var image_height := int(ceil((PARTICLE_COUNT * 2.0) / TEX_WIDTH))
	var image := Image.create(TEX_WIDTH, image_height, false, Image.FORMAT_RGBAF)
	#image.lock()

	for i in PARTICLE_COUNT:
		# Particle transform
		var x = (i % 10) * 32.0
		var y = (i / 10) * 32.0
		var rot = i * 0.1
		var size = 8.0

		# Particle color
		var color = Color(1.0, 0.2 + (i % 5) * 0.15, 0.2, 1.0) # reddish gradient

		# Store two texels per particle
		var index = i * 2

		var x0 = index % TEX_WIDTH
		var y0 = index / TEX_WIDTH
		image.set_pixel(x0, y0, Color(x, y, rot, size))

		var x1 = (index + 1) % TEX_WIDTH
		var y1 = (index + 1) / TEX_WIDTH
		image.set_pixel(x1, y1, color)

	#image.unlock()

	var texture := ImageTexture.create_from_image(image)

	# Step 3: Assign the shader material
	var matt := ShaderMaterial.new()
	matt.shader = preload("res://skip_cpu/verletshader.gdshader")
	matt.set_shader_parameter("particles_data", texture)
	matt.set_shader_parameter("texture_width", float(TEX_WIDTH))
	matt.set_shader_parameter("particles_count", float(PARTICLE_COUNT))

	multimesh_instance.material = matt
