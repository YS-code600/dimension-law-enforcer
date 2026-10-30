extends Panel
## 右上角的数值小面板:标题 + 数字,数值变化时数字跳动一下。
## 默认显示 Tokens 单例的数量;变强界面左上角和 HUD 的 EXP 条也复用它。

const PANEL_SIZE := Vector2(176.0, 40.0)

## 绑定的数据源(自动加载节点路径 / 属性名 / 标题)
var source_path := "/root/Tokens"
var source_property := "total"
var caption_text := "TOKEN"

var _caption: Label
var _value: Label
var _pop: Tween


## 由 HUD 调用:套用 HUD 的字体与面板样式。
func setup(style_source: Panel, font_source: Label) -> void:
	var style: StyleBox = null
	if style_source != null:
		style = style_source.get_theme_stylebox("panel")
	var font: Font = null
	if font_source != null:
		font = font_source.get_theme_font("font")
	build(style, font)


## 手动指定样式/字体;传 null 表示沿用当前主题(场景里已配置的样式或字体)。
func build(style: StyleBox, font: Font) -> void:
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style != null:
		add_theme_stylebox_override("panel", style)
	if _value == null:
		_build_labels()
	if font != null:
		_caption.add_theme_font_override("font", font)
		_value.add_theme_font_override("font", font)
	_bind_source()


func _build_labels() -> void:
	_caption = Label.new()
	_caption.name = "ValueCaption"
	_caption.text = caption_text
	_caption.position = Vector2(14.0, 9.0)
	_caption.size = Vector2(80.0, 20.0)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size", 14)
	_caption.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0, 0.9))
	add_child(_caption)

	_value = Label.new()
	_value.name = "ValueLabel"
	_value.text = "0"
	_value.position = Vector2(70.0, 4.0)
	_value.size = Vector2(92.0, 32.0)
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.add_theme_font_size_override("font_size", 22)
	_value.add_theme_color_override("font_color", Color(0.88, 1.0, 1.0, 1.0))
	_value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	_value.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_value)


func _bind_source() -> void:
	var source := get_node_or_null(source_path)
	if source == null:
		return
	if source.has_signal("changed") and not source.is_connected("changed", _on_value_changed):
		source.connect("changed", _on_value_changed)
	_refresh()


func _on_value_changed(_arg := 0) -> void:
	_refresh()


func _refresh() -> void:
	if _value == null:
		return
	var source := get_node_or_null(source_path)
	if source == null:
		return
	var raw: Variant = source.get(source_property)
	_value.text = str(int(raw)) if raw != null else "0"
	if not is_inside_tree():
		return
	if _pop != null and _pop.is_valid():
		_pop.kill()
	pivot_offset = PANEL_SIZE * 0.5
	scale = Vector2(1.14, 1.14)
	_pop = create_tween()
	_pop.tween_property(self, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
