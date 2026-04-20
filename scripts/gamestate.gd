class_name GameState extends Node

@export var total_rounds_played: int = 0
var total_rounds_won: int = 0
var total_rounds_lost: int = 0
var total_winrate: float = 0.0
var best_win_streak: int = 0

enum State{
	MAIN_MENU,
	MENU_HOST,
	MENU_JOIN,
	LOBBY,
	IN_GAME,
	ROUND_OVER,
}

var current_state: State = State.MAIN_MENU

func load_game():
	var file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if file:
		total_rounds_played = file.get_var()
		total_rounds_won = file.get_var()
		total_rounds_lost = file.get_var()
		total_winrate = file.get_var()
		best_win_streak = file.get_var()
		file.close()
	else:
		total_rounds_played = 0
		total_rounds_won = 0
		total_rounds_lost = 0
		total_winrate = 0.0
		best_win_streak = 0
		print("No save file found. Starting with default game state.")
		save_game()

func save_game():
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_var(total_rounds_played)
		file.store_var(total_rounds_won)
		file.store_var(total_rounds_lost)
		file.store_var(total_winrate)
		file.store_var(best_win_streak)
		file.close()
	else:
		print("Failed to save game state.")

func _ready() -> void:
	load_game()