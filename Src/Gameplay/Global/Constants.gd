extends Node


const ALL_CONNECTED_PEERS_ID := 0
const SERVER_ID := 1
const SERVER_TICK_RATE_MS := 50
const INTERPOLATION_OFFSET_MS := 100

class Network:
	const TIME = "T"
	const POSITION = "P"
	const CASTING = "C"
	const REQUEST_ID = "RID"


class ClientInput:
	const COMMAND = "C"
	const PAYLOAD = "P"
	const MOVEMENT = "M"
	const REQUEST_ID = "RID"
	const TIMESTAMP = "T"
	const PATH = "PTH"
