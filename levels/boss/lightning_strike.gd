extends Node2D
## 雷击:先在目标位置画一条蓝色预警线,延迟后落雷;只造成一次伤害。

const TEXTURE_PATH := "res://picture/boss/fx_lightning.png"
const DAMAGE := 16

var _delay := 0.55
var _t := 0.0
var _struck := false
var _hit := false
var _fading := false
var _telegraph: ColorRect
var _sprite: Sprite2D
var _area: Area2D


func _ready() -> void:
	z_index = 12
	_telegraph = ColorRect.new()
	_telegraph.color = Color(0.35, 0.75, 1.0, 0.35)
	_telegraph.position = Vector2(-3.0, -600.0)
	_telegraph.size = Vector2(6.0, 600.0)
	_telegraph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_telegraph)

	var tex := _load_texture(TEXTURE_PATH)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -280.0)
	_sprite.scale = Vector2(3.6, 5.6)
	_sprite.modulate.a = 0.0
	_sprite.z_index = 12
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite.material = mat
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100.0, 600.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -300.0)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func setup(delay: float) -> void:
	_delay = maxf(delay, 0.05)


func _process(delta: float) -> void:
	_t += delta
	if not _struck:
		_telegraph.color.a = 0.18 + 0.3 * absf(sin(_t * 18.0))
		if _t >= _delay:
			_strike()
		return
	if _t > _delay + 0.55 and not _fading:
		_fading = true
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)


func _strike() -> void:
	_struck = true
	_telegraph.visible = false
	_sprite.modulate.a = 1.0
	_sprite.scale = Vector2(3.6, 5.6)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(4.2, 6.3), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_area.monitoring = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_camera_shake"):
		player.call("add_camera_shake", 1.0)
	_flash_screen()
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


func _flash_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.72, 0.9, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.32, 0.05)
	tw.tween_property(flash, "color:a", 0.0, 0.24)
	tw.tween_callback(layer.queue_free)


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
