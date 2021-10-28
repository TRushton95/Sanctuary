extends Node
class_name RequestLog

var history := []


func add(input: Dictionary) -> void:
	history.append(input)


func first() -> Dictionary:
	var result = {}
	
	if history.size() > 0:
		result = history[0]
		
	return result


func is_empty() -> bool:
	return history.empty()


func get_requests_by_time(timestamp: float, duration: float) -> Array:
	var inputs = []
	
	for request in history:
		var request_time = request[Constants.ClientInput.TIMESTAMP]
		if request_time > timestamp && request_time < timestamp + duration:
			inputs.append(request)
			
	return inputs


func clear_oudated_requests(request_id: int) -> void:
	var oudated_requests = []
	for request in history:
		if request[Constants.Network.REQUEST_ID] <= request_id: # Equal because we don't want to rollback through the already server-confirmed request
			oudated_requests.append(request)
			
	for request in oudated_requests:
		history.erase(request)
