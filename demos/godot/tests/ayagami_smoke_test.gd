extends SceneTree

const DEMO_SCENE := preload("res://ayagami_demo.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo := DEMO_SCENE.instantiate()
	root.add_child(demo)
	for frame in range(120):
		if demo.model != null and not demo.motions.is_empty():
			break
		await process_frame

	assert(demo.model != null, "Ayagami failed to load the Mao model")
	assert(demo.motion_player != null, "Motion controller was not initialized")
	assert(demo.expression_controller != null, "Expression controller was not initialized")
	assert(demo.parameter_names.size() == 128, "Unexpected parameter count")
	assert(demo.model.get_node("Meshes").get_child_count() == 260, "Unexpected mesh count")
	assert(demo.motions.size() == 7, "Unexpected motion count")
	assert(demo.expressions.size() == 8, "Unexpected expression count")

	demo._on_play_motion_pressed()
	demo._on_apply_expression_pressed()
	await process_frame
	demo._on_clear_expression_pressed()
	await process_frame

	print(
		"AYAGAMI_SMOKE_TEST_OK parameters=%d meshes=%d motions=%d expressions=%d"
		% [
			demo.parameter_names.size(),
			demo.model.get_node("Meshes").get_child_count(),
			demo.motions.size(),
			demo.expressions.size(),
		]
	)
	quit(0)
