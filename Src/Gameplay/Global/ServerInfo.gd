extends Node

var _players = {}

signal user_joined(user_id)
signal user_disconnected(username)


func _ready() -> void:
	get_tree().connect("connected_to_server", self, "_on_connection_successful")
	get_tree().connect("network_peer_connected", self, "_on_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_network_peer_disconnected")


func add_user(id: int, username: String) -> void:
	if _players.has(id):
		print("Player id " + str(id) + " is already assigned.")
		return
		
	_players[id] = username


func remove_user(id: int) -> void:
	if _players.has(id):
		_players.erase(id)


func get_username(id: int) -> String:
	var result = ""
	
	if _players.has(id):
		result = _players[id]
		
	return result


func get_users() -> Dictionary:
	return _players


remote func populate_players(players: Dictionary) -> void:
	_players = players
	print("Currenty active players: " + str(players))


func _on_connection_successful() -> void:
	pass


func _on_network_peer_connected(id: int) -> void:
	print("User joined: " + str(id))
	add_user(id, "Client")
	
	if get_tree().is_network_server():
		var sender_id = get_tree().get_rpc_sender_id()
		rpc_id(sender_id, "populate_players", _players)
		
		emit_signal("user_joined", sender_id)
	


func _on_network_peer_disconnected(id: int) -> void:
	print("User disconnected: " + str(id))
	var username = get_username(id)
	remove_user(id)
	
	if get_tree().is_network_server():
		emit_signal("user_disconnected", username)
