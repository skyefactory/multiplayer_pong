extends Node2D

const SCORE_SFX: AudioStream = preload("res://score.mp3")

var player1_score: int = 0
var player2_score: int = 0

@onready var ui: Control = $UI
@onready var ball_spawn: Node2D = $BallSpawn
@export var ball_scene: PackedScene

var time_to_start: int = 3
var start_time: int = 3
var accumulated_time: float = 0.0
var game_started: bool = false

var players: Array = []

func _ready() -> void:
	ui.set_player_names(NetworkController.host_name, NetworkController.guest_name)
	if NetworkController.is_server:
		sync_scores.rpc(player1_score, player2_score)
		sync_round_state.rpc(start_time, game_started)
	find_child("Tick").play()

func _process(delta: float) -> void:
	players = find_children("*", "Player", true, false)
	_update_player_movement_state()
	if not NetworkController.is_server:
		return

	if game_started:
		return

	accumulated_time += delta
	if accumulated_time < 1.0:
		return

	accumulated_time = 0.0
	start_time -= 1
	find_child("Tick").play()
	ui.tick_start_timer(start_time)
	if start_time <= 0:
		game_started = true
		spawn_ball()
	sync_round_state.rpc(start_time, game_started)

func _update_player_movement_state() -> void:
	for player in players:
		player.can_move = game_started

func _on_player_2_goal_body_entered(body: Node2D) -> void:
	if not NetworkController.is_server:
		return
	if body.name == "Ball":
		player1_score += 1
		play_score_sfx_rpc.rpc()
		sync_scores.rpc(player1_score, player2_score)
		despawn_ball_rpc.rpc()
		reset_ball()

	
func _on_player_1_goal_body_entered(body: Node2D) -> void:
	if not NetworkController.is_server:
		return
	if body.name == "Ball":
		player2_score += 1
		play_score_sfx_rpc.rpc()
		sync_scores.rpc(player1_score, player2_score)
		despawn_ball_rpc.rpc()
		reset_ball()

@rpc("authority", "call_local", "reliable")
func play_score_sfx_rpc() -> void:
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = SCORE_SFX
	add_child(sfx_player)
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()


func spawn_ball() -> void:
	if not NetworkController.is_server:
		return
	spawn_ball_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func spawn_ball_rpc() -> void:
	if get_node_or_null("Ball"):
		return
	var ball_instance = ball_scene.instantiate() as Node2D
	ball_instance.position = ball_spawn.position
	add_child(ball_instance)

@rpc("authority", "call_local", "reliable")
func despawn_ball_rpc() -> void:
	var ball = get_node_or_null("Ball")
	if ball:
		ball.queue_free()

@rpc("authority", "call_local", "reliable")
func sync_scores(score1: int, score2: int) -> void:
	player1_score = score1
	player2_score = score2
	ui.update_scores(player1_score, player2_score)

@rpc("authority", "call_local", "reliable")
func sync_round_state(timer_value: int, started: bool) -> void:
	start_time = timer_value
	game_started = started
	ui.tick_start_timer(start_time)

func reset_ball() -> void:
	game_started = false
	start_time = time_to_start
	accumulated_time = 0.0
	ui.tick_start_timer(start_time)
	sync_round_state.rpc(start_time, game_started)