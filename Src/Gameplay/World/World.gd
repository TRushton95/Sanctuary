extends Node

const unit_scene = preload("res://Gameplay/Entities/Unit/Unit.tscn")

const LAG_SIM_DURATION = 0.5

# Components
var world_server: WorldServer
var world_client: WorldClient

var player


func _on_ServerClock_ping_updated(ping: int) -> void:
	$CanvasLayer/NetworkInfo/VBoxContainer/Ping.text = "Ping: " + str(ping) + "ms"


func _on_LagSimTimer_timeout() -> void:
	GameServer.set_lag_simulation(false)
	$CanvasLayer/NetworkInfo/VBoxContainer/LagSimWarning.hide()


func _on_Unit_path_expired() -> void:
	$PathDebug.clear_points()


func _on_Unit_started_casting() -> void:
	$CanvasLayer/CastBar.show()


func _on_Unit_stopped_casting() -> void:
	$CanvasLayer/CastBar.hide()


func _on_Unit_progressed_casting(value: float) -> void:
	$CanvasLayer/CastBar.value = value
	$CanvasLayer/CastBar/Label.text = str(value).pad_decimals(2)


func _on_Unit_path_set(path: PoolVector2Array) -> void:
	path.insert(0, player.position)
	
	$PathDebug.clear_points()
	for point in path:
		$PathDebug.add_point(point)


func _ready() -> void:
	_setup_components()
	
	NavigationHelper.setup($Navigation2D)
	GameServer.setup(self)
	ServerClock.setup()
	ServerClock.connect("ping_updated", self, "_on_ServerClock_ping_updated")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("LagSim"):
		GameServer.set_lag_simulation(true)
		$LagSimTimer.start(LAG_SIM_DURATION)
		$CanvasLayer/NetworkInfo/VBoxContainer/LagSimWarning.show()
		
	if get_tree().is_network_server():
		# Won't work on client, lots of effort for a debugging tool
		if Input.is_action_just_pressed("Pushback") && player.is_casting:
			player.set_cast_progress(player.get_cast_progress() - 1.0)
		
	if player == null:
		return
		
	var movement_delta = player.get_next_position_delta(delta)
	var input = world_client.get_input(movement_delta)
	
	if input:
		world_client.send_input(input)
		
		# Immediately apply local client movement input
		if !get_tree().is_network_server():
			player.position += input[Constants.ClientInput.MOVEMENT]


func _physics_process(delta: float) -> void:
	if get_tree().is_network_server():
		world_server.process_player_input_buffer()
		world_server.send_world_state(delta)
	else:
		world_client.process_world_state()
		
	#player.try_move_along_path(delta)


master func receive_player_input(player_input: Dictionary) -> void:
	world_server.buffer_player_input(player_input)


puppet func receive_world_state(world_state: Dictionary) -> void:
	world_client.buffer_world_state(world_state)


func get_player(username: String) -> Node:
	var result = null
	
	if $Players.has_node(username):
		result = $Players.get_node(username)
	
	return result


func create_player(user_id: int, username: String, position: Vector2) -> void:
	var new_unit = unit_scene.instance()
	new_unit.position = position
	new_unit.name = username
	$Players.add_child(new_unit)
	#new_unit.set_network_master(user_id) # TODO Is this necessary?
	
	if user_id == get_tree().get_network_unique_id():
		player = new_unit
		
		player.connect("path_expired", self, "_on_Unit_path_expired")
		player.connect("started_casting", self, "_on_Unit_started_casting")
		player.connect("stopped_casting", self, "_on_Unit_stopped_casting")
		player.connect("progressed_casting", self, "_on_Unit_progressed_casting")
		player.connect("path_set", self, "_on_Unit_path_set")


func remove_player(username: String) -> void:
	var player = $Players.get_node(username)
	player.queue_free()


func _setup_components() -> void:
	if get_tree().get_network_unique_id() == Constants.SERVER_ID:
		world_server = WorldServer.new(self)
		add_child(world_server)
		
	world_client = WorldClient.new(self)
	add_child(world_client)
