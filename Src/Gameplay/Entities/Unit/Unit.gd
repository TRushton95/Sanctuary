extends KinematicBody2D
class_name Unit

const SPEED := 300

var path : PoolVector2Array setget set_path
var is_casting := false setget ,get_is_casting

signal path_set
signal path_expired
signal started_casting
signal stopped_casting
signal progressed_casting(value)


func _on_CastTimer_started() -> void:
	$CastBar.show()


func _on_CastTimer_stopped() -> void:
	is_casting = false
	$CastBar.hide()
	emit_signal("stopped_casting")


func _on_CastTimer_finished() -> void:
	print("Bang!")


func _process(delta: float) -> void:
	if is_casting:
		$CastBar.value = $CastTimer.current_time
		$CastBar/Label.text = str($CastTimer.current_time).pad_decimals(2)
		emit_signal("progressed_casting", $CastTimer.current_time)


func start_cast(duration: float, current_time: float = 0.0) -> void:
	$CastTimer.start(duration, current_time)
	is_casting = true
	emit_signal("started_casting")


func stop_cast() -> void:
	$CastTimer.stop()


func set_cast_progress(current_time: float) -> void:
	$CastTimer.current_time = current_time


func get_cast_progress() -> float:
	if !is_casting:
		return -1.0
		
	return $CastTimer.current_time


func get_next_position_delta(delta: float) -> Vector2:
	var result = Vector2.ZERO
	
	if !path.empty():
		var walkable_distance = SPEED * delta
		var simulated_position = position
		
		while !path.empty() && walkable_distance > 0:
			if walkable_distance > simulated_position.distance_to(path[0]):
				walkable_distance -= simulated_position.distance_to(path[0])
				simulated_position = path[0]
				path.remove(0)
			else:
				simulated_position += simulated_position.direction_to(path[0]) * walkable_distance
				walkable_distance = 0
				
		result = simulated_position - position
		
		if path.empty():
			emit_signal("path_expired")
		
	return result


func set_path(value: PoolVector2Array) -> void:
	path = value
	emit_signal("path_set", path)

func get_is_casting() -> bool:
	return is_casting
