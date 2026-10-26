extends Node2D
## 衍月核心:研究员被击倒后在仪器右侧生成的光球。
## 主角靠近显示「Q 取得衍月核心」,按 Q 发出 collected 信号。

signal collected

const INTERACT_RADIUS := 120.0
const PROMPT_TEXT := "Q  取得衍月核心"

var _player: Node2D
var _prompt: Label
var _core: Sprite2D
var _halo: Sprite2D
var _time := 0.0
var _home_y := 0.0
var _taken := false


func _ready() -> void:
	z_index = 5
	_home_y = position.y
	_build_visual()
	_build_prompt()
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	var pulse := 1.0 + sin(_time * 3.4) * 0.08
	_core.scale = Vector2(pulse, pulse) * 0.9
	var halo_pulse := 1.0 + sin(_time * 2.2) * 0.12
	_halo.scale = Vector2(2.4, 2.4) * halo_pulse
	position.y = _home_y + sin(_time * 2.0) * 5.0

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var near := _player.global_position.distance_to(global_position) <= INTERACT_RADIUS
	_prompt.visible = near
	if near and Input.is_action_just_pressed("switch_dimension"):
		_collect()


func _collect() -> void:
	if _taken:
		return
	_taken = true
	_prompt.visible = false
	collected.emit()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(queue_free)


func _build_visual() -> void:
	_halo = Sprite2D.new()
	_halo.name = "Halo"
	_halo.texture = _make_glow_texture(
		Color(0.45, 0.82, 1.0, 0.45), Color(0.35, 0.75, 1.0, 0.18))
	_halo.scale = Vector2(2.4, 2.4)
	add_child(_halo)

	_core = Sprite2D.new()
	_core.name = "Core"
	_core.texture = _make_glow_texture(Color(0.55, 0.9, 1.0, 1.0), Color(0.25, 0.62, 0.95, 0.85))
	_core.scale = Vector2(0.9, 0.9)
	add_child(_core)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 3.0
	ring.default_color = Color(0.2, 0.55, 0.9, 0.9)
	ring.antialiased = true
	ring.closed = true
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		points.append(Vector2(cos(angle), sin(angle)) * 15.0)
	ring.points = points
	add_child(ring)


func _make_glow_texture(inner: Color, outer: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([inner, outer, Color(outer.r, outer.g, outer.b, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _build_prompt() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC",
		"Noto Sans CJK SC", "PingFang SC", "SimHei",
	])
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = PROMPT_TEXT
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.position = Vector2(-110.0, -92.0)
	_prompt.size = Vector2(220.0, 28.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", font)
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_color", Color(0.25, 0.55, 0.85, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	_prompt.z_index = 10
	add_child(_prompt)
