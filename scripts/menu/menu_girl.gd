extends Node2D
## 像素少女立绘(持枪) + 青色光晕 + 地面阴影 + 倒影。
## 由参考 UI 的 32x48 sprite 移植,支持任意倍率缩放。

var _glow_tex: GradientTexture2D
var _shadow_tex: GradientTexture2D


func _ready() -> void:
	_glow_tex = _radial(Color(0.35, 0.9, 1.0, 0.30), Color(0.35, 0.9, 1.0, 0.0))
	_shadow_tex = _radial(Color(0.0, 0.0, 0.0, 0.5), Color(0.0, 0.0, 0.0, 0.0))


func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([inner, outer])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _draw() -> void:
	var vp := get_viewport_rect()
	var W := vp.size.x
	var H := vp.size.y
	var s := float(clampi(int(floor(minf(W, H) / 120.0)), 3, 7))
	var gx := W / 2.0
	var gy := H * 0.40

	# 地面阴影
	draw_texture_rect(_shadow_tex, Rect2(gx - 14.0 * s, H - 15.0 - 6.0, 28.0 * s, 12.0), false, Color(1, 1, 1, 0.9))
	# 青色光晕
	draw_texture_rect(_glow_tex, Rect2(gx - 22.0 * s, gy - 26.0 * s, 44.0 * s, 52.0 * s), false)

	# 本体
	_draw_girl(gx - 16.0 * s, gy - 24.0 * s, s, 1.0)

	# 地面倒影(裁剪到地面下,透明度低)
	draw_set_transform(Vector2(0.0, H - 12.0), 0.0, Vector2(1.0, -0.3))
	_draw_girl(gx - 16.0 * s, gy - 24.0 * s, s, 0.15)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_girl(x: float, y: float, s: float, a: float) -> void:
	var C := func(c: Color, al: float) -> Color:
		return Color(c.r, c.g, c.b, c.a * al)
	var dark := Color(Color8(21, 21, 42))
	var hl := Color(Color8(42, 42, 74))
	var white := Color(Color8(232, 232, 232))
	var gray := Color(Color8(192, 192, 192))
	var skirt := Color(Color8(26, 26, 48))
	var shoe := Color(Color8(10, 10, 26))
	var gun := Color(Color8(192, 192, 192))
	var gun2 := Color(Color8(128, 128, 128))
	var gun3 := Color(Color8(232, 232, 232))

	# 丸子头
	draw_rect(Rect2(x + 12 * s, y, 8 * s, 3 * s), C(dark, a))
	draw_rect(Rect2(x + 10 * s, y + 3 * s, 12 * s, 3 * s), C(dark, a))
	draw_rect(Rect2(x + 11 * s, y + 6 * s, 10 * s, 2 * s), C(dark, a))
	draw_rect(Rect2(x + 14 * s, y + s, 3 * s, 2 * s), C(hl, a))
	# 长发
	draw_rect(Rect2(x + 5 * s, y + 8 * s, 5 * s, 24 * s), C(dark, a))
	draw_rect(Rect2(x + 22 * s, y + 8 * s, 5 * s, 24 * s), C(dark, a))
	draw_rect(Rect2(x + 8 * s, y + 10 * s, 16 * s, 4 * s), C(dark, a))
	draw_rect(Rect2(x + 4 * s, y + 28 * s, 4 * s, 5 * s), C(dark, a))
	draw_rect(Rect2(x + 24 * s, y + 28 * s, 4 * s, 5 * s), C(dark, a))
	draw_rect(Rect2(x + 6 * s, y + 12 * s, 2 * s, 15 * s), C(hl, a))
	draw_rect(Rect2(x + 24 * s, y + 12 * s, 2 * s, 15 * s), C(hl, a))
	# 上衣
	draw_rect(Rect2(x + 7 * s, y + 16 * s, 18 * s, 9 * s), C(white, a))
	draw_rect(Rect2(x + 7 * s, y + 22 * s, 18 * s, 3 * s), C(gray, a))
	draw_rect(Rect2(x + 13 * s, y + 16 * s, 6 * s, 5 * s), C(dark, a))
	draw_rect(Rect2(x + 11 * s, y + 16 * s, 10 * s, 2 * s), C(dark, a))
	# 短裙
	draw_rect(Rect2(x + 5 * s, y + 25 * s, 22 * s, 5 * s), C(skirt, a))
	draw_rect(Rect2(x + 7 * s, y + 30 * s, 18 * s, 3 * s), C(skirt, a))
	draw_rect(Rect2(x + 6 * s, y + 25 * s, 3 * s, 4 * s), C(hl, a))
	draw_rect(Rect2(x + 23 * s, y + 25 * s, 3 * s, 4 * s), C(hl, a))
	# 腿
	draw_rect(Rect2(x + 8 * s, y + 33 * s, 5 * s, 7 * s), C(dark, a))
	draw_rect(Rect2(x + 19 * s, y + 33 * s, 5 * s, 7 * s), C(dark, a))
	draw_rect(Rect2(x + 8 * s, y + 33 * s, 2 * s, 6 * s), C(hl, a))
	draw_rect(Rect2(x + 19 * s, y + 33 * s, 2 * s, 6 * s), C(hl, a))
	# 鞋
	draw_rect(Rect2(x + 6 * s, y + 40 * s, 7 * s, 3 * s), C(shoe, a))
	draw_rect(Rect2(x + 19 * s, y + 40 * s, 7 * s, 3 * s), C(shoe, a))
	draw_rect(Rect2(x + 5 * s, y + 42 * s, 9 * s, s), C(skirt, a))
	draw_rect(Rect2(x + 18 * s, y + 42 * s, 9 * s, s), C(skirt, a))
	# 枪(右手)
	draw_rect(Rect2(x + 22 * s, y + 18 * s, 10 * s, 3 * s), C(gun, a))
	draw_rect(Rect2(x + 29 * s, y + 16 * s, 3 * s, 7 * s), C(gun, a))
	draw_rect(Rect2(x + 24 * s, y + 19 * s, 5 * s, s), C(gun2, a))
	draw_rect(Rect2(x + 28 * s, y + 17 * s, 2 * s, 2 * s), C(gun2, a))
	draw_rect(Rect2(x + 22 * s, y + 18 * s, 3 * s, s), C(gun3, a))
