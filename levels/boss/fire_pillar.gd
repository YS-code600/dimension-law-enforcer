extends Node2D
## 火柱:先在地面画预警圈,延迟后喷发火焰;只造成一次伤害。

const TEXTURE_PATH := "res://picture/boss/fx_fire.png"
const DAMAGE := 12
const GROUND_RADIUS := 72.0

var _delay := 0.55
var _t := 0.0
var _erupted := false
var _hit := false
var _fading := false
var _sprites: Array[Sprite2D] = []
var _base_scales: Array[Vector2] = []
var _base_alphas: Array[float] = []
var _area: Area2D


func _ready() -> void:
	z_index = 6
	var tex := _load_texture(TEXTURE_PATH)
	_add_flame(tex, 0.0, 1.9, 1.0)
	_add_flame(tex, -38.0, 1.45, 0.55)
	_add_flame(tex, 38.0, 1.45, 0.55)
	_add_flame(tex, 0.0, 1.1, 0.35)
	for sprite in _sprites:
		_base_scales.append(sprite.scale)
		_base_alphas.append(sprite.modulate.a)
		sprite.modulate.a = 0.0
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(140.0, 200.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -100.0)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(delay: float) -> void:
	_delay = maxf(delay, 0.05)


func _add_flame(tex: Texture2D, x: float, scale: float, alpha: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = Vector2(x, -scale * 50.0)
	sprite.scale = Vector2(scale, scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(1, 1, 1, alpha)
	sprite.z_index = 6
	add_child(sprite)
	_sprites.append(sprite)


func _process(delta: float) -> void:
	_t += delta
	if not _erupted:
		if _t >= _delay:
			_erupt()
		else:
			queue_redraw()
		return
	# 火焰抖动
	var flicker := 0.82 + 0.18 * sin(_t * 34.0)
	for i in _sprites.size():
		_sprites[i].scale = _base_scales[i] * (0.96 + 0.04 * sin(_t * 18.0 + float(i)))
		_sprites[i].modulate.a = _base_alphas[i] * flicker
	if _t > _delay + 1.0 and not _fading:
		_fading = true
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.28)
		tw.chain().tween_callback(queue_free)


func _erupt() -> void:
	_erupted = true
	queue_redraw()
	_area.monitoring = true
	for i in _sprites.size():
		_sprites[i].modulate.a = _base_alphas[i]
		_sprites[i].scale = _base_scales[i] * Vector2(0.75, 0.2)
		var tw := create_tween()
		tw.tween_property(_sprites[i], "scale", _base_scales[i], 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_camera_shake"):
		player.call("add_camera_shake", 0.35)
	for body in _area.get_overlapping_bodies():
		_hit_body(body)


func _on_body_entered(body: Node) -> void:
	_hit_body(body)


func _hit_body(body: Node) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.call("take_damage", DAMAGE, global_position)


func _draw() -> void:
	if _erupted:
		return
	var pulse := 0.22 + 0.2 * absf(sin(_t * 12.0))
	draw_circle(Vector2.ZERO, GROUND_RADIUS, Color(1.0, 0.28, 0.05, 0.12))
	draw_arc(Vector2.ZERO, GROUND_RADIUS, 0.0, TAU, 40, Color(1.0, 0.48, 0.12, pulse), 3.0)


func _load_texture(path: String) -> Texture2D:
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null
