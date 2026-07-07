extends Node2D


"
max 200 at 60 fps
"

@onready var viewport_size = get_viewport_rect().size
const GRAVITY = Vector2(0, 500)
const SUBSTEPS = 8  # Reduced from 8 to 4
const BOUNDS_RADIUS = 150.0
const BOUNDS_CENTER = Vector2(500, -200)
@onready var renderer: MultiMeshInstance2D = $MultiMeshInstance2D


# FPS monitoring variables
const TARGET_FPS = 30
var current_fps = 60
var fps_counter = 0
var fps_timer = 0
var can_spawn = true
var particles_per_click = 1
var warmup_frames = 3
var max_particles = 10000

# Spatial hash optimization
const CELL_SIZE = 20.0  # Increased cell size slightly
var spatial_hash = {}
var checked_pairs = {}  # Made this a class variable to avoid recreation
var particles: Array = []

var packed_particle_data : PackedFloat32Array



## - compute - ##




const buffer_set_index : int = 0


const storage_bind_index : int = 0
const params_bind_index : int = 1
const pos_bind_index : int = 2
const particles_bind_index : int = 3


var rd: RenderingDevice
var shader : RID
var pipeline : RID


var buffer_set : RID
var params_buffer : RID
var storage_buffer : RID
var pos_buffer : RID
var particles_buffer : RID

var pos_data_bytes : PackedByteArray
var param_data_bytes : PackedByteArray

var _delta : float

const MAX_PARTICLES : int = 10000
const FLOATS_PER_PARTICLE : int = 12
var mouse_left_down = true

func _ready():
	#init_compute()
	#_ready_multi_mesh()
	#fetch_and_process_compute_data()
	pass


