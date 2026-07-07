extends Node2D

@onready var viewport_size = get_viewport_rect().size
const GRAVITY = Vector2(0, 500)
const SUBSTEPS = 4  # Reduced from 8 to 4
const BOUNDS_RADIUS = 100.0
const BOUNDS_CENTER = Vector2(400, 300)
@export var renderer : MultiMeshInstance2D 

# FPS monitoring variables
const TARGET_FPS = 30
var current_fps = 60
var fps_counter = 0
var fps_timer = 0
var can_spawn = true
var particles_per_click = 2
var warmup_frames = 3
var max_particles = 10000

# Spatial hash optimization
const CELL_SIZE = 25.0  # Increased cell size slightly
var spatial_hash = {}
var checked_pairs = {}  # Made this a class variable to avoid recreation
var particles: Array = []

func create_verlet_obj(pos: Vector2, radius := 1.0, color := Color.WHITE) -> Dictionary:
	return {
		"pos": pos,
		"last_pos": pos,
		"accel": Vector2.ZERO,
		"radius": radius,
		"color": color,
	}


func spawn_particles_at_mouse():
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
		particles.append(create_verlet_obj(pos, 5.0, color))
	
	# Only update instance count when necessary
	if renderer and renderer.multimesh.instance_count < particles.size():
		renderer.multimesh.instance_count = particles.size()

func _ready():
	# Pre-allocate the multimesh with maximum capacity
	if renderer:
		renderer.multimesh.instance_count = max_particles
	
	# For tracking performance
	fps_timer = 0
	fps_counter = 0

func _input(event: InputEvent) -> void:
	# Simplified input handling
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		spawn_particles_at_mouse()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		spawn_particles_at_mouse()

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
			#print("STOPPED SPAWNING - Final particle count: ", particles.size(), " - FPS: ", current_fps)
		#
		#print("FPS: ", current_fps, " Particles: ", particles.size())

func _physics_process(delta):
	if particles.size() == 0:
		return
	
	var dt = delta / SUBSTEPS
	for i in SUBSTEPS:
		simulate(dt)

func simulate(dt):
	# Apply gravity once
	for p in particles:
		p["accel"] += GRAVITY
	
	# Update positions
	for p in particles:
		var temp = p["pos"]
		p["pos"] += (p["pos"] - p["last_pos"]) + p["accel"] * dt * dt
		p["last_pos"] = temp
		p["accel"] = Vector2.ZERO
	
	# Only update spatial hash and check collisions if we have enough particles
	if particles.size() > 1:
		update_spatial_hash()
		check_collisions()
	
	enforce_boundary()
	update_multimesh()

func check_collisions():
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
		var to_center = p["pos"] - BOUNDS_CENTER
		var dist = to_center.length()
		if dist > BOUNDS_RADIUS - p["radius"]:
			p["pos"] = BOUNDS_CENTER + to_center.normalized() * (BOUNDS_RADIUS - p["radius"])

func update_multimesh():
	var mm := renderer.multimesh
	var count = particles.size()
	
	# Only update what we need to
	for i in count:
		var p = particles[i]
		mm.set_instance_transform_2d(i, Transform2D(0, Vector2(10, 10), 0, p["pos"]))
		mm.set_instance_color(i, p["color"])

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
	draw_circle(BOUNDS_CENTER, BOUNDS_RADIUS, Color.DARK_GRAY)
	#for cell in spatial_hash.keys():
		#var top_left = cell * CELL_SIZE
		#draw_rect(Rect2(top_left, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.2, 0.8, 1.0, 0.2), false, 1.0)
