extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func run() -> void:
	var model_path := OS.get_environment("CUBISM_TEST_MODEL")
	if not check(not model_path.is_empty(), "Set CUBISM_TEST_MODEL to a model3.json path"):
		return
	for batching in [false, true]:
		ProjectSettings.set_setting("gd_cubism/rendering/batching", batching)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 360)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var model := GDCubismUserModel.new()
		viewport.add_child(model)
		model.assets = model_path
		model.position = Vector2(160, 180)
		model.scale = Vector2.ONE * 0.07
		model.physics_evaluate = false
		var cover := ColorRect.new()
		cover.size = Vector2(320, 360)
		cover.color = Color.GREEN
		model.add_child(cover)
		cover.top_level = true
		var render_root := model.get_node_or_null("CubismRenderRoot")
		if not check(render_root != null, "Missing isolated render container"):
			return
		var expressions: Array = [""]
		expressions.append_array(model.get_expressions())
		for layer in [2, 1, 4]:
			viewport.canvas_cull_mask = layer
			model.visibility_layer = layer
			cover.visibility_layer = layer
			for expression in expressions:
				if expression != "":
					model.start_expression(expression)
				for frame in 10:
					await process_frame
				await RenderingServer.frame_post_draw
				if not check(render_root.get_index() < cover.get_index(), "Internal sorting moved user attachment"):
					return
				if not check(render_root.visibility_layer == layer, "Container layer is stale"):
					return
				for drawable in render_root.get_children():
					if not check(drawable.visibility_layer == layer, "Drawable layer is stale"):
						return
				var pixels := viewport.get_texture().get_image()
				for y in range(0, 360, 8):
					for x in range(0, 320, 8):
						var pixel := pixels.get_pixel(x, y)
						if not check(pixel.g > 0.98 and pixel.r < 0.02 and pixel.b < 0.02, "Attachment occluded"):
							return
			cover.hide()
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			var colored := 0
			for y in range(0, 360, 4):
				for x in range(0, 320, 4):
					var pixel := pixels.get_pixel(x, y)
					if pixel.r + pixel.g + pixel.b > 0.5:
						colored += 1
			if not check(colored > 100, "Model disappeared after layer switch"):
				return
			cover.show()
		viewport.queue_free()
		await process_frame
	print("RUNTIME_RENDER_TEST_OK")
	quit()
