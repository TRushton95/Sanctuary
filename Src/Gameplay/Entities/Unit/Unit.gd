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


func _on_CastTimer_stopped():
	is_casting = false
	emit_signal("stopped_casting")


func _process(delta: float) -> void:
	if is_casting:
		emit_signal("progressed_casting", $CastTimer.current_time)


func start_cast(duration: float, current_time: float = 0.0) -> void:
	$CastTimer.start(duration, current_time)
	emit_signal("started_casting")


func stop_cast() -> void:
	$CastTimer.stop()


func get_cast_progress() -> float:
	if !is_casting:
		return -1.0
		
	return $CastTimer.current_time


func input_command(command) -> void:
	if command is MoveCommand:
		stop_cast()
		var new_path = NavigationHelper.get_simple_path(position, command.path)
		new_path.remove(0) # Remove starting position
		path = new_path
		
	if command is CastCommand:
		start_cast(command.duration)


func move_along_path(delta: float) -> void:
	if !path.empty():
		var walkable_distance = SPEED * delta
		
		while !path.empty() && walkable_distance > 0:
			if walkable_distance > position.distance_to(path[0]):
				walkable_distance -= position.distance_to(path[0])
				position = path[0]
				path.remove(0)
			else:
				position += position.direction_to(path[0]) * walkable_distance
				walkable_distance = 0
				
		if path.empty():
			emit_signal("path_expired")



func set_path(value: PoolVector2Array) -> void:
	path = value
	emit_signal("path_set", path)

func get_is_casting() -> bool:
	return is_casting
