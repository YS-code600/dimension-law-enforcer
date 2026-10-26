extends Node2D
## 主菜单背景总控:天空渐变 + 霓虹月亮 + 程序化城市 + 雨/粒子 + 少女立绘。


func _ready() -> void:
	var sky: TextureRect = %SkyRect
	if sky:
		sky.texture = _make_sky()
	get_viewport().size_changed.connect(_on_resized)


func _on_resized() -> void:
	var city: Node2D = %City
	var weather: Node2D = %Weather
	if city and city.has_method("regen"):
		city.regen()
	if weather and weather.has_method("regen"):
		weather.regen()


func _make_sky() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	g.colors = PackedColorArray([
		Color("#030308"),
		Color("#0a0a1e"),
		Color("#0d0d28"),
		Color("#08081a"),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t