func init_compute():
	rd= RenderingServer.create_local_rendering_device()
	# Load compute shader
	var shader_file : RDShaderFile = load("res://verlet/compute_shader2.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	# Create params buffer
	var pba2 = PackedByteArray()
	pba2.resize(500) # Fills with zeroes

	#var buffer = rd.storage_buffer_create(size, pba2)

	var params_array = get_params_array()
	var params_bytes = PackedFloat32Array(params_array).to_byte_array()
	#(pba2)
	#rd.buffer_update(params_buffer, 0, params_bytes.size(), params_bytes)
	#var params_bytes = PackedFloat32Array(get_params_array()).to_byte_array()
	#params_buffer = rd.storage_buffer_create(4, PackedByteArray([0, 0, 0, 0]))
	params_buffer = rd.storage_buffer_create(500, pba2)
	var params_uniform = init_uniform(params_buffer, params_bind_index,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	
	var pba = PackedByteArray()
	pba.resize(64)
	for i in range(16):
		pba.encode_float(i*4, 2.0)
	storage_buffer = rd.storage_buffer_create(64, pba)
	var storage_uniform = init_uniform(storage_buffer, storage_bind_index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)



	var pba3 = PackedByteArray()
	pba3.resize(100) # Fills with zeroes
	pos_buffer = rd.storage_buffer_create(100, pba3)

	var pos_uniform = init_uniform(pos_buffer, pos_bind_index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)


	var pba_part = PackedByteArray()
	pba_part.resize(100000) # Fills with zeroes
	#pba_part.insert(0, 1)
	particles_buffer = rd.storage_buffer_create(100000, pba_part)
	#particles_buffer = rd.storage_buffer_create(4, [0, 4, 8, 7])

	#var pba_part = PackedByteArray()
	#pba_part.resize(4 * 4) # 4 floats * 4 bytes each = 16 bytes
#
	#pba_part.encode_float(0 * 4, 0.0)
	#pba_part.encode_float(1 * 4, 4.0)
	#pba_part.encode_float(2 * 4, 8.0)
	#pba_part.encode_float(3 * 4, 7.0)
#
	#particles_buffer = rd.storage_buffer_create(pba_part.size(), pba_part)


	var particles_uniform = init_uniform(particles_buffer, particles_bind_index, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)
	## Create buffer setter and pipeline
	var buffers = [storage_uniform, params_uniform, pos_uniform, particles_uniform]
	buffer_set = rd.uniform_set_create(buffers, shader, buffer_set_index)
	pipeline = rd.compute_pipeline_create(shader)

	var compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	rd.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	# Dispatch 1x1x1 (XxYxZ) work groups
	rd.compute_list_dispatch(compute_list, 128, 1, 1)
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()

func run_compute():
	# Update params buffer
	# Prepare compute list
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, buffer_set, buffer_set_index)
	rd.compute_list_dispatch(compute_list, 128, 1, 1)
	rd.compute_list_end()
	
	# Run
	rd.submit()
	#last_compute_dispatch_frame = frame
	#waiting_for_compute = true

func fetch_and_process_compute_data():
	rd.sync()
	#waiting_for_compute = false
	# Get output
	var byte_data = rd.buffer_get_data(storage_buffer)
	#for i in range(16):
	#for i in range(0, 26):
		#print(i, ": ", byte_data[i])

	for i in range(16):
		print(byte_data.decode_float(i*4))
		#byte_data.decode_float(i*12)
		#print(byte_data[i])
		pass

func pull_acceleration_from_gpu():
	#rd.sync()
	var byte_data = rd.buffer_get_data(particles_buffer).to_float32_array()
	#for i in range(particles.size()):
	for i in range(particles.size()):
		#print(byte_data.decode_float(i*4))
		var index = i * 12  # Assuming your particle has 10 floats: pos(2), last_pos(2), accel(2), radius(1), pad(1), color(4) = 12, but aligned, maybe padded to 16
		var accel_x = byte_data[index + 4] - 1
		var accel_y = byte_data[index + 5] - 1
		var accel = Vector2(accel_x, accel_y)
		
		var pos_x = byte_data[index + 0]
		var pos_y = byte_data[index + 1]
		var pos = Vector2(pos_x, pos_y)
#
		var last_pos_x = byte_data[index + 2]
		var last_pos_y = byte_data[index + 3]
		var last_pos = Vector2(last_pos_x, last_pos_y)
		var det = byte_data[index + 6]
#
		##var accel_x = byte_data[index + 4]
		##var accel_y = byte_data[index + 5]
#
		var temp = Vector2(pos_x, pos_y)#p["pos"]
		#print(det)
		particles[i]["pos"] = pos
		particles[i]["last_pos"] = last_pos
		particles[i]["accel"] = accel
		#particles[i]["accel"] = Vector2.ZERO
		#print(det)
		var debug_floats = rd.buffer_get_data(storage_buffer).to_float32_array()
		#print("DEBUG pos.y[0] = ", debug_floats[0])


		pass
	#print(byte_data)
	#print(byte_data[0 + 4])
	#print(byte_data[0 + 5])



func init_uniform(buffer, binding, type)->RDUniform:
	
	var uniform = RDUniform.new()
	uniform.uniform_type = type#RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform

func get_params_array():
	var params = []
	#for agent in agents:
	params.append(_delta)
	params.append(particles.size())
		#params.append(noise_offset.z)
	return params












## - verlet - ##


















func create_verlet_obj(pos: Vector2, radius := 1.0, color := Color.WHITE) -> Dictionary:
	return {
		"pos": pos,
		"last_pos": pos,
		"accel": Vector2.ZERO,
		"radius": radius,
		"color": color,
	}

func spawn_particles_at_mouse2():
	if !can_spawn or particles.size() >= max_particles:
		return
		
	var mouse_pos = get_global_mouse_position()
	var start_idx = particles.size()
	
	for i in particles_per_click:
		if particles.size() >= max_particles:
			break
			
		var angle = TAU * randf()
		var distance = 20 * randf()
		var pos = mouse_pos + Vector2(cos(angle), sin(angle)) * distance
		var color = Color.from_hsv(randf(), 1, 1)
		particles.append(create_verlet_obj(pos, 5.0, color))
	
	# Only update instance count when necessary
	if renderer and renderer.multimesh.instance_count < particles.size():
		renderer.multimesh.instance_count = particles.size()


	# 🟡 NOW update the GPU buffer for just the new particles
	var new_particle_data = PackedFloat32Array()
	for i in range(start_idx, particles.size()):
		var p = particles[i]
		new_particle_data.push_back(p["pos"].x)
		new_particle_data.push_back(p["pos"].y)
		new_particle_data.push_back(p["last_pos"].x)
		new_particle_data.push_back(p["last_pos"].y)

		new_particle_data.push_back(p["accel"].x)
		new_particle_data.push_back(p["accel"].y)
		new_particle_data.push_back(p["radius"])
		new_particle_data.push_back(0.0)

		new_particle_data.push_back(p["color"].r)
		new_particle_data.push_back(p["color"].g)
		new_particle_data.push_back(p["color"].b)
		new_particle_data.push_back(p["color"].a)

	# 💾 Send that new chunk to the GPU
	var byte_data := PackedByteArray()
	byte_data.resize(new_particle_data.size() * 4) # 4 bytes per float

	# Convert float data to raw bytes
	for i in range(new_particle_data.size()):
		byte_data.encode_float(i * 4, new_particle_data[i])


	# Now update the buffer
	rd.buffer_update(
		particles_buffer,
		start_idx * FLOATS_PER_PARTICLE * 4, # offset in bytes
		byte_data.size(),                    # size in bytes
		byte_data
	)

## dt

	var dt = (1.0 / Engine.get_physics_ticks_per_second()) / SUBSTEPS 
	var dt_squared = dt * dt
	var param_data = PackedFloat32Array([dt, float(particles.size())])
	var param_bytes : PackedByteArray = PackedByteArray()
	param_bytes.resize(param_data.size() * 4)
	for i in range(param_data.size()):
		param_bytes.encode_float(i * 4, param_data[i])

	rd.buffer_update(params_buffer, 0, param_bytes.size(), param_bytes)
	#print("Sending dt:", dt, "particle count:", particles.size())
	#print(param_data)
	run_compute()
	#print(byte_data.size())
	#for i in range(16):
			#
		#print(byte_data.decode_float(i*4))
	#fetch_and_process_compute_data()
	#pull_acceleration_from_gpu()
	#print(particles.size())


func _ready_multi_mesh():
	# Pre-allocate the multimesh with maximum capacity
	if renderer:
		renderer.multimesh.instance_count = max_particles
	
	# For tracking performance
	fps_timer = 0
	fps_counter = 0

func _input(event: InputEvent) -> void:
	# Simplified input handling
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_left_down = true
	else:
		mouse_left_down = false
		
	#elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#spawn_particles_at_mouse()

#func _process(delta):
	## FPS monitoring
	#fps_timer += delta
	#fps_counter += 1
	#
	#if fps_timer >= 1.0:
		#current_fps = fps_counter
		#fps_counter = 0
		#fps_timer = 0
		#warmup_frames -= 1
		#
		#if warmup_frames <= 0 and current_fps < TARGET_FPS and can_spawn:
			#can_spawn = false
			##("STOPPED SPAWNING - Final particle count: ", particles.size(), " - FPS: ", current_fps)
		#
		##print("FPS: ", current_fps, " Particles: ", particles.size())
#
	##run_compute()
	##fetch_and_process_compute_data()

func spawn_particles_at_mouse():
	if !mouse_left_down:
		return
	if !can_spawn or particles.size() >= max_particles:
		return
		
	var mouse_pos = get_global_mouse_position()
	
	for i in particles_per_click:
		if particles.size() >= max_particles:
			break
			
		var angle = TAU * randf()
		var distance = 20 * randf()
		var pos = mouse_pos + Vector2(cos(angle), sin(angle)) * distance
		var color = Color.from_hsv(randf(), 1, 1)
		particles.append(create_verlet_obj(pos, 8.0, color))
	
	# Only update instance count when necessary
	if renderer and renderer.multimesh.instance_count < particles.size():
		renderer.multimesh.instance_count = particles.size()

func _physics_process(delta)->void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) + " PARTICLES: " + str(particles.size())
	spawn_particles_at_mouse()

	if particles.size() == 0:
		return
	
	#var dt = delta / SUBSTEPS
	var dt = (1.0 / Engine.get_physics_ticks_per_second()) / SUBSTEPS
	#pull_acceleration_from_gpu(dt)
	#run_compute()
	#rd.sync()
	#simulate()
	#RenderingServer.call_on_render_thread(_run_compute_shader)
	for i in SUBSTEPS:
		simulate(dt)
		pass
	update_multimesh()
	queue_redraw()

