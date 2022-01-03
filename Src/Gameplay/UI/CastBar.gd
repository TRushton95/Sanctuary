extends ProgressBar


func set_progress(value: float) -> void:
	$CastBar.value = value
	$CastBar/Label.text = str(value).pad_decimals(2)
