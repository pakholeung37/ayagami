extends Node2D

const MODEL_PATH := "res://assets/live2d/mao/runtime/mao_pro.model3.json"

@onready var background: ColorRect = $Background
@onready var motion_select: OptionButton = $UI/Panel/Margin/Controls/MotionSelect
@onready var expression_select: OptionButton = $UI/Panel/Margin/Controls/ExpressionSelect
@onready var status: Label = $UI/Panel/Margin/Controls/Status

var model: AyagamiModel
var motion_player: AnimationPlayer
var expression_controller: AyagamiExpressionMutator
var motions: Array[StringName] = []
var expressions: Array = []
var parameter_names: Array = []


func _ready() -> void:
	get_viewport().size_changed.connect(_layout_model)
	if not FileAccess.file_exists(MODEL_PATH):
		_show_error("Model not found:\n%s" % MODEL_PATH)
		return

	model = AyagamiLoader.load_model(MODEL_PATH)
	if model == null:
		_show_error("Ayagami could not load the model")
		return

	model.name = "AyagamiMao"
	add_child(model)
	await get_tree().process_frame

	parameter_names = model.get_parameters()
	_setup_motions()
	_setup_expressions()
	_layout_model()

	if not motions.is_empty():
		motion_player.play(motions[0])

	status.text = (
		"Ayagami loaded successfully\n"
		+ "%d parameters · %d meshes\n" % [parameter_names.size(), model.get_node("Meshes").get_child_count()]
		+ "%d motions · %d expressions" % [motions.size(), expressions.size()]
	)


func _process(_delta: float) -> void:
	if model == null:
		return

	var viewport_size := get_viewport_rect().size
	var pointer := get_viewport().get_mouse_position()
	var normalized := Vector2.ZERO
	var pointer_inside := Rect2(Vector2.ZERO, viewport_size).has_point(pointer)
	if get_window().has_focus() and pointer_inside:
		normalized = Vector2(
			clampf((pointer.x / maxf(viewport_size.x, 1.0)) * 2.0 - 1.0, -1.0, 1.0),
			clampf(-((pointer.y / maxf(viewport_size.y, 1.0)) * 2.0 - 1.0), -1.0, 1.0)
		)
	_set_parameter(&"ParamAngleX", normalized.x * 20.0)
	_set_parameter(&"ParamAngleY", normalized.y * 20.0)
	_set_parameter(&"ParamEyeBallX", normalized.x)
	_set_parameter(&"ParamEyeBallY", normalized.y)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not motions.is_empty():
		var index := randi_range(0, motions.size() - 1)
		motion_select.select(index)
		motion_player.play(motions[index])


func _setup_motions() -> void:
	motion_player = model.get_node("MotionController")
	var library := AyagamiLoader.load_motion_library(model)
	if motion_player.has_animation_library(""):
		motion_player.remove_animation_library("")
	motion_player.add_animation_library("", library)

	motion_select.clear()
	for animation in library.get_animation_list():
		if animation == &"RESET":
			continue
		motions.append(animation)
		motion_select.add_item(String(animation).trim_suffix(".motion3.json"))


func _setup_expressions() -> void:
	expression_controller = model.get_node("ExpressionController")
	var library := AyagamiLoader.load_expression_library(MODEL_PATH.get_base_dir(), true)
	expressions = library.keys()
	expression_controller.expressions = expressions

	expression_select.clear()
	for expression in expressions:
		var group: String = library[expression]
		expression_controller.set("expression_groups/%s" % expression.get_name(), group)
		expression_select.add_item(expression.get_name())


func _layout_model() -> void:
	var viewport_size := get_viewport_rect().size
	background.size = viewport_size
	if model == null:
		return

	var model_area := Vector2(maxf(viewport_size.x - 350.0, 100.0), viewport_size.y)
	var source_size := Vector2(model.size)
	var fit_scale := minf(model_area.x / source_size.x, (model_area.y * 0.92) / source_size.y)
	model.position = Vector2(model_area.x * 0.5, viewport_size.y * 0.52)
	model.scale = Vector2.ONE * fit_scale


func _set_parameter(parameter: StringName, value: float) -> void:
	if parameter in parameter_names:
		model.set("parameters/%s" % parameter, value)


func _on_play_motion_pressed() -> void:
	var index := motion_select.selected
	if motion_player != null and index >= 0 and index < motions.size():
		motion_player.play(motions[index])


func _on_apply_expression_pressed() -> void:
	var index := expression_select.selected
	if expression_controller == null or index < 0 or index >= expressions.size():
		return
	_reset_expressions()
	var expression = expressions[index]
	expression_controller.create_tween().tween_property(
		expression_controller,
		"weight/%s" % expression.get_name(),
		1.0,
		0.2
	)


func _on_clear_expression_pressed() -> void:
	_reset_expressions()


func _reset_expressions() -> void:
	if expression_controller == null:
		return
	var tween := expression_controller.create_tween().set_parallel(true)
	for expression in expressions:
		tween.tween_property(
			expression_controller,
			"weight/%s" % expression.get_name(),
			0.0,
			0.2
		)


func _show_error(message: String) -> void:
	status.text = message
	status.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
