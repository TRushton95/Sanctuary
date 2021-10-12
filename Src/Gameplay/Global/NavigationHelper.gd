extends Node

var _nav_instance


func setup(nav_instance) -> void:
	self._nav_instance = nav_instance


func get_simple_path(from: Vector2, to: Vector2) -> PoolVector2Array:
	if !_nav_instance:
		print("Navigation instance not set")
		return PoolVector2Array()
		
	var result = _nav_instance.get_simple_path(from, to)
	result.remove(0) # Remove starting position
	
	return result
