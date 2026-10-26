extends Node2D
## 同行缔结后的系统播报:在衍月头顶弹出打字机效果的文字气泡。
## 独立成组件,不改 violet_companion.gd(那份脚本会被 Team Create 覆盖)。

@export_multiline var message := "防火墙故障，有不明人员尝试访问系统内核"
## 每秒打出的字数。
@export var type_speed := 26.0
## 打完字后停留的秒数。
@export var hold_time := 3.2
@export var bubble_width := 340.0
## 气泡相对角色脚底的偏移。
@export var head_offset := Vector2(0.0, -178.0)

var _companion: Node
var _was_following := false
var _fired := false


func _ready() -> void:
	_companion = get_parent()
	if _companion != null and _companion.has_method("is_following"):
		_was_following = bool(_companion.call("is_following"))
	set_process(_companion != null)


func _process(_delta: float) -> void:
	if _fired or _companion == null or not is_instance_valid(_companion):
		return
	if not _companion.has_method("is_following"):
		return
	var following := bool(_companion.call("is_following"))
	if following and not _was_following:
		_say()
	_was_following = following


## 手动触发一次(方便调试或其他剧情节点调用)。
func say_once() -> void:
	_say()


func _say() -> void:
	if _fired:
		return
	_fired = true
	print(message)

	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC",
		"Noto Sans CJK SC", "PingFang SC", "SimHei",
	])

	var label := Label.new()
	label.name = "SystemLine"
	label.text = message
	label.position = head_offset + Vector2(-bubble_width * 0.5, 0.0)
	label.size = Vector2(bubble_width, 64.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.10, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	label.visible_characters = 0
	add_child(label)

	var chars := float(label.text.length())
	var type_time := maxf(0.35, chars / maxf(type_speed, 1.0))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 1.0, 0.18)
	tw.tween_property(label, "position:y", head_offset.y - 14.0, type_time + 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "visible_characters", int(chars), type_time)
	tw.chain().tween_interval(hold_time)
	tw.chain().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(label.queue_free)
