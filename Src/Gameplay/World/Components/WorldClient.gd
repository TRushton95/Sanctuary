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


func get_input() -> Dictionary:
	var input = null
	
	if world.buffered_movement_input is Vector2:
		input = InputHelper.build_data("M", world.buffered_movement_input, request_id)
	if world.buffered_movement_input != null: # Reset
		world.buffered_movement_input = null
		
	if Input.is_action_just_pressed("Cast"):
		var cast_time = 2.0
		input = InputHelper.build_data("Q", cast_time, request_id)
		
	return input


func send_input(input: Dictionary) -> void:
	GameServer.send_player_input(input)
	
	var history_data = input.duplicate()
	history_data[Constants.ClientInput.PATH] = world.player.path
	request_history.append(history_data)
	
	request_id += 1


func buffer_world_state(world_state: Dictionary) -> void:
	if world_state[Constants.Network.TIME] > prev_world_state_timestamp:
		prev_world_state_timestamp = world_state[Constants.Network.TIME]
		world_state_buffer.append(world_state)
		
		# Don't bother trying to correct client-side player prediction if we havn't got a player
		if world.player == null:
			return
		
		var player_id = get_tree().get_network_unique_id()
		if world_state.has(player_id):
			var player_state = world_state[player_id]
			
#			if world_state.has(Constants.Network.REQUEST_ID):
#				print("Sequence id from server: " + str(world_state[Constants.Network.REQUEST_ID]))
			
			var oudated_requests = []
			for request in request_history:
				if request[Constants.Network.REQUEST_ID] <= player_state[Constants.Network.REQUEST_ID]: # Equal because we don't want to rollback through the already server-confirmed request
					oudated_requests.append(request)
					
			# Remove oudated requests
			for request in oudated_requests:
				request_history.erase(request)
				
			# Enforce state to most recent server state
			world.player.position = player_state[Constants.Network.POSITION]
			
			if player_state.has(Constants.Network.CASTING):
				world.player.start_cast(2.0, player_state[Constants.Network.CASTING]) # TODO: Don't hardcode the duration here
				print("Enforced casting progress from server: " + str(player_state[Constants.Network.CASTING]))
			elif world.player.is_casting:
				world.player.stop_cast()
			
			# Replay client-side prediction based on most recent available server data
			if request_history.size() > 0:
				world.player.path = request_history[0][Constants.ClientInput.PATH]
				var FRAME_DURATION = 0.0167 # figure out how we can replay the timestep accurately
				var snapshot_time = world_state[Constants.Network.TIME] + FRAME_DURATION
				
				var temporary_request_history = request_history.duplicate()
				var inputs = []
				
				for request in temporary_request_history:
					if request[Constants.ClientInput.TIMESTAMP] < snapshot_time:
						inputs.append(request)
						
				for input in inputs:
					temporary_request_history.erase(input)
				
				while snapshot_time < ServerClock.get_time():
					play_forward_frame(FRAME_DURATION, snapshot_time, inputs)
					snapshot_time += FRAME_DURATION
					
				snapshot_time -= FRAME_DURATION # TODO: hack fix - snapshot time has been incremented to be bigger than get_time, we want the snapshot BEFORE that
				var remaining_time = ServerClock.get_time() - snapshot_time
				play_forward_frame(remaining_time, snapshot_time, inputs)


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
				if !world_state_buffer[1].has(key):
					continue
				if key == get_tree().get_network_unique_id() && world.player != null: # If player is not set, we need to create a unit for the player
					continue
				
				var username = ServerInfo.get_username(key)
				var new_position = lerp(world_state_buffer[1][key][Constants.Network.POSITION], world_state_buffer[2][key][Constants.Network.POSITION], interpolation_factor)
				
				if world.has_node(username):
					world.get_node(username).position = new_position
				else:
					world.create_player(key, username, new_position)
					
		elif render_time > world_state_buffer[1][Constants.Network.TIME]:
			var extrapolation_factor = float(render_time - world_state_buffer[0][Constants.Network.TIME]) / float(world_state_buffer[1][Constants.Network.TIME] - world_state_buffer[0][Constants.Network.TIME]) - 1.0
			
			for key in world_state_buffer[1].keys():
				if str(key) == Constants.Network.TIME:
					continue
				if !world_state_buffer[1].has(key):
					continue
				if key == get_tree().get_network_unique_id() && world.player != null: # If player is not set, we need to create a unit for the player
					continue
					
				var username = ServerInfo.get_username(key)
				var delta_position = world_state_buffer[1][key][Constants.Network.POSITION] - world_state_buffer[0][key][Constants.Network.POSITION]
				var new_position = world_state_buffer[1][key][Constants.Network.POSITION] + (delta_position * extrapolation_factor)
					
				if world.has_node(username):
					world.get_node(username).position = new_position
				else:
					world.create_player(key, username, new_position)


func play_forward_frame(delta: float, snapshot_time: float, inputs) -> void:
	for input in inputs:
		var command_type = input[Constants.ClientInput.COMMAND]
		var payload = input[Constants.ClientInput.PAYLOAD]
		var command = build_command(command_type, payload)
		world.player.input_command(command)
	
	world.player.try_move_along_path(delta)
	world.player.get_node("CastTimer").update(delta)


func build_command(command_type: String, payload):
	var result
	
	match command_type:
		"M":
			result = MoveCommand.new(payload)
		"Q":
			result = CastCommand.new(payload)
			
	return result
