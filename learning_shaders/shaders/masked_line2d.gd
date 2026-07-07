extends Line2D

@export var target_node : Node2D


func _process(delta):
	if target_node:
		# Get the position and size of the target node
		var target_position = target_node.global_position
		var target_size = Vector2(50, 50) # Replace with actual size logic

		# Pass them to the shader
		#material.set_shader_param("target_size", target_size)
		material.set("shader_parameter/target_position", target_position)
		material.set("shader_parameter/target_size", target_size)

		#print(material.get("shader_parameter/target_size"))
