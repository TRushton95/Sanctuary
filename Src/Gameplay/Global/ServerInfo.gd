extends Node

var _players = {}

func add_user(id: int, username: String) -> void:
	if _players.has(id):
		print("Player id " + str(id) + " is already assigned.")
		return
		
	_players[id] = username


func get_username(id: int) -> String:
	var result = ""
	
	if _players.has(id):
		result = _players[id]
		
	return result
