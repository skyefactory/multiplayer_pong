class_name MainMenu extends Control

@onready var bg: ColorRect = $BG
#Menu Controls
@onready var menu_buttons: VBoxContainer = $MenuButtons
@onready var host_btn: Button = $MenuButtons/HostBtn
@onready var join_btn: Button = $MenuButtons/JoinBtn
@onready var quit_btn: Button = $MenuButtons/QuitBtn
#Stats
@onready var stats_panel: VBoxContainer = $Stats
@onready var rounds_played_label: Label = $Stats/RoundsPlayedLbl
@onready var rounds_won_label: Label = $Stats/RoundsWonLbl
@onready var rounds_lost_label: Label = $Stats/RoundsLostLbl
@onready var winrate_label: Label = $Stats/WinrateLbl
@onready var best_streak_label: Label = $Stats/WinstreakLbl

@onready var join_menu: VBoxContainer = $JoinMenu
@onready var join_ip: LineEdit = $JoinMenu/IpEntry
@onready var join_name: LineEdit = $JoinMenu/NameEntry
@onready var submit_join_btn: Button = $JoinMenu/SubmitJoinBtn
@onready var back_btn: Button = $JoinMenu/BackBtn
@onready var port_entry: LineEdit = $JoinMenu/PortEntry

@onready var host_menu: VBoxContainer = $HostMenu
@onready var host_port: LineEdit = $HostMenu/PortEntry
@onready var host_name: LineEdit = $HostMenu/NameEntry
@onready var submit_host_btn: Button = $HostMenu/SubmitHostBtn
@onready var host_back_btn: Button = $HostMenu/BackBtn

@onready var lobby: ColorRect = $Lobby
@onready var player1_label: Label = $Lobby/Player1Lbl
@onready var player2_label: Label = $Lobby/Player2Lbl
@onready var lobby_start_btn: Button = $Lobby/StartGameBtn

@export var game_scene: PackedScene

var clients: int = 0

func populate_stats():
	rounds_played_label.text = "Rounds Played: " + str(Gamestate.total_rounds_played)
	rounds_won_label.text = "Rounds Won: " + str(Gamestate.total_rounds_won)
	rounds_lost_label.text = "Rounds Lost: " + str(Gamestate.total_rounds_lost)
	winrate_label.text = "Winrate: " + str(Gamestate.total_winrate) + "%"
	best_streak_label.text = "Best Win Streak: " + str(Gamestate.best_win_streak)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	submit_join_btn.pressed.connect(_on_submit_join_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	submit_host_btn.pressed.connect(_on_submit_host_pressed)
	host_back_btn.pressed.connect(_on_host_back_pressed)
	lobby_start_btn.pressed.connect(_on_lobby_start_pressed)
	populate_stats()

func _on_host_pressed():
	Gamestate.current_state = Gamestate.State.MENU_HOST

func _on_join_pressed():
	Gamestate.current_state = Gamestate.State.MENU_JOIN

func _on_quit_pressed():
	get_tree().quit()

func _on_lobby_start_pressed():
	NetworkController.reject_new_clients = true
	Gamestate.current_state = Gamestate.State.IN_GAME
	NetworkController.start_game()

func _on_submit_join_pressed():
	var ip = join_ip.text.strip_edges()
	var name = join_name.text.strip_edges()
	var port_text = port_entry.text.strip_edges()
	var port_good = NetworkController.verify_port(int(port_text))
	if ip == "" or name == "" or not port_good:
		return
	var port = int(port_text)
	var status = NetworkController.join(ip, port, name)
	if status == OK:
		Gamestate.current_state = Gamestate.State.LOBBY
	else:
		print("Failed to join server: %s" % [status])
		Gamestate.current_state = Gamestate.State.MAIN_MENU
		NetworkController.reset()

	pass

func _on_back_pressed():
	Gamestate.current_state = Gamestate.State.MAIN_MENU

func _on_host_back_pressed():
	Gamestate.current_state = Gamestate.State.MAIN_MENU

func _on_submit_host_pressed():
	var port_text = host_port.text.strip_edges()
	var port_good = NetworkController.verify_port(int(port_text))
	if not port_good:
		return
	var port = int(port_text)
	var name = host_name.text.strip_edges()
	if name == "":
		return
	var status = NetworkController.host(port, name)
	if status == OK:
		Gamestate.current_state = Gamestate.State.LOBBY
	else:
		print("Failed to host server: %s" % [status])
		Gamestate.current_state = Gamestate.State.MAIN_MENU
		NetworkController.reset()

func _process(delta: float) -> void:
	clients = multiplayer.get_peers().size() + 1
	match Gamestate.current_state:
		Gamestate.State.MENU_HOST:
			stats_panel.visible = false
			menu_buttons.visible = false
			join_menu.visible = false
			host_menu.visible = true
			lobby.visible = false
		Gamestate.State.MENU_JOIN:
			stats_panel.visible = false
			menu_buttons.visible = false
			join_menu.visible = true
			host_menu.visible = false
			lobby.visible = false
		Gamestate.State.MAIN_MENU:
			stats_panel.visible = true
			menu_buttons.visible = true
			join_menu.visible = false
			host_menu.visible = false
			lobby.visible = false

		Gamestate.State.LOBBY:
			stats_panel.visible = false
			menu_buttons.visible = false
			join_menu.visible = false
			host_menu.visible = false
			lobby.visible = true
			player1_label.text = "Player 1 (host): " + NetworkController.host_name
			player2_label.text = "Player 2: " + NetworkController.guest_name if NetworkController.guest_name != "" else "Waiting for Player"
			if NetworkController.is_server:
				lobby_start_btn.visible = true
				if clients == 1:
					lobby_start_btn.disabled = true
				else:
					lobby_start_btn.disabled = false
			else:
				lobby_start_btn.visible = false

func _on_server_disconnected():
	print("Disconnected from server.")
	Gamestate.current_state = Gamestate.State.MAIN_MENU
	NetworkController.reset()

func _on_peer_connected(id: int) -> void:
	print("Peer connected with id: %d" % [id])
	clients += 1

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected with id: %d" % [id])
	clients -= 1

#connect all the signals from network.gd 
func bind_network_signals() -> void:
	if not NetworkController.server_disconnected.is_connected(_on_server_disconnected):
		NetworkController.server_disconnected.connect(_on_server_disconnected)
	if not NetworkController.peer_connected.is_connected(_on_peer_connected):
		NetworkController.peer_connected.connect(_on_peer_connected)
	if not NetworkController.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkController.peer_disconnected.connect(_on_peer_disconnected)
		
#disconnect all the signals from network.gd
func unbind_network_signals() -> void:
	if NetworkController.server_disconnected.is_connected(_on_server_disconnected):
		NetworkController.server_disconnected.disconnect(_on_server_disconnected)
	if NetworkController.peer_connected.is_connected(_on_peer_connected):
		NetworkController.peer_connected.disconnect(_on_peer_connected)
	if NetworkController.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkController.peer_disconnected.disconnect(_on_peer_disconnected)
