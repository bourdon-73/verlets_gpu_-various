extends CharacterBody2D
class_name kines

@export var damping : float = 0.95  # Damping factor to simulate friction
@export var max_speed : float = 400.0  # Maximum speed of movement
@export var bounce_factor : float = 0.7  # Controls how bouncy the collisions are (0-1)
@export var gravity_strength : float = 980.0  # Gravity strength (pixels/sec²)

var gravity_vec : Vector2 = Vector2(0, 1)  # Gravity direction (downward)

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Initialize with zero velocity
	velocity = Vector2.ZERO

# Called every frame. Used for updating logic.
func _process(delta: float) -> void:
	# Apply gravity
	var force = gravity_vec * gravity_strength
	
	# Add some air resistance/damping
	force -= velocity * damping * 0.1
	
	# Apply forces to the velocity
	velocity += force * delta
	
	# Handle movement and collisions
	move_and_slide()
	
	# Apply bounce effect if there was a collision
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision_info = get_slide_collision(i)
			var normal = collision_info.get_normal()
			
			# Reflect the velocity based on the collision normal and apply bounce factor
			velocity = velocity.bounce(normal) * bounce_factor
