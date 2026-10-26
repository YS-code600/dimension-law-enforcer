extends Node2D
## 程序化赛博都市:深浅建筑 + 彩色闪烁窗户 + 天线霓虹点 + 霓虹招牌 + 地面反光。

const WINDOW_COLORS := [
	Color("#ff3366"), Color("#00ffff"), Color("#ffcc00"),
	Color("#aaccff"), Color("#ffffff"),
]
const NEON_TEXTS := ["CYBER", "BAR", "HOTEL", "NET", "GAME", "DREAM", "愛", "電脳"]

var _buildings: Array[Dictionary] = []
var _fog_tex: GradientTexture2D
var _refl_tex: GradientTexture2D
var _font: SystemFont


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC", "WenQuanYi Micro Hei"])
	_fog_tex = _build_fog()
	_refl_tex = _build_refl()
	regen()


func regen() -> void:
	_buildings.clear()
	var vp := get_viewport_rect()
	var W := vp.size.x
	var H := vp.size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path())
	var x := -60.0
	while x < W + 80.0:
		var bw := 60.0 + rng.randf() * 150.0
		var bh := 80.0 + rng.randf() * 380.0
		var depth := rng.randf()
		var windows: Array = []
		var col_step := 14.0
		var row_step := 18.0
		for cx in range(int(bw / col_step)):
			for cy in range(int(bh / row_step)):
				if rng.randf() < 0.28:
					windows.append({
						"x": cx * col_step,
						"y": cy * row_step,
						"w": 3.0 + rng.randf() * 4.0,
						"h": 4.0 + rng.randf() * 3.0,
						"color": WINDOW_COLORS[rng.randi_range(0, WINDOW_COLORS.size() - 1)],
						"alpha": 0.3 + rng.randf() * 0.7,
						"flick": 0.5 + rng.randf() * 2.0,
					})
		var neon: Dictionary = {}
		if rng.randf() < 0.35:
			neon = {
				"dx": rng.randf() * bw * 0.6 + 10.0,
				"dy": 25.0 + rng.randf() * maxf(50.0, bh - 50.0),
				"text": NEON_TEXTS[rng.randi_range(0, NEON_TEXTS.size() - 1)],
				"color": Color("#ff3366") if rng.randf() < 0.5 else Color("#00ffff"),
				"size": 12.0 + rng.randf() * 18.0,
				"flick": 0.3 + rng.randf() * 2.0,
			}
		_buildings.append({
			"x": x, "w": bw, "h": bh, "depth": depth,
			"windows": windows, "neon": neon,
			"antenna": rng.randf() < 0.3,
		})
		x += bw + 2.0


func _build_fog() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.04, 0.04, 0.12, 0.0), Color(0.04, 0.04, 0.12, 0.6)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t


func _build_refl() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.2, 0.4, 0.0), Color(1.0, 0.2, 0.4, 0.09)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect()
	var W := vp.size.x
	var H := vp.size.y
	var t := Time.get_ticks_msec() / 1000.0

	# 远处雾
	if _fog_tex:
		draw_texture_rect(_fog_tex, Rect2(0.0, H * 0.5, W, H * 0.5), false)

	var arr := _buildings.duplicate()
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for b in arr:
		var bx: float = b.x
		var bw: float = b.w
		var bh: float = b.h
		var by := H - bh
		var base := int(8.0 + b.depth * 8.0)
		var col := Color(base / 255.0, base / 255.0, (base * 1.5) / 255.0)
		draw_rect(Rect2(bx, by, bw, bh), col)
		if b.depth > 0.5:
			draw_rect(Rect2(bx, by, 2.0, bh), Color(0.0, 1.0, 1.0, 0.08))
			draw_rect(Rect2(bx + bw - 2.0, by, 2.0, bh), Color(0.0, 1.0, 1.0, 0.08))
		if b.antenna:
			var ax := bx + bw / 2.0
			draw_rect(Rect2(ax - 1.0, by - 15.0, 2.0, 15.0), Color(0.1, 0.1, 0.19))
			draw_rect(Rect2(ax - 2.0, by - 18.0, 4.0, 3.0), Color(1.0, 0.2, 0.4, 0.9))
		# 窗户
		for win in b.windows:
			var flick := 0.7 + 0.3 * sin(t / (0.5 * win.flick) + bx * 0.01)
			var wc: Color = win.color
			draw_rect(Rect2(bx + win.x + 5.0, by + win.y + 5.0, win.w, win.h),
				Color(wc.r, wc.g, wc.b, win.alpha * flick))
		# 霓虹招牌
		if not b.neon.is_empty():
			_draw_neon(Vector2(bx + b.neon.dx, by + b.neon.dy), b.neon.text, b.neon.color, b.neon.size, t / (0.4 * b.neon.flick))

	# 地面
	draw_rect(Rect2(0.0, H - 12.0, W, 12.0), Color(0.016, 0.016, 0.05))
	if _refl_tex:
		draw_texture_rect(_refl_tex, Rect2(0.0, H - 80.0, W, 80.0), false)
	# 地面霓虹反射线
	for k in range(5):
		var ly := H - 12.0 - float(k) * 2.0
		draw_line(Vector2(0.0, ly), Vector2(W, ly), Color(0.0, 1.0, 1.0, 0.15), 1.0, true)


func _draw_neon(pos: Vector2, text: String, color: Color, size: float, flick: float) -> void:
	var a := 0.55 + 0.45 * sin(flick * 6.28 + pos.x * 0.05)
	a = maxf(0.3, a)
	# 光晕(多次偏移)
	for k in range(4, 0, -1):
		var o := float(k) * 2.5
		var ga := 0.05 * float(5 - k)
		_draw_text_glow(pos + Vector2(o, 0.0), text, Color(color.r, color.g, color.b, ga), size)
		_draw_text_glow(pos - Vector2(o, 0.0), text, Color(color.r, color.g, color.b, ga), size)
		_draw_text_glow(pos + Vector2(0.0, o), text, Color(color.r, color.g, color.b, ga), size)
		_draw_text_glow(pos - Vector2(0.0, o), text, Color(color.r, color.g, color.b, ga), size)
	_draw_text_glow(pos, text, Color(color.r, color.g, color.b, a), size)


func _draw_text_glow(pos: Vector2, text: String, color: Color, size: float) -> void:
	if _font:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), color)
