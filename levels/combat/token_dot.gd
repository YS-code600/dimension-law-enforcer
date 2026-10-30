extends RigidBody2D
## 击败小怪后掉落的 token 光点:随机颜色、会被重力拉回地面,
## 落地并冷却 0.5 秒之后才能被主角吸附拾取(Tokens +1)。

## 贴身拾取半径
const PICKUP_RADIUS := 16.0
## 进入这个距离开始被主角吸附
const MAGNET_RADIUS := 92.0
const MAGNET_SPEED := 460.0
## 落地后还要等这么久才能捡
const ARM_DELAY := 0.5
## 落地判定:身体下方这么多像素内有地面就算落地
const LAND_PROBE := 9.0
## 兜底:一直判定不到落地(卡在奇怪位置)时,最多这么久也强制可拾取
const LAND_TIMEOUT := 2.5
## 没人捡就自己消失,避免地上越堆越多
const LIFETIME := 26.0
const POP_SPEED := Vector2(170.0, 330.0)

var _tint := Color(0.45, 0.95, 1.0)
var _age := 0.0
var _landed := false
var _armed := false
var _arm_left := 0.0
var _magnet := false
var _picked := false
var _twinkle: Tween


## 由掉落逻辑调用,决定这个光点的颜色。
func setup(color: Color) -> void:
	_tint = color
	queue_redraw()


func _ready() -> void:
	add_to_group("token_dot")
	z_index = 6
	lock_rotation = true
	# 不占物理层,只和地形/掩体(碰撞层 1)碰撞,免得把主角顶开。
	collision_layer = 0
	collision_mask = 1
	linear_damp = 1.5
	angular_damp = 8.0
	var player := get_tree().get_first_node_in_group("player")
	if player is PhysicsBody2D:
		add_collision_exception_with(player)
	# 冷却期间压暗,落地弹一下才亮起来。
	modulate.a = 0.45
	# 从掉落点向上弹开,再被重力拉到地面。
	linear_velocity = Vector2(
		randf_range(-POP_SPEED.x, POP_SPEED.x),
		randf_range(-POP_SPEED.y, -POP_SPEED.y * 0.5)
	)


## 落地检测:下落中且正下方很近就是地面。
func _physics_process(_delta: float) -> void:
	if _picked or _landed or freeze:
		return
	if linear_velocity.y < 0.0:
		return
	var from := global_position + Vector2(0.0, -2.0)
	var to := global_position + Vector2(0.0, LAND_PROBE)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		_land()


func _process(delta: float) -> void:
	if _picked:
		return
	_age += delta
	if _age >= LIFETIME:
		_expire()
		return
	if not _landed and _age >= LAND_TIMEOUT:
		_land()
	if _landed and not _armed:
		_arm_left -= delta
		if _arm_left <= 0.0:
			_arm()
	if not _armed:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist <= PICKUP_RADIUS:
		_collect()
		return
	if _magnet or dist <= MAGNET_RADIUS:
		_magnet = true
		freeze = true
		global_position += to_player / maxf(dist, 1.0) * minf(MAGNET_SPEED * delta, dist)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(_tint, 0.12))
	draw_circle(Vector2.ZERO, 6.4, Color(_tint, 0.34))
	draw_circle(Vector2.ZERO, 3.6, _tint.lerp(Color(1, 1, 1), 0.3))
	draw_circle(Vector2.ZERO, 1.5, Color(1.0, 1.0, 1.0, 0.95))


## 落地:开始 0.5 秒冷却。
func _land() -> void:
	if _landed:
		return
	_landed = true
	_arm_left = ARM_DELAY


## 冷却结束:亮起来,并开始呼吸闪烁。
func _arm() -> void:
	if _armed:
		return
	_armed = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	_twinkle = create_tween().set_loops()
	_twinkle.tween_property(self, "modulate:a", 0.6, 0.42).set_trans(Tween.TRANS_SINE)
	_twinkle.tween_property(self, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_SINE)


func _collect() -> void:
	if _picked:
		return
	_picked = true
	set_process(false)
	set_physics_process(false)
	freeze = true
	collision_mask = 0
	var tokens := get_node_or_null("/root/Tokens")
	if tokens != null:
		tokens.call("add", 1)
	_stop_twinkle()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_property(self, "global_position:y", global_position.y - 16.0, 0.14)
	tw.chain().tween_callback(queue_free)


func _expire() -> void:
	_picked = true
	set_process(false)
	set_physics_process(false)
	_stop_twinkle()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _stop_twinkle() -> void:
	if _twinkle != null and _twinkle.is_valid():
		_twinkle.kill()
	_twinkle = null
