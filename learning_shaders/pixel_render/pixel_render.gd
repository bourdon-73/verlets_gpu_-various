extends Node2D

var image: Image
var texture: ImageTexture
var sprite: Sprite2D

const WIDTH = 360
const HEIGHT = 360

func _ready():
	# Create the image
	image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)

	# Create the texture
	texture = ImageTexture.create_from_image(image)

	# Create the sprite
	sprite = Sprite2D.new()
	sprite.texture = texture
	add_child(sprite)

var time_accum = 0.0
#func _process(delta):
func _physics_process(delta: float) -> void:
	get_window().title = " / FPS: " + str(Engine.get_frames_per_second()) #+ " PARTICLES: " + str(particles.size())
#
	## Randomly change some pixels each frame
	#time_accum += delta
	#if time_accum >= 1.0:  # every 1 second
		#time_accum = 0.0
	#for i in range(1000):
		#var x = randi() % WIDTH
		#var y = randi() % HEIGHT
		#image.set_pixel(x, y, Color.RED)
	#texture.update(image)
