extends KinematicBody2D
class_name Unit

const SPEED := 300

var path : PoolVector2Array setget set_path

var casting_index := -1

signal path_set
signal path_expired
signal started_casting(duration)
signal stopped_casting
signal finished_casting
signal progressed_casting(value)
signal clicked


func _on_CastTimer_started(duration: float) -> void:
	$CastBar.set_max_value(duration)
	$CastBar.show()


func _on_CastTimer_stopped() -> void:
	casting_index = -1
	$CastBar.hide()
	emit_signal("stopped_casting")


func _on_CastTimer_finished() -> void:
	print("Finished casting!")
	casting_index = -1
	emit_signal("finished_casting")


func _process(delta: float) -> void:
	if is_casting():
		$CastBar.set_progress($CastTimer.current_time)
		emit_signal("progressed_casting", $CastTimer.current_time)


func _input(event) -> void:
	if event is InputEventMouseButton && event.button_index == BUTTON_LEFT && event.pressed:
		emit_signal("clicked")


func start_cast(ability_index: int, current_time: float = 0.0) -> void:
	var ability = get_node("Abilities").get_child(ability_index)
	$CastTimer.start(ability.cast_time, current_time)
	casting_index = ability_index
	emit_signal("started_casting", ability.cast_time)


func stop_cast() -> void:
	$CastTimer.stop()


func set_cast_progress(current_time: float) -> void:
	$CastTimer.current_time = current_time


func get_cast_progress() -> float:
	return $CastTimer.current_time if is_casting() else -1.0


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

func is_casting() -> bool:
	return casting_index > -1
