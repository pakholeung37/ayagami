extends SceneTree

const DEMO := preload("res://main.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo := DEMO.instantiate()
	root.add_child(demo)
	var parameters := {}
	for parameter in demo.model.get_parameters():
		parameters[parameter.id] = parameter
	var maximum_open_difference := 0.0
	var minimum_left := INF
	var minimum_right := INF
	for frame in 120:
		await process_frame
		var left: float = parameters.ParamEyeLOpen.value
		var right: float = parameters.ParamEyeROpen.value
		maximum_open_difference = maxf(maximum_open_difference, absf(left - right))
		minimum_left = minf(minimum_left, left)
		minimum_right = minf(minimum_right, right)
	print(
		"AYAGAMI_CORE_EYE_DIAGNOSTIC max_lr_difference=%f min_left=%f min_right=%f eyeball=(%f,%f)"
		% [
			maximum_open_difference,
			minimum_left,
			minimum_right,
			parameters.ParamEyeBallX.value,
			parameters.ParamEyeBallY.value,
		]
	)
	quit(0)
