class_name Network extends Node
#pass multiplayer signals through this node.
signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const MAX_PEERS: int = 2 # max number of clients that can connect to the server (including the host)

var is_singleplayer: bool = false # is this a singleplayer session?

# the peer of this instance.
var peer: ENetMultiplayerPeer = null
# is this instance the server?
var is_server: bool = false
var reject_new_clients: bool = false

var player_name: String = "" # the name of the local player, set when hosting or joining a game.
var host_name: String = ""
var guest_name: String = ""

# the path to the game scene to load when the game starts.
const GAME_SCENE_PATH: String = "res://scenes/game.tscn"

func reset() -> void:
	# clean up the peer and reset state
	if peer:
		peer.close()
	peer = null
	player_name = ""
	host_name = ""
	guest_name = ""
	is_server = false
	reject_new_clients = false
	multiplayer.multiplayer_peer = null

# forcibly disconnect a client from the server. Only the server can call this function.
func disconnect_client(peer_id: int, force: bool = true) -> void:
	if not is_server or peer == null:
		return
	peer.disconnect_peer(peer_id, force)

# change whether the server will reject new clients. Disconnects existing clients if disconnect_existing is true.
func set_reject_new_clients(reject: bool, disconnect_existing: bool = false) -> void:
	if not is_server or peer == null:
		return
	reject_new_clients = reject
	if disconnect_existing:
		for id in multiplayer.get_peers():
			peer.disconnect_peer(id, true)

# verify that a port number is valid (0-65535)
func verify_port(port: int) -> bool:
	return port >= 0 and port <= 65535

func _ready() -> void:
	_bind_multiplayer_signals()

# connect all multiplayer signals to the passthrough signals.
func _bind_multiplayer_signals() -> void:
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

#called when the player chooses host from the menu.
func host(port: int, plr_name: String) -> int:
	_bind_multiplayer_signals()
	is_server = true # this is the server instance
	peer = ENetMultiplayerPeer.new() #setup peer
	player_name = plr_name
	host_name = plr_name
	if not verify_port(port): # check that port is valid
		print("Invalid port number: %d" % [port])
		return ERR_INVALID_PARAMETER
	# create the server and start listening
	var err_code = peer.create_server(port)
	if err_code == OK:
		multiplayer.multiplayer_peer = peer
		print("Server listening on port %d" % [port])
	else:
		print("Failed to create server: %s" % [err_code])
	return err_code

#called when the player chooses join from the menu.
func join(ip: String, port: int, plr_name: String) -> int:
	_bind_multiplayer_signals()
	is_server = false # this is a client instance
	peer = ENetMultiplayerPeer.new() #setup peer
	player_name = plr_name
	guest_name = plr_name
	if not verify_port(port): # check that port is valid
		print("Invalid port number: %d" % [port])
		return ERR_INVALID_PARAMETER
	# connect to the server
	var err_code = peer.create_client(ip, port)
	if err_code == OK:
		multiplayer.multiplayer_peer = peer
		print("Connected to server at %s:%d" % [ip, port])
	else:
		print("Failed to connect to server: %s" % [err_code])
	return err_code

func _on_connected_to_server() -> void:
	emit_signal("connected_to_server")
	send_name_to_server(player_name) # send the player's name to the server after connecting

func _on_connection_failed() -> void:
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	emit_signal("server_disconnected")

func _on_peer_connected(id: int) -> void:
	if is_server and reject_new_clients and peer:
		peer.disconnect_peer(id, true)
		return
	emit_signal("peer_connected", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("peer_disconnected", id)
	guest_name = "" # reset guest name when a peer disconnects

func send_name_to_server(name: String) -> void:
	if is_server:
		return
	rpc_id(1, "_receive_name_from_client", name)

@rpc("any_peer","reliable", "call_local")
func _receive_name_from_client(name: String) -> void:
	if not is_server:
		return
	guest_name = name
	print("Received player name from client: %s" % [name])
	rpc("broadcast_names", host_name, guest_name)

@rpc("any_peer","reliable", "call_local")
func broadcast_names(host: String, guest: String) -> void:
	print("Broadcasting names - Host: %s, Guest: %s" % [host, guest])
	host_name = host
	guest_name = guest

func start_game() -> void:
	rpc("load_game_scene")

@rpc("authority", "call_local", "reliable")
func load_game_scene() -> void:
	var game_scene = preload(GAME_SCENE_PATH)
	var game = game_scene.instantiate()
	var current_scene = get_tree().current_scene
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	if current_scene:
		current_scene.queue_free()
	
func sync_ball_info(position: Vector2, linear_velocity: Vector2, rotation: float, ball_speed: float) -> void:
	rpc("update_ball_info", position, linear_velocity, rotation, ball_speed)

@rpc("authority","unreliable", "call_local")
func update_ball_info(position: Vector2, linear_velocity: Vector2, rotation: float, ball_speed: float) -> void:
	var game_scene = get_tree().current_scene
	if game_scene and game_scene.name == "game":
		var ball = game_scene.get_node_or_null("Ball")
		if ball:
			ball.position = position
			ball.linear_velocity = linear_velocity
			ball.rotation = rotation
			ball.ball_speed = ball_speed