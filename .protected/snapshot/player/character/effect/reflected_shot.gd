extends Node2D
## 弹反打回去的弹幕:青色光环,自动飞向最近的敌人,命中造成伤害。
## 独立成场景,避免改动敌方弹幕脚本(那些文件会被外部工具覆盖)。

const ENEMY_LAYER := 4
const SPEED := 470.0
const LIFETIME := 3.0
const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")

var damage := 16

var _dir := Vector2.RIGHT
var _life := LIFETIME
var _dead := false
var _spin := 0.0
var _visual: Node2D
var _hitbox: Area2D


func _ready() -> void:
	add_to_group("reflected_projectile")
	z_index = 7
	_build_visual()
	_build_hitbox()


## 由主角弹反时调用:direction 一般指向最近的敌人。
func setup(direction: Vector2, hit_damage: int) -> void:
	if direction.length() > 0.001:
		_dir = direction.normalized()
	damage = maxi(hit_damage, 1)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += _dir * SPEED * delta
	_spin += delta * 9.0
	if _visual != null:
		_visual.rotation = _spin
	_life -= delta
	if _life <= 0.0:
		pop()


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_add_ring(12.0, 7.0, Color(0.28, 0.68, 1.0, 0.3))
	_add_ring(8.0, 3.0, Color(0.55, 0.95, 1.0, 0.95))
	_add_ring(3.4, 2.0, Color(1.0, 1.0, 1.0, 0.9))
	var tail := Line2D.new()
	tail.width = 3.0
	tail.default_color = Color(0.45, 0.85, 1.0, 0.45)
	tail.antialiased = true
	tail.points = PackedVector2Array([Vector2(-4.0, 0.0), Vector2(-22.0, 0.0)])
	_visual.add_child(tail)


func _add_ring(radius: float, width: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.antialiased = true
	ring.closed = true
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	var points := PackedVector2Array()
	var segments := 20
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	_visual.add_child(ring)


func _build_hitbox() -> void:
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = ENEMY_LAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	_hitbox.add_child(shape)
	add_child(_hitbox)
	_hitbox.body_entered.connect(_on_body_entered)
	_hitbox.area_entered.connect(_on_area_entered)


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body != null and body.has_method("take_hit"):
		_hit_target(body)
	pop()


func _on_area_entered(area: Area2D) -> void:
	if _dead or area == null:
		return
	_hit_target(area.get_parent())
	pop()


func _hit_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("take_hit"):
		return
	target.call("take_hit", damage, int(signf(_dir.x)), 250.0, -70.0)


func pop() -> void:
	if _dead:
		return
	_dead = true
	if _hitbox != null:
		_hitbox.set_deferred("monitorable", false)
		_hitbox.set_deferred("monitoring", false)
	var spark := HIT_SPARK.instantiate()
	spark.global_position = global_position
	spark.scale = Vector2(0.7, 0.7)
	get_parent().add_child.call_deferred(spark)
	queue_free()