func simulate(dt):
	#Apply gravity once
	#print(dt)
	
	#pull_acceleration_from_gpu()
	for p in particles:
		p["accel"] += GRAVITY
	
# Update positions
	for p in particles:
		var temp = p["pos"]
		p["pos"] += (p["pos"] - p["last_pos"]) + p["accel"] * dt * dt
		p["last_pos"] = temp
		p["accel"] = Vector2.ZERO
	
	#Only update spatial hash and check collisions if we have enough particles
	if particles.size() > 1:
		update_spatial_hash()
		check_collisions()
	
	enforce_boundary()
	
	#print(particles.size())

func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, buffer_set, 0)
	rd.compute_list_dispatch(compute_list, 128, 1, 1)
	rd.compute_list_end()
			

func check_collisions2():
	const response_coef := 0.75
	checked_pairs.clear()  # Clear instead of recreating

	# Process only cells that actually contain particles
	var active_cells = spatial_hash.keys()
	for cell_idx in range(active_cells.size()):
		var cell = active_cells[cell_idx]
		var cell_particles = spatial_hash[cell]
		
		# First check collisions within the same cell
		for i_idx in range(cell_particles.size()):
			var i = cell_particles[i_idx]
			for j_idx in range(i_idx + 1, cell_particles.size()):
				var j = cell_particles[j_idx]
				process_collision(i, j, response_coef)
		
		# Then check with neighbor cells, but only in the "forward" direction
		# to avoid redundant checks
		for neighbor_idx in range(cell_idx + 1, active_cells.size()):
			var neighbor_cell = active_cells[neighbor_idx]
			
			# Only process if they're actually neighbors (within 1 cell distance)
			if abs(cell.x - neighbor_cell.x) <= 1 and abs(cell.y - neighbor_cell.y) <= 1:
				for i in spatial_hash[cell]:
					for j in spatial_hash[neighbor_cell]:
						process_collision(i, j, response_coef)


