extends KinematicBody2D
class_name Unit

const SPEED := 300

var _path : PoolVector2Array
var _is_casting := false

signal path_expired
signal started_casting
signal stopped_casting
signal progressed_casting(value)


func _process(delta: float) -> void:
	if _is_casting:
		emit_signal("progressed_casting", $CastTimer.time_left)


func cast() -> void:
	if _is_casting:
		print("Already casting")
		return
		
	$CastTimer.start(2)
	_is_casting = true
	emit_signal("started_casting")


func move_along_path(delta: float) -> void:
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


func _on_CastTimer_timeout() -> void:
	_is_casting = false
	emit_signal("stopped_casting")
