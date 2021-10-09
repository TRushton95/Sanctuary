extends Node
class_name Stopwatch

var duration := -1.0 setget ,get_duration
var current_time := -1.0
var is_running := false setget ,get_is_running

signal started
signal stopped


func _process(delta: float) -> void:
	if !is_running:
		return
		
	current_time += delta
	
	if current_time > duration:
		is_running = false
		emit_signal("stopped")


func start(duration: float, current_time := 0.0) -> void:
	self.duration = duration
	self.current_time = current_time if current_time > 0.0 else 0
	is_running = true
	emit_signal("started")


func stop() -> void:
	if is_running:
		is_running = false
		emit_signal("stopped")


# Setgetters
func get_duration() -> float:
	return duration


func get_is_running() -> bool:
	return is_running
