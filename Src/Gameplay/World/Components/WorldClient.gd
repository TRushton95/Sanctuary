extends Node
class_name WorldClient

const unit_scene = preload("res://Gameplay/Entities/Unit/Unit.tscn")

var world
var request_id := 0
var request_history := []
var world_state_buffer := []
var prev_world_state_timestamp := 0


func _init(world) -> void:
	self.world = world


func send_player_update(player: Unit) -> void:
	if player.is_network_master():
		var player_state = {
			Constants.Network.TIME: OS.get_system_time_msecs(),
			Constants.Network.POSITION: player.get_global_position(),
			Constants.Network.REQUEST_ID: request_id
		}
		
		GameServer.send_player_state(player_state)
		
		var request_state = {
			#Constants.Network.POSITION: movement_delta,
			Constants.Network.REQUEST_ID: request_id
		}
		
		request_history.append(request_state)
		
		request_id += 1


func update_world_state(world_state: Dictionary, player: Unit) -> void:
	if world_state[Constants.Network.TIME] > prev_world_state_timestamp:
		prev_world_state_timestamp = world_state[Constants.Network.TIME]
		world_state_buffer.append(world_state)
		
		var player_id = get_tree().get_network_unique_id()
		var player_state = world_state[player_id]
		
		var oudated_requests = []
		for request in request_history:
			if request[Constants.Network.REQUEST_ID] <= player_state[Constants.Network.REQUEST_ID]: # Equal because we don't want to rollback through the already server-confirmed request
				oudated_requests.append(request)
				
		# Remove oudated requests
		for request in oudated_requests:
			request_history.erase(request)
			
		player.position = player_state[Constants.Network.POSITION]
		
		# Replay client-side prediction based on most recent available server data
		# TODO possible bug as packets order most likely not guarunteed?
		if request_history.size() > 0:
			print("Replaying from request " + str(request_history[0][Constants.Network.REQUEST_ID]))
			for i in range(0, request_history.size()):
				player.position += request_history[i][Constants.Network.POSITION] # TODO perhaps create new constant for this to make it clear its not position, but position delta


func process_world_state() -> void:
	var render_time = ServerClock.get_time() - Constants.INTERPOLATION_OFFSET_MS # The game time that we are rendering locally
	if world_state_buffer.size() > 1:
		while world_state_buffer.size() > 2 && world_state_buffer[2][Constants.Network.TIME] < render_time:
			world_state_buffer.remove(0)
			
		if world_state_buffer.size() > 2: # We have a future state to interpolate with
			var interpolation_factor = float(render_time - world_state_buffer[1][Constants.Network.TIME]) / float(world_state_buffer[2][Constants.Network.TIME] - world_state_buffer[1][Constants.Network.TIME])
			
			for key in world_state_buffer[2].keys():
				if str(key) == Constants.Network.TIME:
					continue
				if key == get_tree().get_network_unique_id():
					continue
				if !world_state_buffer[1].has(key):
					continue
				
				var username = ServerInfo.get_username(key)
				var new_position = lerp(world_state_buffer[1][key][Constants.Network.POSITION], world_state_buffer[2][key][Constants.Network.POSITION], interpolation_factor)
				
				if has_node(username):
					get_node(username).position = new_position
				else:
					world.create_player(key, username, new_position)
					
		elif render_time > world_state_buffer[1][Constants.Network.TIME]:
			var extrapolation_factor = float(render_time - world_state_buffer[0][Constants.Network.TIME]) / float(world_state_buffer[1][Constants.Network.TIME] - world_state_buffer[0][Constants.Network.TIME]) - 1.0
			
			for key in world_state_buffer[1].keys():
				if str(key) == Constants.Network.TIME:
					continue
				if key == get_tree().get_network_unique_id():
					continue
				if !world_state_buffer[1].has(key):
					continue
					
				var username = ServerInfo.get_username(key)
				var delta_position = world_state_buffer[1][key][Constants.Network.POSITION] - world_state_buffer[0][key][Constants.Network.POSITION]
				var new_position = world_state_buffer[1][key][Constants.Network.POSITION] + (delta_position * extrapolation_factor)
					
				if has_node(username):
					get_node(username).position = new_position
				else:
					world.create_player(key, username, new_position)
