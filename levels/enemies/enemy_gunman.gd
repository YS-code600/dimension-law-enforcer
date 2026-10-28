extends Node2D
## 远程兵「史莱姆」:有重力、会巡逻/靠近/后撤,主角进入小范围才靠近并发射三向弹幕。

const BULLET := preload("res://levels/enemies/enemy_bullet.tscn")
const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const ART_DIR := "res://levels/enemies/slime/"
const GRAVITY := 1500.0
## 前方障碍探测,避免身体穿进箱子/掩体
const WALL_PROBE := 44.0
const WALL_HEIGHTS: Array[float] = [-14.0, -36.0]

@export var max_hp := 30
@export var fire_interval := 3.0
@export var detection_range := 680.0
@export var detection_vertical := 420.0
@export var hit_stun := 0.55
@export var patrol_speed := 45.0
@export var chase_speed := 62.0
@export var patrol_range := 220.0
@export var chase_range := 300.0
@export var keep_distance := 210.0

var _hp := 0
var _player: Node2D
var _spawn_x := 0.0
var _cooldown := 1.0
var _dead := false
var _facing := 1
var _stun_time := 0.0
var _anim_lock := 0.0
var _patrol_dir := 1
var _spawn_set := false
var _patrol_pause := 0.0
var _vel_y := 0.0
var _on_floor := false

@onready var _body: AnimatedSprite2D = $Body
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	_hp = max_hp
	_cooldown = randf_range(0.7, 1.3)
	_player = get_tree().get_first_node_in_group("player")
	_body.sprite_frames = STRIPS.build([
		{"anim": &"idle", "path": ART_DIR + "idle.png", "fps": 6.0, "loop": true},
		{"anim": &"walk", "path": ART_DIR + "walk.png", "fps": 8.0, "loop": true},
		{"anim": &"death", "path": ART_DIR + "death.png", "fps": 8.0, "loop": false},
	])
	_body.play(&"idle")


func _play(anim: StringName, lock := 0.0) -> void:
	if lock > 0.0:
		_anim_lock = lock
	if _body.animation != anim:
		_body.play(anim)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _spawn_set:
		_spawn_x = global_position.x
		_spawn_set = true
	_apply_gravity(delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	if _stun_time > 0.0:
		_stun_time -= delta
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		_patrol(delta)
		return

	var to_player := _player.global_position - global_position
	var same_level := absf(to_player.y) <= detection_vertical
	var in_sight := absf(to_player.x) <= detection_range and same_level
	var chase := in_sight and absf(to_player.x) <= chase_range

	if chase:
		_facing = -1 if to_player.x < 0.0 else 1
		_body.flip_h = _facing < 0
		var dist := absf(to_player.x)
		var moved := false
		if dist > keep_distance:
			# 太远:靠近
			if _on_floor and not _is_wall(_facing):
				global_position.x += _facing * chase_speed * delta
				moved = true
		elif dist < keep_distance * 0.55:
			# 太近:后撤
			if _on_floor and not _is_wall(-_facing):
				global_position.x -= _facing * chase_speed * 0.8 * delta
				moved = true
		if moved and _anim_lock <= 0.0:
			_play(&"walk")
		elif not moved and _anim_lock <= 0.0:
			_play(&"idle")
	else:
		_patrol(delta)

	if in_sight:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_shoot()
			_cooldown = fire_interval


func _patrol(delta: float) -> void:
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		if _anim_lock <= 0.0:
			_play(&"idle")
		return
	# 撞到箱子/掩体:掉头
	if _on_floor and _is_wall(_patrol_dir):
		_patrol_dir = -_patrol_dir
		_patrol_pause = 0.5
		if _anim_lock <= 0.0:
			_play(&"idle")
		return
	_facing = _patrol_dir
	_body.flip_h = _facing < 0
	if _on_floor:
		global_position.x += _facing * patrol_speed * delta
		if _anim_lock <= 0.0:
			_play(&"walk")
	elif _anim_lock <= 0.0:
		_play(&"idle")
	if global_position.x <= _spawn_x - patrol_range:
		_patrol_dir = 1
		_patrol_pause = 0.6
	elif global_position.x >= _spawn_x + patrol_range:
		_patrol_dir = -1
		_patrol_pause = 0.6


## 朝 dir 方向前方是否有箱子/掩体等实体障碍(碰撞层 1)。
func _is_wall(dir: int) -> bool:
	for dy in WALL_HEIGHTS:
		var from := global_position + Vector2(0.0, dy)
		var to := from + Vector2(float(dir) * WALL_PROBE, 0.0)
		var query := PhysicsRayQueryParameters2D.create(from, to, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


## 重力 + 地面吸附。
func _apply_gravity(delta: float) -> void:
	_vel_y += GRAVITY * delta
	global_position.y += _vel_y * delta
	_on_floor = false
	var from := global_position + Vector2(0.0, -6.0)
	var to := from + Vector2(0.0, 30.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _vel_y >= 0.0:
		if hit.position.y - global_position.y <= 16.0:
			global_position.y = hit.position.y
			_vel_y = 0.0
			_on_floor = true


func _shoot() -> void:
	var target: Vector2 = _player.global_position + Vector2(0, -30)
	var origin: Vector2 = global_position + Vector2(float(_facing) * 16.0, -22.0)
	var base := (target - origin).normalized()
	for angle_offset in [-0.13, 0.0, 0.13]:
		var bullet := BULLET.instantiate()
		bullet.global_position = origin
		get_parent().add_child(bullet)
		bullet.call("setup", base.rotated(angle_offset))
	_play(&"walk", 0.28)
	_body.position.y = -2.0
	var tw := create_tween()
	tw.tween_property(_body, "position:y", 0.0, 0.14)


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= damage
	_stun_time = hit_stun
	_cooldown = fire_interval
	_body.modulate = Color(1.0, 0.45, 0.4)
	var tw := create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.18)
	_body.position.x = direction * 3.0
	var tw2 := create_tween()
	tw2.tween_property(_body, "position:x", 0.0, 0.12)
	if _hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	_hurtbox.set_deferred("monitorable", false)
	_play(&"death", 1.5)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.3)
	tw.chain().tween_callback(queue_free)
