extends Node
class_name NetworkServer

var network_update_time := 0.0
var world_state := {}
var player_states := {}


func process_client_update_requests(delta: float) -> void:
	network_update_time += delta * 1000
	if network_update_time >= Constants.SERVER_TICK_RATE_MS:
		network_update_time -= Constants.SERVER_TICK_RATE_MS
		
		world_state = {}
		
		if !player_states.empty():
			world_state = player_states.duplicate(true)
			
			for player_id in world_state.keys():
				world_state[player_id].erase(Constants.Network.TIME) # Remove timestamp from returned data
				
		if !world_state.empty():
			world_state[Constants.Network.TIME] = OS.get_system_time_msecs()
			GameServer.broadcast_world_state(world_state)


func update_player_state(new_player_state: Dictionary) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	
	if player_states.has(sender_id):
		if player_states[sender_id][Constants.Network.TIME] < new_player_state[Constants.Network.TIME]:
			player_states[sender_id] = new_player_state
	else:
		player_states[sender_id] = new_player_state
