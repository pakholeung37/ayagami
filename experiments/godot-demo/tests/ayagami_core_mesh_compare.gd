extends SceneTree

const MODEL := "res://assets/live2d/mao/runtime/mao_pro.model3.json"


func _initialize() -> void:
	_compare.call_deferred()


func _vectors_equal_approx(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for index in a.size():
		if not a[index].is_equal_approx(b[index]):
			return false
	return true


func _compare() -> void:
	ProjectSettings.set_setting("gd_cubism/rendering/batching", true)
	var core_model := GDCubismUserModel.new()
	root.add_child(core_model)
	core_model.assets = MODEL
	core_model.playback_process_mode = GDCubismUserModel.MANUAL
	core_model.advance(0.0)

	var ayagami_model: AyagamiModel = AyagamiLoader.load_model(MODEL)
	root.add_child(ayagami_model)
	await process_frame

	var ayagami_meshes := {}
	for child in ayagami_model.get_node("Meshes").get_children():
		ayagami_meshes[String(child.name)] = child

	var missing := 0
	var uv_mismatches := 0
	var index_mismatches := 0
	var texture_mismatches := 0
	var aabb_mismatches := 0
	var compared := 0
	for id in core_model.get_meshes():
		var key := String(id)
		if not ayagami_meshes.has(key):
			missing += 1
			continue
		var core_instance: MeshInstance2D = core_model.get_meshes()[id]
		var ayagami_instance: MeshInstance2D = ayagami_meshes[key]
		var core_arrays: Array = core_instance.mesh.surface_get_arrays(0)
		var ayagami_arrays: Array = ayagami_instance.mesh.surface_get_arrays(0)
		if not _vectors_equal_approx(
			core_arrays[Mesh.ARRAY_TEX_UV], ayagami_arrays[Mesh.ARRAY_TEX_UV]
		):
			uv_mismatches += 1
		if core_arrays[Mesh.ARRAY_INDEX] != ayagami_arrays[Mesh.ARRAY_INDEX]:
			index_mismatches += 1
		var core_texture: Texture2D = core_instance.material.get_shader_parameter("tex_main")
		if core_texture == null or ayagami_instance.texture == null \
			or core_texture.resource_path != ayagami_instance.texture.resource_path:
			texture_mismatches += 1
		var core_aabb: AABB = core_instance.mesh.get_custom_aabb()
		var ayagami_aabb: AABB = ayagami_instance.mesh.get_custom_aabb()
		var expected := ayagami_aabb
		if not core_aabb.is_equal_approx(expected):
			aabb_mismatches += 1
		compared += 1

	print(
		"AYAGAMI_CORE_MESH_COMPARE compared=%d missing=%d aabb=%d uv=%d indices=%d textures=%d"
		% [compared, missing, aabb_mismatches, uv_mismatches, index_mismatches, texture_mismatches]
	)
	quit(0)
