extends Node2D
## 空间爆炸:第 4 阶段起由 Boss 每 3 秒在场地随机位置引爆。
## 先亮一圈预警(可跑开),随后炸开;炸开期间碰到主角扣 DAMAGE 点血,每颗只结算一次。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const FRAMES_PATH := "res://levels/boss/space_explosion_frames.png"
const DAMAGE := 4
## 预警时长(秒)
const TELEGRAPH_TIME := 0.75
## 伤害半径 = 爆炸贴图最大帧的一半(80*1.8/2 ≈ 72)
const HIT_RADIUS := 72.0
const SPRITE_SCALE := 1.8
const SPRITE_LIFT := -30.0
## 炸开后还持续判定多久
const BURN_TIME := 0.35

var _delay := TELEGRAPH_TIME
var _t := 0.0
var _blown := false
var _hit := false
var _sprite: AnimatedSprite2D
var _area: Area2D


func _ready() -> void:
	z_index = 8
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Boom"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = STRIPS.build([
		{"anim": &"boom", "path": FRAMES_PATH, "fps": 13.0, "loop": false},
	])
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.offset = Vector2(0.0, SPRITE_LIFT * SPRITE_SCALE * 0.5)
	_sprite.visible = false
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	shape.position = Vector2(0.0, -20.0)
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	queue_redraw()


## 由 Boss 调用;delay 用来错峰连续爆炸。
func setup(delay: float) -> void:
	_delay = maxf(delay, 0.05)


func _process(delta: float) -> void:
	if _blown:
		return
	_t += delta
	if _t >= _delay:
		_blow()
		return
	queue_redraw()


## 地面预警圈:压扁的红色光圈,越接近引爆闪得越快。
func _draw() -> void:
	if _blown:
		return
	var pulse := 0.35 + 0.4 * absf(sin(_t * 10.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, HIT_RADIUS, Color(1.0, 0.35, 0.18, 0.08 + 0.10 * pulse))
	draw_arc(Vector2.ZERO, HIT_RADIUS, 0.0, TAU, 44,
		Color(1.0, 0.58, 0.26, 0.5 + 0.45 * pulse), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _blow() -> void:
	_blown = true
	# 清掉画上去的预警圈
	queue_redraw()
	_sprite.visible = true
	_sprite.play(&"boom")
	_area.monitoring = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("add_camera_shake"):
		player.call("add_camera_shake", 0.9)
	for body in _area.get_overlapping_bodies():
		_hit_body(body)
	await get_tree().create_timer(BURN_TIME).timeout
	if not is_inside_tree():
		return
	_area.monitoring = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	_hit_body(body)


func _hit_body(body: Node) -> void:
	if _hit or not _blown:
		return
	if not body.is_in_group("player"):
		return
	_hit = true
	if body.has_method("take_damage"):
		body.call("take_damage", DAMAGE, global_position)
