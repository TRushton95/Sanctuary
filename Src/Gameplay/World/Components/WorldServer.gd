extends Node
class_name WorldServer

var world
var network_update_time := 0.0

var world_snapshots := {}
var player_input_buffers := {}
var latest_ackowledged_player_requests := {}


func _on_user_joined(sender_id: int) -> void:
	world.create_player(sender_id, "Client", Vector2(100, 100))


func _on_user_disconnected(username: String) -> void:
	world.remove_player(username)


func _init(world) -> void:
	self.world = world
	world.create_player(Constants.SERVER_ID, "Server", Vector2(200, 200))
	ServerInfo.connect("user_joined", self, "_on_user_joined")
	ServerInfo.connect("user_disconnected", self, "_on_user_disconnected")


func send_world_state(delta: float) -> void:
	network_update_time += delta * 1000
	if network_update_time >= Constants.SERVER_TICK_RATE_MS:
		network_update_time -= Constants.SERVER_TICK_RATE_MS
		
		var world_state = {}
		
		for user_id in ServerInfo.get_users():
			var username = ServerInfo.get_username(user_id)
			var user = world.get_player(username)
			
			if user != null:
				var request_id = -1
				if latest_ackowledged_player_requests.has(user_id):
					request_id = latest_ackowledged_player_requests[user_id]
				
				world_state[user_id] = {
					Constants.Network.POSITION: user.position,
					Constants.Network.TIME: ServerClock.get_time(),
					Constants.Network.REQUEST_ID: request_id
				}
				
				if user.is_casting:
					world_state[user_id][Constants.Network.CASTING] = user.get_cast_progress()
			
		if !world_state.empty():
			world_state[Constants.Network.TIME] = ServerClock.get_time()
			GameServer.broadcast_world_state(world_state)


func buffer_player_input(player_input: Dictionary) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	player_input_buffers[sender_id] = player_input # Possible bug here if we attempt to queue multiple inputs


# TODO: Going to process inputs directly for now, though this _might_ need to implement server rollback later
# TODO: Change input variable name here, its misleading as this is a server packet that contains input data - makes you think request_id wouldn't be on it
func process_player_input_buffer() -> void:
	for player_id in player_input_buffers.keys():
		var input = player_input_buffers[player_id]
		var username = ServerInfo.get_username(player_id)
		
		var player = world.get_player(username)
		if player != null:
			execute_input(player, input)
					
			if !latest_ackowledged_player_requests.has(player_id) || latest_ackowledged_player_requests[player_id] < input[Constants.ClientInput.REQUEST_ID]:
				latest_ackowledged_player_requests[player_id] = input[Constants.ClientInput.REQUEST_ID]
			
	player_input_buffers.clear()


func execute_input(unit: Unit, input: Dictionary) -> void:
	unit.position += input[Constants.ClientInput.MOVEMENT]
		
	# Cancel casting if moving
	if input[Constants.ClientInput.MOVEMENT] != Vector2.ZERO && unit.is_casting:
		unit.stop_cast()
		ReliableMessageQueue.push_message(Constants.ALL_CONNECTED_PEERS_ID, {Constants.Network.INTERRUPT: unit.name})
		print("Casting interrupted by movement")
		
	# Do not attempt to cast ability if moving or already casting
	if input[Constants.ClientInput.MOVEMENT] != Vector2.ZERO || unit.is_casting:
		return
		
	if input.has(Constants.ClientInput.CAST):
		match input[Constants.ClientInput.CAST]:
			1: # Arbitrary ability index
				unit.start_cast(2.0)
