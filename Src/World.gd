extends Node


func _on_Unit_path_expired() -> void:
	$PathDebug.clear_points()


func _unhandled_input(event) -> void:
	if !event is InputEventMouseButton:
		return
		
	if event.button_index == BUTTON_RIGHT && event.pressed:
		var path = $Navigation2D.get_simple_path($Unit.position, event.position)
		$PathDebug.clear_points()
		for point in path:
			$PathDebug.add_point(point)
					
		path.remove(0) # Remove starting point
		$Unit._path = path
