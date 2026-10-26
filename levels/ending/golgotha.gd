extends Control
## 结局场景:监控画面里的孤石方碑(golgotha)。
## 字幕浮现 → 闪烁三下 → 切入火雨房间,主角与衍月在那里重新登场。
## 场景里的 Subtitle / Flash 若缺失(例如被外部工具覆盖),脚本会在运行时补建。

const NEXT_SCENE := "res://levels/fire_room.tscn"
const SUBTITLE_TEXT := "...我们的道路并不相同..."

@onready var _monolith: TextureRect = $Monolith
@onready var _fade: ColorRect = $Fade

var _subtitle: Label
var _flash: ColorRect
var _leaving := false
var _intro_tween: Tween


func _ready() -> void:
	_subtitle = _ensure_subtitle()
	_flash = _ensure_flash()
	_flash.color.a = 0.0
	_fade.color.a = 1.0
	await get_tree().process_frame
	_monolith.pivot_offset = _monolith.size * 0.5
	_monolith.scale = Vector2(1.06, 1.06)
	var zoom := create_tween()
	zoom.tween_property(_monolith, "scale", Vector2.ONE, 9.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween = create_tween()
	_intro_tween.tween_property(_fade, "color:a", 0.0, 2.0)
	_run_ending()


func _run_ending() -> void:
	# 石碑显现后再浮出字幕
	await get_tree().create_timer(2.2).timeout
	if _leaving:
		return
	var tw := create_tween()
	tw.tween_property(_subtitle, "modulate:a", 1.0, 1.0)
	await get_tree().create_timer(2.6).timeout
	_flash_out()


## 闪烁三下,然后白场切入火雨房间。
func _flash_out() -> void:
	if _leaving:
		return
	_leaving = true
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	for i in 3:
		_flash.color.a = 0.85
		await get_tree().create_timer(0.1).timeout
		_flash.color.a = 0.0
		await get_tree().create_timer(0.12).timeout
	_flash.color.a = 1.0
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_flash_out()


func _ensure_subtitle() -> Label:
	var existing := get_node_or_null("Subtitle") as Label
	if existing == null:
		existing = Label.new()
		existing.name = "Subtitle"
		existing.anchor_top = 1.0
		existing.anchor_right = 1.0
		existing.anchor_bottom = 1.0
		existing.offset_top = -58.0
		existing.offset_bottom = -18.0
		existing.grow_horizontal = Control.GROW_DIRECTION_BOTH
		existing.grow_vertical = Control.GROW_DIRECTION_BEGIN
		existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		existing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.add_theme_color_override("font_color", Color(0.84, 0.88, 0.94))
		existing.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		existing.add_theme_constant_override("outline_size", 6)
		existing.add_theme_font_size_override("font_size", 22)
		add_child(existing)
	if existing.text.is_empty():
		existing.text = SUBTITLE_TEXT
	existing.modulate.a = 0.0
	return existing


func _ensure_flash() -> ColorRect:
	var existing := get_node_or_null("Flash") as ColorRect
	if existing == null:
		existing = ColorRect.new()
		existing.name = "Flash"
		existing.color = Color(1.0, 0.97, 0.92, 0.0)
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(existing)
	return existing
