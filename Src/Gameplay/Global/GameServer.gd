extends Node

var game_world


func setup(world: Node) -> void:
	game_world = world


###################
#  CLIENT METHODS #
###################

func send_player_state(player_state: Dictionary) -> void:
	game_world.rpc_unreliable_id(Constants.SERVER_ID, "recieve_player_state", player_state)


###################
#  SERVER METHODS #
###################

func broadcast_world_state(world_state: Dictionary) -> void:
	game_world.rpc_unreliable_id(Constants.ALL_CONNECTED_PEERS_ID, "receive_world_state", world_state)
