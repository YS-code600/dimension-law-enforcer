extends CanvasLayer
## 敌对衍月的血条。整块 UI 在运行时构建,场景文件里没有对应节点也能显示。

const BAR_WIDTH := 424.0
const FILL_COLOR := Color(0.95, 0.24, 0.28)
const FRAME_COLOR := Color(0.04, 0.02, 0.05, 0.9)
const FONT_NAMES := ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"]

var _root: Control
var _name: Label
var _value: Label
var _fill: ColorRect
var _boss: Node


func _ready() -> void:
	_ensure_ui()


func bind(boss: Node, title := "衍月") -> void:
	if boss == null:
		return
	_ensure_ui()
	_boss = boss
	_name.text = title
	if boss.has_signal("health_changed") and not boss.health_changed.is_connected(_on_health_changed):
		boss.connect("health_changed", _on_health_changed)
	if boss.has_signal("defeated") and not boss.defeated.is_connected(_on_defeated):
		boss.connect("defeated", _on_defeated)
	if boss.has_signal("revived") and not boss.revived.is_connected(_on_revived):
		boss.connect("revived", _on_revived)
	var hp := 0
	if boss.has_method("health_now"):
		hp = int(boss.call("health_now"))
	_apply(hp, int(boss.get("max_health")))
	_root.visible = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.4)


func _ensure_ui() -> void:
	if _root != null:
		return
	# 场景里若有旧的 Root 节点则隐藏,统一用运行时构建的这套
	var legacy := get_node_or_null("Root")
	if legacy != null:
		legacy.set_visible(false)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)

	_root = Control.new()
	_root.name = "BossRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_root.offset_bottom = 76.0
	_root.visible = false
	add_child(_root)

	var frame := ColorRect.new()
	frame.name = "Frame"
	frame.color = FRAME_COLOR
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.offset_left = -214.0
	frame.offset_right = 214.0
	frame.offset_top = 24.0
	frame.offset_bottom = 50.0
	_root.add_child(frame)

	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = FILL_COLOR
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.offset_left = 2.0
	_fill.offset_top = 4.0
	_fill.offset_right = 426.0
	_fill.offset_bottom = 22.0
	frame.add_child(_fill)

	_name = Label.new()
	_name.name = "Name"
	_name.text = "衍月"
	_name.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_name.offset_left = -214.0
	_name.offset_right = 0.0
	_name.offset_top = 0.0
	_name.offset_bottom = 22.0
	_style_label(_name, font, Color(1.0, 0.72, 0.72), HORIZONTAL_ALIGNMENT_LEFT)
	_root.add_child(_name)

	_value = Label.new()
	_value.name = "HPValue"
	_value.text = "300 / 300"
	_value.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_value.offset_left = 0.0
	_value.offset_right = 214.0
	_value.offset_top = 0.0
	_value.offset_bottom = 22.0
	_style_label(_value, font, Color(0.95, 0.78, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
	_root.add_child(_value)


func _style_label(label: Label, font: Font, color: Color, align: int) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_health_changed(current: int, maximum: int) -> void:
	_apply(current, maximum)
	if _fill == null:
		return
	_fill.color = Color(1.0, 0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(_fill, "color", FILL_COLOR, 0.18)


func _apply(current: int, maximum: int) -> void:
	if _fill == null or _value == null:
		return
	var ratio := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	_fill.offset_right = _fill.offset_left + BAR_WIDTH * ratio
	_value.text = "%d / %d" % [current, maximum]


func _on_defeated() -> void:
	if _root == null:
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _root.visible = false)


func _on_revived() -> void:
	if _root == null:
		return
	_root.visible = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)
