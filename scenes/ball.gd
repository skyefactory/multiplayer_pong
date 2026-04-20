extends RigidBody2D

@export var ball_speed: float = 500.0
@export var paddle_max_bounce_angle: float = 60.0
@export var min_wall_vertical_component: float = 0.2

func _ready() -> void:
	linear_velocity = Vector2(0, ball_speed)
	gravity_scale = 0
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	if not NetworkController.is_server:
		freeze = true
		contact_monitor = false


func _on_body_entered(body: Node) -> void:
	if not NetworkController.is_server:
		return
	if body is Player:
		print("Ball collided with player: %s" % [body.player_name])
		var hit_ratio = get_hit_ratio_player(body, global_position)
		var away_x_dir = get_away_x_dir_from_player(body)
		linear_velocity = angle_from_hit_player(ball_speed, hit_ratio, away_x_dir, paddle_max_bounce_angle)
		ball_speed *= 1.05 # increase speed by 5% on each hit
		body.find_child("HitSound").play()
	elif body.name == "UpperLimit":
		print("Ball collided with upper limit")
		linear_velocity = bounce_from_limit(true)
		
	elif body.name == "LowerLimit":
		print("Ball collided with lower limit")
		linear_velocity = bounce_from_limit(false)

func get_away_x_dir_from_player(player: Player) -> float:
	var away_x_dir = sign(global_position.x - player.global_position.x)
	if is_zero_approx(away_x_dir):
		away_x_dir = -sign(linear_velocity.x)
	if is_zero_approx(away_x_dir):
		away_x_dir = 1.0
	return away_x_dir

func bounce_from_limit(is_upper: bool) -> Vector2:
	var fallback_y = 1.0 if is_upper else -1.0
	var dir = linear_velocity.normalized()
	if dir.is_zero_approx():
		dir = Vector2(1.0, fallback_y).normalized()
	else:
		dir.y = -dir.y

	if absf(dir.y) < min_wall_vertical_component:
		dir.y = fallback_y * min_wall_vertical_component

	return dir.normalized() * ball_speed

func angle_from_hit_player(speed: float, hit_ratio: float, away_x_dir: float, max_angle_deg: float) -> Vector2:
	var angle = deg_to_rad(hit_ratio * max_angle_deg)
	var dir = Vector2(away_x_dir, 0.0).rotated(angle).normalized()
	return dir * speed


func get_hit_ratio_player(character: Player, hit_world_pos: Vector2) -> float:
	var collider: CollisionShape2D = character.get_node("CollisionShape2D")
	if collider and collider.shape:
		var half_height = shape_half_height(collider.shape)
		if half_height <= 0.0001:
			return 0.0
		var local_hit_pos = collider.to_local(hit_world_pos)
		return clamp(local_hit_pos.y / half_height, -1.0, 1.0)
	return 0.0
	
func shape_half_height(shape: Shape2D) -> float:
	if shape is RectangleShape2D:
		return shape.size.y * 0.5
	return 1.0

func _physics_process(delta: float) -> void:
	if not NetworkController.is_server:
		return
	NetworkController.sync_ball_info(global_position, linear_velocity, rotation, ball_speed)