func check_collisions():
	const response_coef := 0.75
	checked_pairs.clear()
	
	# Pre-define neighbor offsets
	var neighbor_offsets = [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
	]
	
	# Process only cells that actually contain particles
	for cell in spatial_hash:
		var cell_particles = spatial_hash[cell]
		
		# Check collisions within the same cell
		var cell_size = cell_particles.size()
		for i_idx in range(cell_size):
			var i = cell_particles[i_idx]
			for j_idx in range(i_idx + 1, cell_size):
				var j = cell_particles[j_idx]
				process_collision(i, j, response_coef)
		
		# Only check the "forward" neighboring cells to avoid duplicate checks
		for offset in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]:
			var neighbor_cell = cell + offset
			if spatial_hash.has(neighbor_cell):
				for i in cell_particles:
					for j in spatial_hash[neighbor_cell]:
						process_collision(i, j, response_coef)


func process_collision(i: int, j: int, response_coef: float):
	# Skip if already checked
	var pair_key = i if i < j else j
	var pair_value = j if i < j else i
	if checked_pairs.has(pair_key) and pair_key in checked_pairs and pair_value in checked_pairs[pair_key]:
		return
		
	# Record that we've checked this pair
	if not checked_pairs.has(pair_key):
		checked_pairs[pair_key] = {}
	checked_pairs[pair_key][pair_value] = true
	
	var a = particles[i]
	var b = particles[j]
	var delta_pos = a["pos"] - b["pos"]
	var dist2 = delta_pos.length_squared()
	var min_dist = a["radius"] + b["radius"]
	
	if dist2 < min_dist * min_dist and dist2 > 0.0001:
		var dist = sqrt(dist2)
		var normal = delta_pos / dist
		var mass_ratio_a = a["radius"] / (a["radius"] + b["radius"])
		var mass_ratio_b = b["radius"] / (a["radius"] + b["radius"])
		var delta = 0.5 * response_coef * (dist - min_dist)
		
		a["pos"] -= normal * (mass_ratio_b * delta)
		b["pos"] += normal * (mass_ratio_a * delta)

