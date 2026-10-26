extends CanvasLayer
## 衍月的台词气泡:黄色描边、黑色底、白色文字,显示 2 秒后自动消失。
## 整个 UI 在运行时构建,场景文件里没有对应节点也能用。

const DURATION := 2.0
const FONT_NAMES := ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"]

var _panel: PanelContainer
var _label: Label
var _timer := 0.0


func _ready() -> void:
	_ensure_ui()


## world_pos: 气泡的尖端对准的世界坐标(通常是角色头顶)。duration 为显示秒数。
func show_line(text: String, world_pos: Vector2, duration := DURATION) -> void:
	_ensure_ui()
	_label.text = text
	_panel.visible = true
	_panel.reset_size()
	await get_tree().process_frame
	var screen: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var view: Vector2 = get_viewport().get_visible_rect().size
	var x := clampf(screen.x - _panel.size.x * 0.5, 8.0, maxf(8.0, view.x - _panel.size.x - 8.0))
	var y := clampf(screen.y - _panel.size.y - 8.0, 8.0, maxf(8.0, view.y - _panel.size.y - 8.0))
	_panel.position = Vector2(x, y)
	_timer = maxf(duration, 0.2)


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0 and _panel != null:
		_panel.visible = false


func _ensure_ui() -> void:
	if _panel != null:
		return
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.015, 0.02, 0.92)
	style.border_color = Color(1.0, 0.85, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	_panel = PanelContainer.new()
	_panel.name = "Bubble"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)

	_label = Label.new()
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_panel.add_child(_label)
