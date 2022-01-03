extends Node
class_name ReliableMessage

var id := -1
var data := {}
var acknowledgements := {}


func _init(id: int, peer_id: int, data: Dictionary) -> void:
	var target_peers = ServerInfo.get_users().keys() if peer_id == Constants.ALL_CONNECTED_PEERS_ID else [peer_id]
	
	# Do not want to broadcast to self
	var my_id_index = target_peers.find(ServerInfo.get_my_id())
	if my_id_index > -1:
		target_peers.remove(my_id_index)
	
	for peer_id in target_peers:
		if peer_id is int && !acknowledgements.has(peer_id):
			acknowledgements[peer_id] = false
			
	self.id = id
	self.data = data


func all_peers_acknowledged() -> bool:
	for peer_id in acknowledgements.keys():
		if !acknowledgements[peer_id]:
			return false
			
	return true


func requires_peer_acknowledgement(peer_id: int) -> bool:
	return acknowledgements.has(peer_id)


func get_unacknowledged_peers() -> Array:
	var result = []
	
	for peer_id in acknowledgements.keys():
		if !acknowledgements[peer_id]:
			result.push_back(peer_id)
			
	return result


func get_peer_acknowledgement(peer_id: int) -> bool:
	if acknowledgements.has(peer_id):
		return acknowledgements[peer_id]
		
	print("Can't find peer in acknowledgement list")
	
	return false


func set_peer_acknowledgement(peer_id: int, value: bool) -> void:
	if acknowledgements.has(peer_id):
		acknowledgements[peer_id] = value
