extends Node2D

const PARTICLE_COUNT = 100
const TEX_WIDTH = 64 # must fit 2 * PARTICLE_COUNT

@onready var multimesh_instance :MultiMeshInstance2D= $MultiMeshInstance2D


#
#func _ready():
	#for i in multimesh_instance.multimesh.instance_count:
		#var angle = PI
		#var pos = Vector2(i * 64, 0)
		#multimesh_instance.multimesh.set_instance_transform_2d(i, Transform2D(angle, pos))

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

	#update_multimesh_aabb()

func update_multimesh_aabb():
	# Create a new AABB
	var new_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
	
	# Assign it to your MultiMeshInstance3D
	multimesh_instance.multimesh.custom_aabb = new_aabb

#func _ready():
	#var multimesh := MultiMesh.new()
	#multimesh.instance_count = PARTICLE_COUNT
	#multimesh.transform_format = MultiMesh.TRANSFORM_2D
	#multimesh_instance.multimesh = multimesh
#
	#var image_height := int(ceil((PARTICLE_COUNT * 2.0) / TEX_WIDTH))
	#var image := Image.create(TEX_WIDTH, image_height, false, Image.FORMAT_RGBAF)
	##image.lock()
#
	#for i in PARTICLE_COUNT:
		#var x = i * 10.0
		#var y = 100.0
		#var rot = 0.0
		#var size = 1.0
		#var color = Color(1.0, 0.0, 0.0, 1.0) # RED
#
		#var index = i * 2
		#var x0 = index % TEX_WIDTH
		#var y0 = index / TEX_WIDTH
		#image.set_pixel(x0, y0, Color(x, y, rot, size))
#
		#var x1 = (index + 1) % TEX_WIDTH
		#var y1 = (index + 1) / TEX_WIDTH
		#image.set_pixel(x1, y1, color)
	##image.unlock()
#
	#var texture := ImageTexture.create_from_image(image)
#
	#var material := ShaderMaterial.new()
	#material.shader = preload("res://skip_cpu/verletshader.gdshader")
	#material.set_shader_parameter("particles_data", texture)
	#material.set_shader_parameter("texture_width", float(TEX_WIDTH))
	#material.set_shader_parameter("particles_count", float(PARTICLE_COUNT))
#
	#multimesh_instance.material = material