func enforce_boundary():
	for p in particles:
		var to_center =  BOUNDS_CENTER - p["pos"]# - BOUNDS_CENTER
		var dist = to_center.length()
		if dist > (BOUNDS_RADIUS - p["radius"]):
			var n = to_center / dist
			#p["pos"] = BOUNDS_CENTER + to_center.normalized() * (BOUNDS_RADIUS - p["radius"])
			p["pos"] = BOUNDS_CENTER - n * (BOUNDS_RADIUS - p["radius"])

func update_multimesh():
	var mm := renderer.multimesh
	var count = particles.size()
	
	for i in count:
		var p = particles[i]
		# Remove the scale Vector2(10, 10)
		mm.set_instance_transform_2d(i, Transform2D(0, Vector2(1, 1), 0, p["pos"]))
		mm.set_instance_color(i, p["color"])

func update_multimesh2():
	var mm := renderer.multimesh
	var count = particles.size()
	var transforms = []
	var colors = []
	
	# Create arrays for batch updating
	for i in count:
		var p = particles[i]
		transforms.append(Transform2D(0, Vector2(1, 1), 0, p["pos"]))
		colors.append(p["color"])
	
	# Batch update the multimesh
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform_2d(i, transforms[i])
		mm.set_instance_color(i, colors[i])

func get_cell_index(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / CELL_SIZE), floor(pos.y / CELL_SIZE))

func update_spatial_hash():
	spatial_hash.clear()
	for i in particles.size():
		var cell = get_cell_index(particles[i]["pos"])
		if not spatial_hash.has(cell):
			spatial_hash[cell] = []
		spatial_hash[cell].append(i)

# Comment out the _draw function to improve performance
# Only uncomment for debugging
func _draw():
	draw_circle(BOUNDS_CENTER + Vector2(8, 8), BOUNDS_RADIUS, Color.DARK_GRAY)
	for cell in spatial_hash.keys():
		var top_left = cell * CELL_SIZE
		draw_rect(Rect2(top_left, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.2, 0.8, 1.0, 0.2), false, 1.0)



func pack_particles():

	# Create a PackedFloat32Array for the particle buffer
	packed_particle_data = PackedFloat32Array()
	for p in particles:
		# Pack 3 vec4s per particle:
		# [0-3]   = pos.xy, last_pos.xy
		# [4-7]   = accel.xy, radius, unused
		# [8-11]  = color.rgba

		packed_particle_data.push_back(p["pos"].x)
		packed_particle_data.push_back(p["pos"].y)
		packed_particle_data.push_back(p["last_pos"].x)
		packed_particle_data.push_back(p["last_pos"].y)

		packed_particle_data.push_back(p["accel"].x)
		packed_particle_data.push_back(p["accel"].y)
		packed_particle_data.push_back(p["radius"])
		packed_particle_data.push_back(0.0) # padding or future use

		packed_particle_data.push_back(p["color"].r)
		packed_particle_data.push_back(p["color"].g)
		packed_particle_data.push_back(p["color"].b)
		packed_particle_data.push_back(p["color"].a)
		#packed_particle_data.push_back(8)


	pass
