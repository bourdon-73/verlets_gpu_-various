extends Node2D

@export var is_rendering := true
@export var gpu_particles_2d: GPUParticles2D
var objects: Array = []

# Spawning setup
var spawn_timer := 0.0
@export var spawn_delay := 0.25
@export var count := 100
var spawned := 0

# Bezier control points
@export var control_point_distance := 80.0
@export var particles_per_curve := 100

# Gravity parameters
@export var gravity := Vector2(0, 980)  # 9.8 m/s² downward

# Particle emission points
var emission_points := []
var emission_velocities := []
var emission_colors := []

func _ready():
	if is_rendering and gpu_particles_2d:
		# Configure the GPUParticles2D for path following
		setup_particle_system()

func setup_particle_system():
	# Make sure we have a valid particle system
	if not gpu_particles_2d:
		printerr("No GPUParticles2D assigned!")
		return
		
	# Configure the particle system
	gpu_particles_2d.emitting = false
	gpu_particles_2d.amount = count * particles_per_curve
	gpu_particles_2d.lifetime = 2.0
	gpu_particles_2d.explosiveness = 0.0
	gpu_particles_2d.fixed_fps = 0  # Use the game's FPS
	gpu_particles_2d.local_coords = false
	
	# Create a particle material if not already set
	if not gpu_particles_2d.process_material:
		var particle_material = ParticleProcessMaterial.new()
		particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		particle_material.particle_flag_disable_z = true
		particle_material.gravity = Vector3.ZERO  # We'll handle our own physics
		particle_material.direction = Vector3(0, 0, 0)
		particle_material.spread = 0.0
		particle_material.color = Color(1, 1, 1, 0.8)
		gpu_particles_2d.process_material = particle_material

func _process(delta: float) -> void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) + " SPAWNED: " + str(spawned)
	
	if spawned < count:
		spawn_timer += delta
		if spawn_timer >= spawn_delay:
			spawn_timer = 0.0
			var x = randf_range(-200, 400)
			var y = randf_range(-200, -500)
			create_rigid_object(Vector2(x, y))
			spawned += 1
	
	# Update particle emission points to follow bezier curves
	if is_rendering and gpu_particles_2d and objects.size() > 1:
		update_particle_emission_points()

func update_particle_emission_points():
	emission_points.clear()
	emission_velocities.clear()
	emission_colors.clear()
	
	# Calculate points along bezier curves between physics objects
	for i in range(objects.size() - 1):
		var start_pos = PhysicsServer2D.body_get_state(objects[i][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		var end_pos = PhysicsServer2D.body_get_state(objects[i+1][0], PhysicsServer2D.BODY_STATE_TRANSFORM).origin
		
		# Calculate control points
		var direction = (end_pos - start_pos).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)
		
		var cp1 = start_pos + direction * control_point_distance + perpendicular * randf_range(-40, 40)
		var cp2 = end_pos - direction * control_point_distance + perpendicular * randf_range(-40, 40)
		
		# Generate a random color for this curve
		var color = Color(randf(), randf(), randf(), 0.8)
		
		# Generate points along the bezier curve
		for j in range(particles_per_curve):
			var t = float(j) / particles_per_curve
			var point = cubic_bezier_point(start_pos, cp1, cp2, end_pos, t)
			
			# Calculate the tangent vector for velocity
			var t_delta = 0.01
			var t_next = min(t + t_delta, 1.0)
			var next_point = cubic_bezier_point(start_pos, cp1, cp2, end_pos, t_next)
			var velocity = (next_point - point) / t_delta
			
			emission_points.append(point)
			emission_velocities.append(velocity)
			emission_colors.append(color)
	
	# Update the particle system with new emission points
	update_particle_system()

func update_particle_system():
	if not gpu_particles_2d or not gpu_particles_2d.process_material:
		return
		
	# Set emission points
	var material = gpu_particles_2d.process_material
	material.emission_point_count = emission_points.size()
	material.emission_point_texture = create_point_texture(emission_points)
	
	# Set velocities and colors
	material.initial_velocity_min = 0
	material.initial_velocity_max = 0
	material.color_ramp = create_color_ramp(emission_colors)
	
	# Restart emission
	gpu_particles_2d.emitting = true

func create_point_texture(points: Array) -> Texture2D:
	# Create a data texture from the points
	var img = Image.create(points.size(), 1, false, Image.FORMAT_RGBAF)
	#img.lock()
	
	for i in range(points.size()):
		var point = points[i]
		img.set_pixel(i, 0, Color(point.x, point.y, 0, 1))
	
	#img.unlock()
	
	var texture = ImageTexture.create_from_image(img)
	return texture

func create_color_ramp(colors: Array) -> Gradient:
	var gradient = Gradient.new()
	var color_points = []
	
	for i in range(colors.size()):
		var offset = float(i) / max(colors.size() - 1, 1)
		color_points.append({"offset": offset, "color": colors[i]})
	
	# Sort by offset
	color_points.sort_custom(func(a, b): return a["offset"] < b["offset"])
	
	# Set gradient points
	#gradient.clear_points()
	for point in color_points:
		gradient.add_point(point["offset"], point["color"])
	
	return gradient

func cubic_bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return (
		u * u * u * p0 +
		3.0 * u * u * t * p1 +
		3.0 * u * t * t * p2 +
		t * t * t * p3
	)

func create_rigid_object(pos: Vector2) -> void:
	var radius = 10
	var body_rid = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(body_rid, PhysicsServer2D.BODY_MODE_RIGID)
	var shape = PhysicsServer2D.circle_shape_create()
	PhysicsServer2D.shape_set_data(shape, radius)
	PhysicsServer2D.body_add_shape(body_rid, shape)
	var trans = Transform2D(0, pos)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, trans)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_CAN_SLEEP, true)
	PhysicsServer2D.body_set_param(body_rid, PhysicsServer2D.BODY_PARAM_BOUNCE, true)
	PhysicsServer2D.body_set_space(body_rid, get_world_2d().space)
	
	# Store physics body
	objects.append([body_rid, null])
	
	# Add random velocity when creating
	var velocity = Vector2(randf_range(-100, 100), randf_range(-50, 50))
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func _physics_process(delta: float) -> void:
	# Apply gravity and update physics
	for object in objects:
		var velocity = PhysicsServer2D.body_get_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
		velocity += gravity * delta
		PhysicsServer2D.body_set_state(object[0], PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)

func _exit_tree() -> void:
	# Free physics bodies
	for object in objects:
		PhysicsServer2D.free_rid(object[0])
