extends KinematicBody2D

const SPEED := 300

var _path : PoolVector2Array

signal path_expired

func _physics_process(delta: float) -> void:
	if !_path.empty():
		var walkable_distance = SPEED * delta
		var distance_to_next_point = position.distance_to(_path[0])
		
		while !_path.empty() && walkable_distance > 0:
			if walkable_distance > distance_to_next_point:
				walkable_distance -= position.distance_to(_path[0])
				position = _path[0]
				_path.remove(0)
			else:
				position += position.direction_to(_path[0]) * walkable_distance
				walkable_distance = 0
				
		if _path.empty():
			emit_signal("path_expired")
			
	if is_network_master():
		var player_state = {
			Constants.Network.TIME: OS.get_system_time_msecs(),
			Constants.Network.POSITION: get_global_position()
		}
		
		GameServer.send_player_state(player_state)
