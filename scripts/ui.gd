extends Control

@onready var player1_score_label: Label = $Player1Score
@onready var player2_score_label: Label = $Player2Score
@onready var player1_name_label: Label = $Player1Name
@onready var player2_name_label: Label = $Player2Name
@onready var start_timer_label: Label = $StartTimer
func tick_start_timer(val: int) -> void:
	start_timer_label.text = str(val)
	if val <= 0:
		start_timer_label.visible = false
	else:
		start_timer_label.visible = true

func set_player_names(name1: String, name2: String) -> void:
	player1_name_label.text = name1
	player2_name_label.text = name2

func update_scores(score1: int, score2: int) -> void:
	player1_score_label.text = str(score1)
	player2_score_label.text = str(score2)