extends ProgressBar


func set_progress(value: float) -> void:
	self.value = value
	$Label.text = str(value).pad_decimals(2)
