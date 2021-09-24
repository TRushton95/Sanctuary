extends Node

signal ping_updated(_latency)

const MAX_LATENCY_SAMPLE_SIZE := 9
const LATENCY_REMOVAL_THRESHOLD := 20
const LATENCY_SAMPLE_TIME := 0.5

var _time : int
var _latency: int
var _delta_latency := 0.0
var _latency_sample := []
var _decimal_collector := 0.0


func _on_LatencyTimer_timeout() -> void:
	rpc_id(Constants.SERVER_ID, "_determine_latency", OS.get_system_time_msecs())


func _physics_process(delta: float) -> void:
	var delta_ms = delta * 1000
	
	_time += int(delta_ms) + _delta_latency
	_delta_latency = 0
	
	_decimal_collector += delta_ms - int(delta_ms)
	if _decimal_collector >= 1.0:
		_time += 1.0
		_decimal_collector -= 1.0


func setup() -> void:
	_synchronise()
	
	if !is_network_master():
		var _latency_timer = Timer.new()
		_latency_timer.wait_time = LATENCY_SAMPLE_TIME
		_latency_timer.autostart = true
		_latency_timer.connect("timeout", self, "_on_LatencyTimer_timeout")
		add_child(_latency_timer)


func _synchronise() -> void:
	if is_network_master():
		_time = OS.get_system_time_msecs()
	else:
		rpc_id(Constants.SERVER_ID, "_get_server_time", OS.get_system_time_msecs())


remote func _get_server_time(client_time: int) -> void:
	var player_id = get_tree().get_rpc_sender_id()
	rpc_id(player_id, "_return_server_time", OS.get_system_time_msecs(), client_time)


remote func _determine_latency(client_time: int) -> void:
	var player_id = get_tree().get_rpc_sender_id()
	rpc_id(player_id, "_return_latency", client_time)


remote func _return_server_time(server_time: int, client_time: int) -> void:
	_latency = (OS.get_system_time_msecs() - client_time) / 2
	_time = server_time + _latency


remote func _return_latency(client_time: int) -> void:
	_latency_sample.push_back((OS.get_system_time_msecs() - client_time) / 2)
	
	if _latency_sample.size() == MAX_LATENCY_SAMPLE_SIZE:
		var _total_latency := 0
		_latency_sample.sort()
		var middle_index = int(ceil(MAX_LATENCY_SAMPLE_SIZE / 2))
		var median = _latency_sample[middle_index]
		
		for i in range(MAX_LATENCY_SAMPLE_SIZE - 1, -1, -1):
			if _latency_sample[i] > median * 2 && _latency_sample[i] > LATENCY_REMOVAL_THRESHOLD:
				_latency_sample.remove(i)
			else:
				_total_latency += _latency_sample[i]
				
		var new_latency = _total_latency / _latency_sample.size()
		
		_delta_latency = new_latency - _latency
		_latency = new_latency
		
		_latency_sample.clear()
		
		emit_signal("ping_updated", _latency)


func get_time() -> int:
	return _time
