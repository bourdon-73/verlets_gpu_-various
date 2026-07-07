class_name VerletObj

var pos: Vector2
var last_pos: Vector2
var accel: Vector2
var radius: float = 5.0
var color: Color = Color.WHITE

func _init(p: Vector2, r: float = 5.0, c: Color = Color.WHITE):
	pos = p
	last_pos = p
	accel = Vector2.ZERO
	radius = r
	color = c

func apply_gravity(gravity: Vector2):
	accel += gravity

func verlet(dt: float):
	var temp = pos
	pos += (pos - last_pos) + accel * dt * dt
	last_pos = temp
	accel = Vector2.ZERO
