extends Resource

class_name VerletObject

# Object properties
var current_position: Vector2
var old_position: Vector2
var acceleration: Vector2
var radius: float = 10.0
var color: Color = Color.WHITE
var is_pinned: bool = false
var pin_position: Vector2

# Physics properties
var bounciness: float = 0.7          # Restitution coefficient (0-1)
var friction: float = 0.99           # Friction coefficient

# Simulation constants
var gravity: Vector2 = Vector2(0, 980)  # Gravity force (pixels/sec^2)

func _init(pos: Vector2, r: float = 10.0, col: Color = Color.WHITE, bounce: float = 0.7):
	current_position = pos
	old_position = pos
	acceleration = Vector2.ZERO
	radius = r
	color = col
	bounciness = clamp(bounce, 0.0, 1.0)

func update_position(delta: float):
	if is_pinned:
		current_position = pin_position
		return
		
	# Save current position
	var temp = current_position
	
	# Verlet integration
	var velocity = (current_position - old_position) * friction
	
	# Update position using verlet integration formula
	current_position = current_position + velocity + acceleration * delta * delta
	
	# Save previous position
	old_position = temp
	
	# Reset acceleration
	acceleration = Vector2.ZERO

func apply_force(force: Vector2):
	acceleration += force

func pin(pos: Vector2):
	is_pinned = true
	pin_position = pos

func unpin():
	is_pinned = false

func constrain_to_bounds(bounds: Rect2):
	# Get current velocity
	var velocity = current_position - old_position
	
	# Constrain to boundaries with bouncing
	if current_position.x > bounds.end.x - radius:
		current_position.x = bounds.end.x - radius
		old_position.x = current_position.x + velocity.x * bounciness  # Apply bounce
	
	if current_position.x < bounds.position.x + radius:
		current_position.x = bounds.position.x + radius
		old_position.x = current_position.x + velocity.x * bounciness  # Apply bounce
	
	if current_position.y > bounds.end.y - radius:
		current_position.y = bounds.end.y - radius
		old_position.y = current_position.y + velocity.y * bounciness  # Apply bounce
	
	if current_position.y < bounds.position.y + radius:
		current_position.y = bounds.position.y + radius
		old_position.y = current_position.y + velocity.y * bounciness  # Apply bounce

func draw(painter):
	painter.draw_circle(current_position, radius, color)


# Example main scene to use Verlet integration
