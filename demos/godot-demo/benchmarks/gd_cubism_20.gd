extends Node2D

const MODEL_PATH := "res://assets/live2d/mao/runtime/mao_pro.model3.json"
const DEFAULT_MODEL_COUNT := 20
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const WARMUP_SECONDS := 5.0
const SAMPLE_SECONDS := 15.0

var _models: Array[GDCubismUserModel] = []
var _model_count := DEFAULT_MODEL_COUNT
var _columns := 5
var _rows := 4
var _elapsed := 0.0
var _sampling := false
var _sample_started_usec := 0
var _frame_started_usec := 0
var _frame_times_ms: Array[float] = []
var _mask_sizes: Dictionary = {}
var _mask_resizes := 0
var _sample_seconds := SAMPLE_SECONDS


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--models="):
			_model_count = maxi(int(argument.trim_prefix("--models=")), 1)
		if argument.begins_with("--seconds="):
			_sample_seconds = maxf(float(argument.trim_prefix("--seconds=")), 1.0)
	_columns = mini(5, _model_count)
	_rows = ceili(float(_model_count) / _columns)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(VIEWPORT_SIZE)

	for index in _model_count:
		var model := GDCubismUserModel.new()
		model.name = "Mao%02d" % index
		add_child(model)
		model.assets = MODEL_PATH
		model.playback_process_mode = GDCubismUserModel.IDLE
		_layout_model(model, index)
		model.start_motion_loop("Idle", 0, GDCubismUserModel.PRIORITY_FORCE, true, true)
		_models.append(model)

	print("BENCHMARK_READY renderer=%s models=%d size=%dx%d warmup_s=%.1f sample_s=%.1f" % [
		RenderingServer.get_current_rendering_driver_name(), _model_count,
		int(VIEWPORT_SIZE.x), int(VIEWPORT_SIZE.y), WARMUP_SECONDS, _sample_seconds
	])


func _process(delta: float) -> void:
	_elapsed += delta
	var now := Time.get_ticks_usec()
	for model in _models:
		for child in model.get_children():
			if child is SubViewport:
				var key := child.get_instance_id()
				if _sampling and _mask_sizes.has(key) and _mask_sizes[key] != child.size:
					_mask_resizes += 1
				_mask_sizes[key] = child.size

	if not _sampling:
		if _elapsed >= WARMUP_SECONDS:
			_sampling = true
			_sample_started_usec = now
			_frame_started_usec = now
			print("BENCHMARK_SAMPLE_BEGIN")
		return

	if _frame_started_usec > 0:
		_frame_times_ms.append(float(now - _frame_started_usec) / 1000.0)
	_frame_started_usec = now

	if float(now - _sample_started_usec) >= _sample_seconds * 1_000_000.0:
		_finish_benchmark(now)


func _layout_model(model: GDCubismUserModel, index: int) -> void:
	var info: Dictionary = model.get_canvas_info()
	if info.is_empty():
		push_error("No canvas info for model %d" % index)
		return

	var cell_size := Vector2(VIEWPORT_SIZE.x / _columns, VIEWPORT_SIZE.y / _rows)
	var source_size: Vector2 = info.size_in_pixels
	var fit_scale := minf((cell_size.x * 0.92) / source_size.x, (cell_size.y * 0.92) / source_size.y)
	var column := index % _columns
	var row := index / _columns
	model.position = Vector2((column + 0.5) * cell_size.x, (row + 0.5) * cell_size.y)
	model.scale = Vector2.ONE * fit_scale


func _finish_benchmark(now_usec: int) -> void:
	set_process(false)
	_frame_times_ms.sort()
	var seconds := float(now_usec - _sample_started_usec) / 1_000_000.0
	var frames := _frame_times_ms.size()
	var average_fps := float(frames) / seconds
	var mask_pixels := 0
	for size in _mask_sizes.values():
		mask_pixels += size.x * size.y
	var result := {
		"implementation": "gd_cubism",
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"model": "mao_pro",
		"models": _model_count,
		"width": int(VIEWPORT_SIZE.x),
		"height": int(VIEWPORT_SIZE.y),
		"sample_seconds": seconds,
		"frames": frames,
		"average_fps": average_fps,
		"mask_count": _mask_sizes.size(),
		"mask_pixels": mask_pixels,
		"mask_resizes_during_sample": _mask_resizes,
		"p50_frame_ms": _percentile(0.50),
		"p95_frame_ms": _percentile(0.95),
		"p99_frame_ms": _percentile(0.99),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
	}
	print("BENCHMARK_RESULT %s" % JSON.stringify(result))
	var result_file := FileAccess.open("res://artifacts/benchmarks/latest.json", FileAccess.WRITE)
	if result_file:
		result_file.store_string(JSON.stringify(result, "\t"))
	get_viewport().get_texture().get_image().save_png("res://artifacts/benchmarks/latest.png")
	get_tree().quit()


func _percentile(fraction: float) -> float:
	if _frame_times_ms.is_empty():
		return 0.0
	var index := mini(int(ceil(fraction * _frame_times_ms.size())) - 1, _frame_times_ms.size() - 1)
	return _frame_times_ms[maxi(index, 0)]
