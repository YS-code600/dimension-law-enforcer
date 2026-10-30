extends Node2D
## 火焰弹:第 5 阶段 Boss 连续射出的火球。朝指定方向直线飞行,命中主角造成伤害。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const FRAMES_PATH := "res://levels/boss/fireball_frames.png"
const DAMAGE := 8
const SPEED := 300.0
const LIFETIME := 4.0
const HIT_RADIUS := 22.0
const SPRITE_SCALE := 1.4
## 让火球的头部(而不是整张 128 格子的中心)落在节点原点,转向时才不歪
const SPRITE_OFFSET := Vector2(38.0, -2.0)

var _dir := Vector2.RIGHT
var _damage := DAMAGE
var _life := LIFETIME
var _dead := false
var _sprite: AnimatedSprite2D
var _area: Area2D


func _ready() -> void:
	z_index = 9
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Flame"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = STRIPS.build([
		{"anim": &"fly", "path": FRAMES_PATH, "fps": 14.0, "loop": true},
	])
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.offset = SPRITE_OFFSET
	add_child(_sprite)
	_sprite.play(&"fly")

	_area = Area2D.new()
	_area.name = "Hitbox"
	_area.collision_layer = 16
	_area.collision_mask = 1
	_area.monitoring = true
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


## dir:飞行方向(贴图同时转向该方向);damage:命中伤害。
func setup(dir: Vector2, damage := DAMAGE) -> void:
	_dir = dir.normalized()
	_damage = maxi(1, damage)
	rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += _dir * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		pop()


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", _damage, global_position)
	pop()


## 命中 / 超时:缩一下淡出销毁。
func pop() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	_area.set_deferred("monitorable", false)
	_area.set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.18)
	tw.chain().tween_callback(queue_free)
