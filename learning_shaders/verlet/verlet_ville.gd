
class_name VerletSimulation
extends Node2D

var objects: Array[VerletObject] = []
@export var simulation_bounds: Rect2

var sub_steps: int = 8  # Number of substeps for better stability

@export var is_simulation_online : bool = false

func _ready():
	
	if !is_simulation_online:
		return
	
	#simulation_bounds = Rect2(Vector2(0, 0), get_viewport_rect().size)
	var spawn_area_size = simulation_bounds.size * 0.6
	var spawn_area_position = simulation_bounds.position + (simulation_bounds.size - spawn_area_size) / 2.0
	var spawn_area = Rect2(spawn_area_position, spawn_area_size)
	# Create some objects with varying bounciness
	for i in range(10):
		var pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		var radius = randf_range(5, 15)
		var color = Color(randf(), randf(), randf())
		var bounce = randf_range(0.0, 0.0)
		var obj = VerletObject.new(pos, radius, color, bounce)
		objects.append(obj)
	
	# Pin one object at the top
	objects[0].pin(Vector2(simulation_bounds.size.x / 2, 50))

#func _process(delta: float):
func _physics_process(delta: float) -> void:
	# For better stability we use multiple substeps
	var sub_delta = delta / sub_steps
	
	for _step in range(sub_steps):
		# Update physics
		update_physics(sub_delta)
		
		# Handle collisions
		handle_collisions()
	
	# Trigger redraw
	queue_redraw()

func update_physics(delta: float):
	var mouse_pos = get_viewport().get_mouse_position()

	for i in range(objects.size()):
		var obj = objects[i]
		
		# Make the first object follow the mouse
		#if !i == 1:
			# Apply gravity
		obj.apply_force(obj.gravity)

		# Update position
		obj.update_position(delta)

		# Constrain to bounds
		obj.constrain_to_bounds(simulation_bounds)

		#elif i == 1:
			##obj.pin(mouse_pos)
			#obj.apply_force((get_global_mouse_position()-obj.current_position)*4)
			## Update position
			#obj.update_position(delta)
#
			## Constrain to bounds
			#obj.constrain_to_bounds(simulation_bounds)

func handle_collisions():
	# Collision response between objects with bounciness
	for i in range(objects.size()):
		for j in range(i + 1, objects.size()):
			var obj1 = objects[i]
			var obj2 = objects[j]
			
			var diff = obj1.current_position - obj2.current_position
			var dist = diff.length()
			var min_dist = obj1.radius + obj2.radius
			
			if dist < min_dist:
				# Calculate collision normal
				var normal = diff.normalized()
				
				# Calculate collision response magnitude based on average bounciness
				var avg_bounciness = (obj1.bounciness + obj2.bounciness) / 2.0
				var correction = normal * (min_dist - dist)
				
				# Calculate velocities
				var vel1 = obj1.current_position - obj1.old_position
				var vel2 = obj2.current_position - obj2.old_position
				
				# Calculate momentum exchange (simplified)
				var total_mass = obj1.radius * obj1.radius + obj2.radius * obj2.radius
				var force_ratio1 = obj2.radius * obj2.radius / total_mass
				var force_ratio2 = obj1.radius * obj1.radius / total_mass
				
				# Apply position correction and velocity exchange
				if not obj1.is_pinned:
					obj1.current_position += correction * force_ratio1
					# Apply bounce effect to velocity (stored in position difference)
					var impact = normal.dot(vel1 - vel2) * avg_bounciness
					obj1.old_position = obj1.current_position - (vel1 - normal * impact * force_ratio1)
				
				if not obj2.is_pinned:
					obj2.current_position -= correction * force_ratio2
					# Apply bounce effect to velocity (stored in position difference)
					var impact = normal.dot(vel2 - vel1) * avg_bounciness
					obj2.old_position = obj2.current_position - (vel2 + normal * impact * force_ratio2)

func _draw():
	# Draw simulation bounds
	draw_rect(simulation_bounds, Color.RED, false, 2.0)
	
	# Draw all objects
	for obj in objects:
		obj.draw(self)


# Optional utility for demonstrating different bounciness values
func add_bouncy_ball(position: Vector2, radius: float, bouncy_value: float, color: Color = Color.WHITE):
	var obj = VerletObject.new(position, radius, color, bouncy_value)
	objects.append(obj)
	return obj

# Optional debug visualization
func draw_bounciness_meter():
	for i in range(objects.size()):
		var obj = objects[i]
		var pos = obj.current_position + Vector2(0, -obj.radius - 15)
		var width = 20
		var height = 20
		
		# Draw bounciness meter background
		draw_rect(Rect2(pos.x - width/2, pos.y - height/2, width, height), Color.DARK_GRAY)
		
		# Draw bounciness meter fill
		draw_rect(Rect2(pos.x - width/2, pos.y - height/2, width * obj.bounciness, height), 
				 Color(0.2, 0.8, 0.2))
