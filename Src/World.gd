extends Node

var network_update_time := 0.0
var player_update_requests := {}
var world_state := {}
var world_state_buffer := []
var prev_world_state_timestamp := 0


func _on_Unit_path_expired() -> void:
	$PathDebug.clear_points()


func _ready() -> void:
	GameServer.setup(self)


func _physics_process(delta: float) -> void:
	if get_tree().is_network_server():
		_process_client_update_requests(delta)
				
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
				
				var username = "CLIENT_NAME" # TODO: Get username from serverlist by key (network id)
				
				if has_node(username):
					var new_position = lerp(world_state_buffer[1][key][Constants.Network.POSITION], world_state_buffer[2][key][Constants.Network.POSITION], interpolation_factor)
					get_node(username).position = new_position
				else:
					# TODO: Spawn player
					pass
					
		elif render_time > world_state_buffer[1][Constants.Network.TIME]:
			var extrapolation_factor = float(render_time - world_state_buffer[0][Constants.Network.TIME]) / float(world_state_buffer[1][Constants.Network.TIME] - world_state_buffer[0][Constants.Network.TIME]) - 1.0
			
			for key in world_state_buffer[1].keys():
				if str(key) == Constants.Network.TIME:
					continue
				if key == get_tree().get_network_unique_id():
					continue
				if !world_state_buffer[1].has(key):
					continue
					
				var username = "CLIENT_NAME" # TODO: Get username from serverlist by key (network id)
				
				if has_node(username):
					var delta_position = world_state_buffer[1][key][Constants.Network.POSITION] - world_state_buffer[0][key][Constants.Network.POSITION]
					var new_position = world_state_buffer[1][key][Constants.Network.POSITION] + (delta_position * extrapolation_factor)
					get_node(username).position = new_position
				else:
					# TODO: Spawn player
					pass


func _unhandled_input(event) -> void:
	if !event is InputEventMouseButton:
		return
		
	if event.button_index == BUTTON_RIGHT && event.pressed:
		var path = $Navigation2D.get_simple_path($Unit.position, event.position)
		$PathDebug.clear_points()
		for point in path:
			$PathDebug.add_point(point)
					
		path.remove(0) # Remove starting point
		$Unit._path = path


func _process_client_update_requests(delta: float) -> void:
	network_update_time += delta * 1000
	if network_update_time >= Constants.SERVER_TICK_RATE_MS:
		network_update_time -= Constants.SERVER_TICK_RATE_MS
		
		world_state = {}
		
		if !player_update_requests.empty():
			world_state = player_update_requests.duplicate(true)
			
			for player_id in world_state.keys():
				world_state[player_id].erase(Constants.Network.TIME) # Remove timestamp from returned data
				
		if !world_state.empty():
			world_state[Constants.Network.TIME] = OS.get_system_time_msecs()
			GameServer.broadcast_world_state(world_state)


remotesync func receive_world_state(world_state: Dictionary) -> void:
	if world_state[Constants.Network.TIME] > prev_world_state_timestamp:
		prev_world_state_timestamp = world_state[Constants.Network.TIME]
		world_state_buffer.append(world_state)
