extends Node2D

@onready var rd_inst = preload("res://kinematics/character_body_2d.tscn")
@export var count :int= 1000
# Called when the node enters the scene tree for the first time.
# Spawning setup
var spawn_timer := 0.0
@export var spawn_delay := 0.25
var spawned := 0

func _process(delta: float) -> void:
	if spawned >= count:
		return

	spawn_timer += delta
	if spawn_timer >= spawn_delay:
		spawn_timer = 0.0
		var x = randf_range(-50, 50)
		var y = randf_range(-500, -100)
		var inst :kines = rd_inst.instantiate()
		add_child(inst)
		inst.global_position = Vector2(x, y)
		spawned += 1


#func _ready() -> void:
	#for i in range(count): 
		#var rd = kines.new()
		#var inst :kines = rd_inst.instantiate()
		#add_child(inst)
		#spawned += 1
		##inst.create_rigid_object(Vector2(randf_range(100, -400),randf_range(-100, -500)), get_world_2d())
	#pass # Replace with function body.
