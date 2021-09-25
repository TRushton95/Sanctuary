extends Node

var unit_scene = load("res://Gameplay/Entities/Unit.tscn")

const LAG_SIM_DURATION = 2.0

var player_name
var network_update_time := 0.0
var player_states := {}
var world_state := {}
var world_state_buffer := []
var prev_world_state_timestamp := 0
var request_id := 0
var request_history := []


func _on_ServerClock_ping_updated(ping: int) -> void:
	$CanvasLayer/NetworkInfo/VBoxContainer/Ping.text = "Ping: " + str(ping) + "ms"


func _on_LagSimTimer_timeout() -> void:
	GameServer.set_lag_simulation(false)
	$CanvasLayer/NetworkInfo/VBoxContainer/LagSimWarning.hide()


func _on_Unit_path_expired() -> void:
	$PathDebug.clear_points()


func _ready() -> void:
	player_name = ServerInfo.get_username(get_tree().get_network_unique_id())
	get_node("Unit").name = player_name
	get_node(player_name).set_network_master(get_tree().get_network_unique_id())
	GameServer.setup(self)
	ServerClock.setup()
	ServerClock.connect("ping_updated", self, "_on_ServerClock_ping_updated")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("LagSim"):
		GameServer.set_lag_simulation(true)
		$LagSimTimer.start(LAG_SIM_DURATION)
		$CanvasLayer/NetworkInfo/VBoxContainer/LagSimWarning.show()


func _physics_process(delta: float) -> void:
	_send_player_update()
		
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
				
				var username = ServerInfo.get_username(key)
				var new_position = lerp(world_state_buffer[1][key][Constants.Network.POSITION], world_state_buffer[2][key][Constants.Network.POSITION], interpolation_factor)
				
				if has_node(username):
					get_node(username).position = new_position
				else:
					_create_player(key, username, new_position)
					
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
					_create_player(key, username, new_position)


func _unhandled_input(event) -> void:
	if !event is InputEventMouseButton:
		return
		
	if event.button_index == BUTTON_RIGHT && event.pressed:
		var player = get_node(player_name)
		var path = $Navigation2D.get_simple_path(player.position, event.position)
		$PathDebug.clear_points()
		for point in path:
			$PathDebug.add_point(point)
					
		path.remove(0) # Remove starting point
		player._path = path


func _create_player(user_id: int, username: String, position: Vector2):
	var new_unit = unit_scene.instance()
	new_unit.position = position
	new_unit.name = username
	add_child(new_unit)
	new_unit.set_network_master(user_id)


func _send_player_update() -> void:
	var player = get_node(player_name)
	
	if player.is_network_master():
		var player_state = {
			Constants.Network.TIME: OS.get_system_time_msecs(),
			Constants.Network.POSITION: player.get_global_position(),
			Constants.Network.REQUEST_ID: request_id
		}
		
		GameServer.send_player_state(player_state)
		request_history.append(player_state)
		
		request_id += 1


func _process_client_update_requests(delta: float) -> void:
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


master func receive_player_state(new_player_state: Dictionary) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	
	if player_states.has(sender_id):
		if player_states[sender_id][Constants.Network.TIME] < new_player_state[Constants.Network.TIME]:
			player_states[sender_id] = new_player_state
	else:
		player_states[sender_id] = new_player_state


remotesync func receive_world_state(world_state: Dictionary) -> void:
	if world_state[Constants.Network.TIME] > prev_world_state_timestamp:
		prev_world_state_timestamp = world_state[Constants.Network.TIME]
		world_state_buffer.append(world_state)
		
		var player_id = get_tree().get_network_unique_id()
		var player_state = world_state[player_id]
		
		var oudated_requests = []
		for request in request_history:
			if request[Constants.Network.REQUEST_ID] < player_state[Constants.Network.REQUEST_ID]:
				oudated_requests.append(request)
				
		# Remove oudated requests
		for request in oudated_requests:
			request_history.erase(request)
			
		# Replay client-side prediction based on most recent available server data
		if request_history.size() >= 2 && request_history[0][Constants.Network.REQUEST_ID] == player_state[Constants.Network.REQUEST_ID]:
			print("Replaying from request " + str(request_history[0][Constants.Network.REQUEST_ID]))
			
			var player_name = ServerInfo.get_username(player_id)
			var player = get_node(player_name)
			
			# TODO: Instead of applying a delta change from each request, having to calculate delta between two states - not very tidy
			player.position = player_state[Constants.Network.POSITION]
			for i in range(0, request_history.size() - 1):
				var delta_pos = request_history[i + 1][Constants.Network.POSITION] - request_history[i][Constants.Network.POSITION]
				player.position += delta_pos
			
