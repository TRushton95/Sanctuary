extends Node
class_name UserInput

var data : Dictionary setget ,get_data

func _init(command, sequence_id, timestamp):
	data = {
		Constants.UserInput.COMMAND: command,
		Constants.UserInput.SEQUENCE_ID: sequence_id,
		Constants.UserInput.TIMESTAMP: timestamp
	}


func get_data() -> Dictionary:
	return data
