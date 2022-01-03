extends Node

var queue := {}
var outgoing_acknowledgements := []
var next_message_id := 0

signal message_received


# TODO Find an appropriate tick rate for this
# TODO Chuck out messages with already process ids
# TODO Give up broadcasting message if recipient doesn't respond within given time
func _process(delta: float) -> void:
	if get_tree().is_network_server():
		broadcast_unacknowledged_messages()
	else:
		for acknowledgement in outgoing_acknowledgements:
			send_acknowledgement(acknowledgement)

###################
#  CLIENT METHODS #
###################

remote func receive_message(message_id: int, message_data: Dictionary) -> void:
	print("Received messsage")
	outgoing_acknowledgements.push_back(message_id)
	
	emit_signal("message_received", message_data)


func send_acknowledgement(message_id: int) -> void:
	print("Sent acknowledgement")
	rpc_unreliable_id(Constants.SERVER_ID, "receive_acknowledgement", message_id)


remote func receive_thank_you(message_id: int) -> void:
	print("Received thank you")
	var index = outgoing_acknowledgements.find(message_id)
	
	if index > -1:
		outgoing_acknowledgements.remove(index)


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
		for peer in message.get_unacknowledged_peers():
			print("Broadcasting " + str(message.id) + " to " + str(peer))
			rpc_unreliable_id(peer, "receive_message", message.id, message.data)


master func receive_acknowledgement(message_id: int) -> void:
	print("Received ack")
	var sender_id = get_tree().get_rpc_sender_id()
	
	if !queue.has(message_id):
		return
		
	var message = queue[message_id]
	
	if !message.requires_peer_acknowledgement(sender_id):
		return
		
	message.set_peer_acknowledgement(sender_id, true)
	
	if message.all_peers_acknowledged():
		queue.erase(sender_id)
	
	send_thank_you(sender_id, message_id)


func send_thank_you(peer_id: int, message_id: int) -> void:
	print("Sent thank you")
	rpc_id(peer_id, "receive_thank_you", message_id)
