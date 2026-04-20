class_name Player extends CharacterBody2D

#player can move up and down only

@export var move_speed: float = 50000.0

var player_name: String = ""
var can_move: bool = false

var fixed_x: float = 0.0

func _ready() -> void:
	fixed_x = global_position.x

func can_process_input() -> bool:
	return can_move and is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if can_process_input():
		if Input.is_action_pressed("move_slowdown"):
			move_speed = 20000.0
		else:
			move_speed = 50000.0
		var input_vector = Vector2.ZERO
		input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		velocity = input_vector.normalized() * move_speed * delta
		move_and_slide()
		global_position.x = fixed_x