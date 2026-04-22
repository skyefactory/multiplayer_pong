class_name PlayerSpawner extends Node
@export var player_scene: PackedScene
@export var player1_spawn: Node2D
@export var player2_spawn: Node2D

@export var player1_tex: Texture2D
@export var player2_tex: Texture2D

func _ready() -> void:
	if NetworkController.is_server:
		rpc("spawn_player", NetworkController.peer.get_unique_id(), NetworkController.player_name)
		for id in multiplayer.get_peers():
			rpc("spawn_player", id, NetworkController.guest_name)

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, player_name: String) -> void:
	var player_instance = player_scene.instantiate() as Player
	if id == 1:
		player_instance.position = player1_spawn.position
		player_instance.player_name = player_name
		player_instance.get_node("Sprite2D").texture = player1_tex
		player_instance.set_multiplayer_authority(id, true)
	else:
		player_instance.position = player2_spawn.position
		player_instance.player_name = player_name
		player_instance.get_node("Sprite2D").texture = player2_tex
		player_instance.set_multiplayer_authority(id, true)
	add_child(player_instance)
