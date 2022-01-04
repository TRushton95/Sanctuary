extends ProgressBar


func set_max_value(value: float) -> void:
	self.max_value = value


func set_progress(value: float) -> void:
	self.value = value
	$Label.text = str(value).pad_decimals(2)
