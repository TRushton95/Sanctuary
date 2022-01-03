extends Node

var queue := {}
var acknowledgements := []
var next_message_id := 0

signal message_received


# TODO Find an appropriate tick rate for this
func _process(delta: float) -> void:
	if get_tree().is_network_server():
		broadcast_unacknowledged_messages()
	else:
		for acknowledgement in acknowledgements:
			send_acknowledgement(acknowledgement)

###################
#  CLIENT METHODS #
###################

remote func receive_message(message: Dictionary) -> void:
	var deserialisedMessage = dict2inst(message)
	acknowledgements.push_back(deserialisedMessage.id)
	
	emit_signal("message_received", deserialisedMessage.data)


func send_acknowledgement(message_id: int) -> void:
	rpc_unreliable_id(Constants.SERVER_ID, "receive_acknowledgement", message_id)


remote func receive_thank_you(message_id: int) -> void:
	var index = acknowledgements.find(message_id)
	
	if index > -1:
		acknowledgements.remove(index)


###################
#  SERVER METHODS #
###################

# TODO this should work both ways, clients need to be able to reliably send input
func push_message(peer_id: int, data: Dictionary) -> void:
	var message = ReliableMessage.new(next_message_id, peer_id, data)
	queue[message.id] = message
	
	next_message_id += 1


func broadcast_unacknowledged_messages() -> void:
	for message in queue.values():
		for peer in message.get_unackowledged_peers():
			rpc_unreliable_id(peer, "receive_message", inst2dict(message))


master func receive_acknowledgement(message_id: int) -> void:
	var sender_id = get_tree().get_rpc_sender_id()
	
	if !queue.has(message_id):
		return
		
	var message = queue[message_id]
	
	if !message.has(sender_id):
		return
		
	message[sender_id].set_peer_acknowledgement(sender_id, true)
	
	if message[sender_id].all_peers_acknowledged():
		queue.erase(sender_id)
	
	send_thank_you(sender_id)


func send_thank_you(peer_id: int) -> void:
	rpc_id(peer_id, "receive_thank_you")
