extends Node2D
## 潮汐水墙:从场地一侧横推过来,站在地面上会被冲伤;跳起来可以躲开。

const TEXTURE_PATH := "res://picture/boss/fx_water.png"
const SHADER_PATH := "res://shaders/water_scroll.gdshader"
const DAMAGE := 10
const SPEED := 280.0
const WIDTH := 360.0
const HEIGHT := 130.0

var _dir := 1.0
var _t := 0.0
var _hit := false
var _area: Area2D


func _ready() -> void:
	z_index = 7
	var tex := _load_texture(TEXTURE_PATH)
	var water := TextureRect.new()
	water.texture = tex
	water.position = Vector2(-WIDTH * 0.5, -HEIGHT)
	water.size = Vector2(WIDTH, HEIGHT)
	water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water.stretch_mode = TextureRect.STRETCH_TILE
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.z_index = 7
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	water.material = mat
	add_child(water)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = true
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, 110.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -55.0)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func setup(direction: float) -> void:
	_dir = 1.0 if direction >= 0.0 else -1.0


func _physics_process(delta: float) -> void:
	_t += delta
	position.x += _dir * SPEED * delta
	if _t > 5.0 or position.x < -420.0 or position.x > 1600.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _hit or not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.call("take_damage", DAMAGE, global_position + Vector2(-_dir * 80.0, 0.0))


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
