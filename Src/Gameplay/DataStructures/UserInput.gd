extends Node
class_name UserInput

var data : Dictionary setget ,get_data

func _init(command, payload, request_id):
	data = {
		Constants.ClientInput.COMMAND: command,
		Constants.Network.REQUEST_ID: request_id, # TODO: Super hacky fix to make comparisons work, look into unifying userInput and request messages
		Constants.ClientInput.TIMESTAMP: ServerClock.get_time()
	}
	
	if payload:
		data[Constants.ClientInput.PAYLOAD] = payload


func get_data() -> Dictionary:
	return data
