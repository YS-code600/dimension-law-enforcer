extends Node2D
## 赛博雨 + 漂浮霓虹粒子。

var _drops: Array[Dictionary] = []
var _parts: Array[Dictionary] = []


func _ready() -> void:
	regen()


func regen() -> void:
	_drops.clear()
	_parts.clear()
	var vp := get_viewport_rect()
	var W := vp.size.x
	var H := vp.size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path()) ^ int(Time.get_ticks_msec())
	for i in range(400):
		_drops.append({
			"x": rng.randf() * W,
			"y": rng.randf() * H,
			"speed": 4.0 + rng.randf() * 12.0,
			"len": 8.0 + rng.randf() * 18.0,
			"alpha": 0.1 + rng.randf() * 0.4,
		})
	for i in range(30):
		_parts.append({
			"x": rng.randf() * W,
			"y": rng.randf() * H,
			"vx": (rng.randf() - 0.5) * 0.5,
			"vy": -0.2 - rng.randf() * 0.5,
			"size": 1.0 + rng.randf() * 2.0,
			"color": Color("#ff3366") if rng.randf() < 0.5 else Color("#00ffff"),
			"alpha": 0.2 + rng.randf() * 0.5,
		})


func _process(delta: float) -> void:
	var vp := get_viewport_rect()
	var W := vp.size.x
	var H := vp.size.y
	# 雨(参考≈每 16ms 帧:竖直速度 4..16 px,横飘 1.2 px)
	var frame := delta * 62.5
	for d in _drops:
		d.y += d.speed * frame
		d.x += 1.2 * frame
		if d.y > H + 20.0:
			d.y = -20.0 - randf() * 20.0
			d.x = randf() * W
		if d.x > W + 10.0:
			d.x = -10.0
	# 粒子
	for p in _parts:
		p.x += p.vx * frame
		p.y += p.vy * frame
		if p.y < -10.0:
			p.y = H + 10.0
			p.x = randf() * W
		if p.x < -10.0:
			p.x = W + 10.0
		elif p.x > W + 10.0:
			p.x = -10.0
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for d in _drops:
		draw_line(Vector2(d.x, d.y), Vector2(d.x + 1.5, d.y + d.len),
			Color(0.47, 0.63, 0.78, d.alpha), 1.0, true)
	for p in _parts:
		var a := p.alpha * (0.6 + 0.4 * sin(t / 0.3 + p.x))
		var pc: Color = p.color
		draw_rect(Rect2(p.x, p.y, p.size, p.size), Color(pc.r, pc.g, pc.b, maxf(0.0, a)))
