extends Node

func build_base_input(movement_delta: Vector2, request_id: int) -> Dictionary:
	var data = {
		Constants.ClientInput.MOVEMENT: movement_delta,
		Constants.Network.REQUEST_ID: request_id, # TODO: Super hacky fix to make comparisons work, look into unifying userInput and request messages
		Constants.ClientInput.TIMESTAMP: ServerClock.get_time()
	}
	
	return data


func add_cast_command(input: Dictionary, cast_index: int) -> void:
	input[Constants.ClientInput.CAST] = cast_index
