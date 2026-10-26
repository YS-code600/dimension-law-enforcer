extends Node2D
## 弹反圆环:主角按下 S 时在身前炸开的一圈蓝色光环。
## 纯代码绘制三层同心圆线,0.5 秒内扩散并淡出,结束后自毁。

const RADIUS := 190.0
const LIFE := 0.5

var _lines: Array[Line2D] = []


func _ready() -> void:
	z_index = 6
	_lines.append(_make_ring(RADIUS, 22.0, Color(0.25, 0.62, 1.0, 0.10)))
	_lines.append(_make_ring(RADIUS, 8.0, Color(0.35, 0.80, 1.0, 0.95)))
	_lines.append(_make_ring(RADIUS * 0.72, 4.0, Color(0.80, 0.97, 1.0, 0.85)))
	_lines.append(_make_ring(RADIUS * 0.44, 2.0, Color(1.0, 1.0, 1.0, 0.6)))
	scale = Vector2(0.22, 0.22)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, LIFE).set_delay(0.14)
	tw.chain().tween_callback(queue_free)


func _make_ring(radius: float, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var points := PackedVector2Array()
	var segments := 72
	for i in segments + 1:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	line.points = points
	add_child(line)
	return line
