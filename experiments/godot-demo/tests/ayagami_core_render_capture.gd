extends SceneTree

const MODEL := "res://assets/live2d/mao/runtime/mao_pro.model3.json"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	ProjectSettings.set_setting("gd_cubism/rendering/batching", true)
	var background := ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color(0.035, 0.043, 0.066, 1)
	root.add_child(background)
	var model := GDCubismUserModel.new()
	root.add_child(model)
	model.assets = MODEL
	model.playback_process_mode = GDCubismUserModel.MANUAL
	model.position = Vector2(490, 360)
	model.scale = Vector2.ONE * 0.0788
	var parameters := {}
	for parameter in model.get_parameters():
		parameters[parameter.id] = parameter
		if parameter.id in ["ParamEyeLOpen", "ParamEyeROpen"]:
			parameter.value = 1.0
		elif parameter.id == "ParamEyeBallY":
			parameter.value = 0.0
		elif parameter.id == "ParamAngleY":
			parameter.value = 0.0
	for step in 41:
		var normalized := -1.0 + step / 20.0
		parameters["ParamAngleX"].value = normalized * 20.0
		parameters["ParamEyeBallX"].value = normalized
		model.advance(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png("res://artifacts/ayagami-core-render-turned.png")
	assert(error == OK, "Failed to save Ayagami Core render capture")
	print("AYAGAMI_CORE_RENDER_CAPTURE_OK")
	quit(0)
