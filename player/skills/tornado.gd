extends Node2D
## 龙卷风(主动技能):在主角身上长起来,朝面向推进 Boss 房间宽度的 3/4。
## 期间清掉碰到的敌方弹幕,撞到的敌人每个打一次 250 点血。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const FRAMES_PATH := "res://player/skills/tornado_frames.png"
const DAMAGE := 250
## 火雨(Boss)房间宽度 1152,推进 3/4 = 864px
const ROOM_WIDTH := 1152.0
const TRAVEL_FRACTION := 0.75
## 先在主角身上慢慢长大(和主角锁 K 攻击动画的 2 秒同步),长满后再往前推进
const GROW_TIME := 2.0
const TRAVEL_TIME := 1.4
const START_SCALE := 0.8
const FULL_SCALE := 8.0
const ENEMY_LAYER := 4
const PROJECTILE_LAYER := 16
const DAMAGE_MASK := ENEMY_LAYER | PROJECTILE_LAYER
## 视觉中心相对节点原点(主角脚下)抬高
const CENTER_OFFSET := Vector2(0.0, -60.0)

var _dir := Vector2.RIGHT
var _damage := DAMAGE
var _speed := 0.0
var _t := 0.0
var _hit := {}
var _done := false
var _sprite: AnimatedSprite2D
## 当前视觉缩放(判定半径跟着它走)
var sprite_scale := START_SCALE


func _ready() -> void:
	z_index = 9
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Tornado"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = STRIPS.build([
		{"anim": &"spin", "path": FRAMES_PATH, "fps": 16.0, "loop": true},
	])
	_sprite.position = CENTER_OFFSET
	_sprite.scale = Vector2(START_SCALE, START_SCALE)
	add_child(_sprite)
	_sprite.play(&"spin")
	_speed = ROOM_WIDTH * TRAVEL_FRACTION / TRAVEL_TIME


func setup(dir: Vector2, damage := DAMAGE) -> void:
	_dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_damage = maxi(1, damage)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# 前 GROW_TIME 秒:停在主角身上慢慢变大
	var k := clampf(_t / GROW_TIME, 0.0, 1.0)
	var s := lerpf(START_SCALE, FULL_SCALE, k)
	if _sprite != null:
		_sprite.scale = Vector2(s, s)
		sprite_scale = s
	# 长满之后才开始往前走
	if _t > GROW_TIME:
		global_position += _dir * _speed * delta
	_poll_hits()
	if _t >= GROW_TIME + TRAVEL_TIME:
		_finish()


## 每帧扫一下范围内的敌人 / 弹幕。
func _poll_hits() -> void:
	var circle := CircleShape2D.new()
	circle.radius = maxf(26.0, 12.5 * sprite_scale)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position + CENTER_OFFSET)
	query.collision_mask = DAMAGE_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 48):
		var area := hit.get("collider") as Area2D
		if area == null:
			continue
		# 敌人是「受击盒 Area2D + 本体父节点」;弹幕本身就是 Area2D,
		# 所以两个都试一下。
		for candidate in [area, area.get_parent()]:
			if candidate == null or not is_instance_valid(candidate):
				continue
			var id: int = (candidate as Node).get_instance_id()
			if _hit.has(id):
				continue
			var node := candidate as Node
			if node.is_in_group("projectile"):
				_hit[id] = true
				node.call("pop")
				break
			if node.is_in_group("enemy") and node.has_method("take_hit"):
				_hit[id] = true
				# 延迟一帧结算:命中发生在物理查询刷新期间,直接改场景会报错
				node.call_deferred("take_hit", PlayerStats.hit(_damage),
					int(signf(_dir.x)), 520.0, -180.0)
				break


func _finish() -> void:
	_done = true
	set_physics_process(false)
	if _sprite == null:
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tw.tween_property(_sprite, "scale", _sprite.scale * 1.25, 0.3)
	tw.chain().tween_callback(queue_free)
