extends Node2D

@onready var multimesh2d = $MultiMeshInstance2D

func _ready():
	var amount_x = 10
	var amount_y = 10
	var spacing = 32
	var total = amount_x * amount_y

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count = total
	multimesh2d.multimesh = mm

	var mesh = QuadMesh.new()
	mesh.size = Vector2(16, 16)
	mm.mesh = mesh

	for x in range(amount_x):
		for y in range(amount_y):
			var index = y * amount_x + x
			var pos = Vector2(x * spacing, y * spacing)
			var angle = 0.0  # You can randomize this for rotation flair
			var xform = Transform2D(angle, pos)
			mm.set_instance_transform_2d(index, xform)
