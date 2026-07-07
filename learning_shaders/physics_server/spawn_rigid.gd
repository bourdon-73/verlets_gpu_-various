extends Node2D

@onready var rd_inst = preload("res://physics_server/rigid_Object.tscn")
var count :int= 1000

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(count): 
		var rd = RigidObject.new()
		var inst :RigidObject = rd_inst.instantiate()
		add_child(inst)
		
		  #inst.create_rigid_object(Vector2(randf_range(100, -400),randf_range(-100, -500)), get_world_2d())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
