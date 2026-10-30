extends Node2D
## 混沌爆炎的火球:朝指定方向直线飞行,命中敌人造成高额伤害。
## 素材复用 Boss 第 5 阶段的那张火球条(4 帧 128x128)。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const FRAMES_PATH := "res://levels/boss/fireball_frames.png"
const DAMAGE := 5
const SPEED := 620.0
const LIFETIME := 1.8
const HIT_RADIUS := 24.0
const SPRITE_SCALE := 1.5
## 让火球头部(而不是整张 128 格子的中心)落在节点原点,转向时才不歪
const SPRITE_OFFSET := Vector2(38.0, -2.0)
const ENEMY_LAYER := 4

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
		{"anim": &"fly", "path": FRAMES_PATH, "fps": 16.0, "loop": true},
	])
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.offset = SPRITE_OFFSET
	add_child(_sprite)
	_sprite.play(&"fly")

	_area = Area2D.new()
	_area.name = "Hitbox"
	_area.collision_layer = 0
	_area.collision_mask = ENEMY_LAYER
	_area.monitoring = true
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)
	_area.area_entered.connect(_on_area_entered)
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


func _on_area_entered(area: Area2D) -> void:
	if _dead or area == null:
		return
	_hit_target(area.get_parent())


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	_hit_target(body)


func _hit_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("take_hit"):
		return
	# 延迟一帧再结算:命中回调发生在物理查询刷新期间,直接改场景(掉 token)会报错
	target.call_deferred("take_hit", PlayerStats.hit(_damage), int(signf(_dir.x)), 320.0, -60.0)
	pop()


## 命中 / 超时:放大淡出销毁。
func pop() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	if _area != null:
		_area.set_deferred("monitorable", false)
		_area.set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.18)
	tw.chain().tween_callback(queue_free)
