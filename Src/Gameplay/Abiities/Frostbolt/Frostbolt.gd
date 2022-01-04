extends Ability


func execute(target, caster: Unit) -> void:
	if !target is Unit:
		return
		
	print("Frostbolt executed!")
	ReliableMessageQueue.push_message(Constants.ALL_CONNECTED_PEERS_ID, { Constants.Network.DEBUG: "Frosbolt remotely executed!" })
