extends Control
## 红色警告三角:粗红边 + 半透明红填充 + 中间一个会呼吸的感叹号。
## 尺寸跟随自身 rect,所以直接改 Control 的 offset 就能缩放。

@export var line_color := Color(1.0, 0.16, 0.24, 1.0)
@export var fill_color := Color(1.0, 0.1, 0.18, 0.14)
@export var mark_color := Color(1.0, 0.24, 0.3, 1.0)
@export var line_width := 14.0

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var pad := line_width * 0.75
	var tri := PackedVector2Array([
		Vector2(w * 0.5, pad),
		Vector2(w - pad, h - pad),
		Vector2(pad, h - pad),
	])
	draw_colored_polygon(tri, fill_color)
	var outline := tri.duplicate()
	outline.append(tri[0])
	draw_polyline(outline, line_color, line_width, true)
	# 感叹号:轻微呼吸,像在报警。
	var pulse := 0.72 + 0.28 * sin(_time * 6.5)
	var cx := w * 0.5
	draw_line(Vector2(cx, h * 0.34), Vector2(cx, h * 0.6),
		Color(mark_color, pulse), line_width * 0.8, true)
	draw_circle(Vector2(cx, h * 0.72), line_width * 0.46, Color(mark_color, pulse))
