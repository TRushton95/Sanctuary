extends Node


func _on_ServerButton_pressed():
	_setup_server()
	get_tree().change_scene("res://Gameplay/World.tscn")


func _on_ClientButton_pressed():
	_connect_to_server()
	$CenterContainer/VBoxContainer/Label.text = "Connecting..."


func _on_connection_failed() -> void:
	$CenterContainer/VBoxContainer/Label.text = "Connection failed"


func _on_connection_successful() -> void:
	get_tree().change_scene("res://Gameplay/World.tscn")


func _ready() -> void:
	get_tree().connect("connected_to_server", self, "_on_connection_successful")
	get_tree().connect("connection_failed", self, "_on_connection_failed")


func _setup_server() -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(1026, 2)
	get_tree().set_network_peer(peer)
	ServerInfo.add_user(get_tree().get_network_unique_id(), "Server")


func _connect_to_server() -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client("127.0.0.1", 1026)
	get_tree().set_network_peer(peer)
	ServerInfo.add_user(get_tree().get_network_unique_id(), "Client")
