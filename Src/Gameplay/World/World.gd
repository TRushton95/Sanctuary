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


func _ready() -> void:
	_setup_components()
	
	var player_name = ServerInfo.get_username(get_tree().get_network_unique_id())
	get_node("Unit").name = player_name
	
	player = get_node(player_name)
	player.set_network_master(get_tree().get_network_unique_id())
	
	GameServer.setup(self)
	ServerClock.setup()
	ServerClock.connect("ping_updated", self, "_on_ServerClock_ping_updated")


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("LagSim"):
		GameServer.set_lag_simulation(true)
		$LagSimTimer.start(LAG_SIM_DURATION)
		$CanvasLayer/NetworkInfo/VBoxContainer/LagSimWarning.show()
		
	if Input.is_action_just_pressed("Cast"):
		player.cast()


func _physics_process(delta: float) -> void:
	var prev_player_position = player.position
	player.move_along_path(delta)
	var movement_delta = player.position - prev_player_position
	
	world_client.send_player_update(movement_delta)
		
	if get_tree().is_network_server():
		world_server.process_client_update_requests(delta)
		
	world_client.process_world_state()


func _unhandled_input(event) -> void:
	if !event is InputEventMouseButton:
		return
		
	if event.button_index == BUTTON_RIGHT && event.pressed:
		var path = $Navigation2D.get_simple_path(player.position, event.position)
		$PathDebug.clear_points()
		for point in path:
			$PathDebug.add_point(point)
					
		path.remove(0) # Remove starting point
		player._path = path


master func receive_player_state(new_player_state: Dictionary) -> void:
	world_server.update_player_state(new_player_state)


remotesync func receive_world_state(world_state: Dictionary) -> void:
	world_client.update_world_state(world_state)


func create_player(user_id: int, username: String, position: Vector2):
	var new_unit = unit_scene.instance()
	new_unit.position = position
	new_unit.name = username
	add_child(new_unit)
	new_unit.set_network_master(user_id)


func _setup_components() -> void:
	world_server = WorldServer.new()
	world_client = WorldClient.new(self)
	
	add_child(world_client)
	add_child(world_server)
