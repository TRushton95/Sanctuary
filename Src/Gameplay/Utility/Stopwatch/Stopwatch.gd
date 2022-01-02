extends Node
class_name Stopwatch

var duration := -1.0 setget ,get_duration
var current_time := -1.0 setget set_current_time, get_current_time
var is_running := false setget ,get_is_running

signal started
signal stopped
signal finished


func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if !is_running:
		return
		
	current_time += delta
	
	if current_time > duration:
		stop()
		emit_signal("finished")


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


func set_current_time(value: float) -> void:
	var new_time = value
	
	if value < 0:
		new_time = 0
		
	if value > duration:
		new_time = duration
		stop()
		
	current_time = new_time


func get_current_time() -> float:
	return current_time


func get_is_running() -> bool:
	return is_running
