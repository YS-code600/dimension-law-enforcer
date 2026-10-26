extends Node2D
## 动态光带层（原 .gif 图层的位置）：项目里没有现成素材，
## 改为程序化绘制横向流动的光点。

@export var streak_count: int = 6
@export var speed: float = 26.0
@export var streak_color: Color = Color(0.55, 0.85, 1.0, 0.7)
@export var height_min: float = 0.32
@export var height_max: float = 0.58

var _progress: PackedFloat32Array = PackedFloat32Array()
var _heights: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in streak_count:
		_progress.append(rng.randf())
		_heights.append(rng.randf_range(height_min, height_max))
	queue_redraw()


func _process(delta: float) -> void:
	var view_width: float = max(get_viewport_rect().size.x, 1.0)
	for i in _progress.size():
		_progress[i] = fmod(_progress[i] + speed * delta / view_width, 1.0)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	for i in _progress.size():
		var start := Vector2(_progress[i] * view.x, _heights[i] * view.y)
		for k in 6:
			var fade := 1.0 - k * 0.16
			var color := Color(streak_color.r, streak_color.g, streak_color.b, streak_color.a * fade)
			draw_rect(Rect2(start.x - k * 16.0, start.y, 14.0, 2.0), color)
