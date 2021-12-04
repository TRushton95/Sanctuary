extends Node
class_name RequestLog

var _history := []


func add(input: Dictionary) -> void:
	_history.append(input)


func first() -> Dictionary:
	var result = {}
	
	if _history.size() > 0:
		result = _history[0]
		
	return result


func get_requests() -> Array:
	return _history


func is_empty() -> bool:
	return _history.empty()


func clear_oudated_requests(request_id: int) -> void:
	var oudated_requests = []
	for request in _history:
		if request[Constants.Network.REQUEST_ID] <= request_id: # Equal because we don't want to rollback through the already server-confirmed request
			oudated_requests.append(request)
			
	for request in oudated_requests:
		_history.erase(request)
