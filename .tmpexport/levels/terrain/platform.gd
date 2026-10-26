extends StaticBody2D
## 地形组件:地板/平台(可单向往上穿过),运行时按导出尺寸生成碰撞体与外观。
## 表面花纹取自 material 图案集,裁切并镜像成可无缝平铺的贴图。

const PATTERNS: Array[Texture2D] = [
	preload("res://levels/terrain/floor_pattern_grid.png"),
	preload("res://levels/terrain/floor_pattern_lattice.png"),
]

@export var size := Vector2(128, 24)
@export var one_way := false
@export var body_color := Color(0.05, 0.06, 0.12)
@export var edge_color := Color(1.0, 0.6, 0.22, 0.9)
@export_enum("Circuit", "Lattice") var pattern_style := 0
@export var pattern_modulate := Color(0.62, 0.8, 1.0, 0.85)

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var rs := RectangleShape2D.new()
	rs.size = size
	_shape.shape = rs
	_shape.one_way_collision = one_way
	_shape.one_way_collision_margin = 3.0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rect := Rect2(-w / 2.0, -h / 2.0, w, h)
	var band_h := minf(h, 36.0)
	var band := Rect2(-w / 2.0, -h / 2.0, w, band_h)

	# 主体
	draw_rect(rect, body_color)

	# 顶部花纹带(图案取自 material,29px 无缝平铺)
	var pattern: Texture2D = PATTERNS[clampi(pattern_style, 0, PATTERNS.size() - 1)]
	draw_texture_rect(pattern, band, true, pattern_modulate)
	# 压暗纹理,保证角色与特效的对比度
	draw_rect(band, Color(body_color.r, body_color.g, body_color.b, 0.16))

	# 顶部发光条
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, 4.0), edge_color)
	draw_rect(Rect2(-w / 2.0, -h / 2.0, w, 1.0), Color(1.0, 0.95, 0.85, 0.85))

	# 厚地板:花纹带下缘的分界线
	if h > band_h + 2.0:
		draw_line(Vector2(-w / 2.0, -h / 2.0 + band_h), Vector2(w / 2.0, -h / 2.0 + band_h),
			Color(0.2, 0.38, 0.7, 0.45), 1.0)

	# 底部阴影(单向平台不画)
	if not one_way:
		draw_rect(Rect2(-w / 2.0, h / 2.0 - 3.0, w, 3.0), Color(0, 0, 0, 0.35))
