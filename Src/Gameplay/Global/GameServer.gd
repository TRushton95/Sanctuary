extends Node

var _game_world : Node
var _simulating_lag := false


func setup(world: Node) -> void:
	_game_world = world


func set_lag_simulation(enabled: bool) -> void:
	_simulating_lag = enabled


###################
#  CLIENT METHODS #
###################

func send_player_input(player_input: Dictionary) -> void:
	if !_simulating_lag:
		_game_world.rpc_unreliable_id(Constants.SERVER_ID, "receive_player_input", player_input)


###################
#  SERVER METHODS #
###################

func broadcast_world_state(world_state: Dictionary) -> void:
	if !_simulating_lag:
		_game_world.rpc_unreliable_id(Constants.ALL_CONNECTED_PEERS_ID, "receive_world_state", world_state)
