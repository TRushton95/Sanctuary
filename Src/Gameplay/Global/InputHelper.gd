extends Node


func build_data(command, payload, request_id) -> Dictionary:
	var data = {
		Constants.ClientInput.COMMAND: command,
		Constants.Network.REQUEST_ID: request_id, # TODO: Super hacky fix to make comparisons work, look into unifying userInput and request messages
		Constants.ClientInput.TIMESTAMP: ServerClock.get_time()
	}
	
	if payload:
		data[Constants.ClientInput.PAYLOAD] = payload
		
	return data
