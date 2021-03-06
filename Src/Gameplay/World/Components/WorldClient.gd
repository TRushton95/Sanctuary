extends Node
class_name WorldClient

const unit_scene = preload("res://Gameplay/Entities/Unit/Unit.tscn")

const NULL_CASTING = -1.0

var world
var request_id := 0
var world_state_buffer := []
var prev_world_state_timestamp := 0
var buffered_movement_input
var request_log := RequestLog.new()
var last_processed_packet_id = -1


func _init(world) -> void:
	self.world = world


func _unhandled_input(event) -> void:
	if !event is InputEventMouseButton:
		return
		
	if event.button_index == BUTTON_RIGHT && event.pressed:
		world.player.path = NavigationHelper.get_simple_path(world.player.position, event.global_position)


func get_input(movement_delta: Vector2) -> Dictionary:
	var input = null
	
	# TODO need to add cast AND move to single command
	input = InputHelper.build_base_input(movement_delta, request_id)
		
	if Input.is_action_just_pressed("cast_ability_1"):
		InputHelper.add_cast_command(input, Enums.Abilities.FROSTBOLT) # This needs to map from key -> ability via spellbar/spellbook
		
		
	return input


func send_input(input: Dictionary) -> void:
	GameServer.send_player_input(input)
	
	var history_data = input.duplicate()
	history_data[Constants.ClientInput.PATH] = world.player.path
	request_log.add(history_data)
	
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
			_reconcile_client_side_prediction(world_state[player_id], world_state[Constants.Network.TIME])


func process_world_state() -> void:
	var render_time = ServerClock.get_time() - Constants.INTERPOLATION_OFFSET_MS # The game time that we are rendering locally
	if world_state_buffer.size() > 1:
		while world_state_buffer.size() > 2 && world_state_buffer[2][Constants.Network.TIME] < render_time:
			world_state_buffer.remove(0)
			
		if world_state_buffer.size() > 2: # We have a future state to interpolate with
			var interpolation_factor = float(render_time - world_state_buffer[1][Constants.Network.TIME]) / float(world_state_buffer[2][Constants.Network.TIME] - world_state_buffer[1][Constants.Network.TIME])
			
			for key in world_state_buffer[2].keys():
				if str(key) == Constants.Network.PACKET_ID:
					continue
				if str(key) == Constants.Network.TIME:
					continue
				if !world_state_buffer[1].has(key):
					continue
				
				var username = ServerInfo.get_username(key)
				var user = world.get_player(username)
				
				# Spawn new player or move existing player
				if key != get_tree().get_network_unique_id() || world.player == null:
					var new_position = lerp(world_state_buffer[1][key][Constants.Network.POSITION], world_state_buffer[2][key][Constants.Network.POSITION], interpolation_factor)
					
					if user != null:
						user.position = new_position
					else:
						world.create_player(key, username, new_position)
						
						
				var ability_index_from = -1
				var casting_from = NULL_CASTING
				
				if world_state_buffer[1][key].has(Constants.Network.CASTING):
					ability_index_from = world_state_buffer[1][key][Constants.Network.CASTING][0]
					casting_from = world_state_buffer[1][key][Constants.Network.CASTING][1]
					
				var ability_index_to = -1
				var casting_to = NULL_CASTING
				
				if world_state_buffer[2][key].has(Constants.Network.CASTING):
					ability_index_to = world_state_buffer[2][key][Constants.Network.CASTING][0]
					casting_to = world_state_buffer[2][key][Constants.Network.CASTING][1]
					
				# TODO: This needs adding to the elif statement below too
				_resolve_casting_interpolation(user, ability_index_from, ability_index_to, casting_from, casting_to, interpolation_factor, world_state_buffer[2][Constants.Network.PACKET_ID])
				
			last_processed_packet_id = world_state_buffer[2][Constants.Network.PACKET_ID]
					
		elif render_time > world_state_buffer[1][Constants.Network.TIME]:
			var extrapolation_factor = float(render_time - world_state_buffer[0][Constants.Network.TIME]) / float(world_state_buffer[1][Constants.Network.TIME] - world_state_buffer[0][Constants.Network.TIME]) - 1.0
			
			for key in world_state_buffer[1].keys():
				if str(key) == Constants.Network.PACKET_ID:
					continue
				if str(key) == Constants.Network.TIME:
					continue
				if !world_state_buffer[1].has(key):
					continue
				if key == get_tree().get_network_unique_id() && world.player != null: # If player is not set, we need to create a unit for the player
					continue
					
				var username = ServerInfo.get_username(key)
				var delta_position = world_state_buffer[1][key][Constants.Network.POSITION] - world_state_buffer[0][key][Constants.Network.POSITION]
				var new_position = world_state_buffer[1][key][Constants.Network.POSITION] + (delta_position * extrapolation_factor)
				
				var user = world.get_player(username)
				if user != null:
					user.position = new_position
				else:
					world.create_player(key, username, new_position)
					
			last_processed_packet_id = world_state_buffer[1][Constants.Network.PACKET_ID]


func _reconcile_client_side_prediction(player_state: Dictionary, update_timestamp: float) -> void:
	# Enforce state to most recent server state
	world.player.position = player_state[Constants.Network.POSITION]
	
	# Replay client-side prediction based on most recent available server data
	request_log.clear_oudated_requests(player_state[Constants.Network.REQUEST_ID])
	
	if !request_log.is_empty():
		for request in request_log.get_requests():
			world.player.position += request[Constants.ClientInput.MOVEMENT]


func _resolve_casting_interpolation(user: Unit, ability_index_from: int, ability_index_to: int, casting_from: float, casting_to: float, interpolation_factor: float, packet_id: int) -> void:
	var has_casting_from = casting_from != NULL_CASTING
	var has_casting_to = casting_to != NULL_CASTING
	
	# No new casting information
	if !has_casting_from && !has_casting_to:
		return
		
	var current_cast_time = lerp(casting_from, casting_to, interpolation_factor)
	
	# Ensure we don't attempt to start/stop casts multiple times due to processing the same two packets more than once
	if packet_id > last_processed_packet_id:
		#  Stop casting
		if has_casting_from && !has_casting_to:
			print("End cast from server update")
			user.stop_cast()
			return
			
		# Start casting
		if !has_casting_from && has_casting_to:
			print("Start cast from server update")
			user.start_cast(ability_index_to, casting_to)
			return
			
		# Spell cast has changed from one to another within a single frame
		if ability_index_from > -1 && ability_index_to > -1 && ability_index_from != ability_index_to:
			print ("Changing spell cast")
			user.stop_cast()
			user.start_cast(ability_index_to, casting_to)
		
	# Progress casting
	if has_casting_from && has_casting_to:
		var cast_progress = lerp(casting_from, casting_to, interpolation_factor)
		
		if user.is_casting():
			user.set_cast_progress(cast_progress)
		else:
			user.start_cast(ability_index_to, cast_progress) # TODO Send spell id or something and pull duration from that
