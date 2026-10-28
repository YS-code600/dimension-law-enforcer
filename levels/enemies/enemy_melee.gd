extends Node2D
## 近战兵「骷髅」:大范围巡逻,主角进入小范围才追击;
## 只有攻击动画播到挥砍帧时才造成伤害;有重力,不会在空中行走。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const ART_DIR := "res://levels/enemies/skeleton/"
const GRAVITY := 1500.0
## 前方障碍探测:距离取精灵半宽(约 42)+ 余量,避免身体穿进箱子/掩体
const WALL_PROBE := 46.0
const WALL_HEIGHTS: Array[float] = [-16.0, -44.0]

@export var max_hp := 24
@export var speed := 78.0
@export var patrol_speed := 42.0
@export var detection_range := 520.0
@export var chase_range := 210.0
@export var patrol_range := 260.0
@export var contact_damage := 12
@export var hit_stun := 0.5
@export var attack_cooldown := 1.1
@export var attack_damage_frame := 3
@export var attack_reach := 58.0

var _hp := 0
var _player: Node2D
var _spawn_x := 0.0
var _facing := 1
var _dead := false
var _attack_cd := 0.0
var _walk_t := 0.0
var _stun_time := 0.0
var _anim_lock := 0.0
var _patrol_dir := 1
var _spawn_set := false
var _patrol_pause := 0.0
var _attacking := false
var _attack_hit_done := false
var _vel_y := 0.0
var _on_floor := false

@onready var _body: AnimatedSprite2D = $Body
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	_hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	_body.sprite_frames = STRIPS.build([
		{"anim": &"idle", "path": ART_DIR + "idle.png", "fps": 8.0, "loop": true},
		{"anim": &"walk", "path": ART_DIR + "walk.png", "fps": 10.0, "loop": true},
		{"anim": &"attack", "path": ART_DIR + "attack.png", "fps": 14.0, "loop": false},
		{"anim": &"hurt", "path": ART_DIR + "hurt.png", "fps": 12.0, "loop": false},
		{"anim": &"death", "path": ART_DIR + "death.png", "fps": 10.0, "loop": false},
	])
	_body.play(&"idle")
	_body.animation_finished.connect(_on_animation_finished)


func _play(anim: StringName, lock := 0.0) -> void:
	if lock > 0.0:
		_anim_lock = lock
	if _body.animation != anim:
		_body.play(anim)


func _on_animation_finished() -> void:
	if _body.animation == &"attack":
		_attacking = false


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
		_body.position.y = 0.0
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		_patrol(delta)
		return

	var to_player := _player.global_position - global_position
	var same_level := absf(to_player.y) <= 160.0

	# 攻击动画播放中:站定,只在挥砍帧结算一次伤害
	if _attacking:
		_body.position.y = 0.0
		if not _attack_hit_done and _body.animation == &"attack" \
				and _body.frame >= attack_damage_frame:
			_attack_hit_done = true
			if absf(to_player.x) <= attack_reach and absf(to_player.y) <= 64.0:
				if _player.has_method("take_damage"):
					_player.take_damage(contact_damage, global_position)
		return

	var chase := same_level and absf(to_player.x) <= chase_range

	if not chase:
		# 小范围外:只巡逻,不追
		_patrol(delta)
		return

	# 小范围追击
	_facing = -1 if to_player.x < 0.0 else 1
	_body.flip_h = _facing < 0
	if absf(to_player.x) > 34.0:
		if _on_floor:
			if _is_wall(_facing):
				# 前方有箱子/掩体:停在前面,不把身体挤进去
				_body.position.y = 0.0
				if _anim_lock <= 0.0:
					_play(&"idle")
			else:
				global_position.x += _facing * speed * delta
				_walk_t += delta * 12.0
				_body.position.y = sin(_walk_t) * 1.0
				if _anim_lock <= 0.0:
					_play(&"walk")
		elif _anim_lock <= 0.0:
			_play(&"idle")
	else:
		_body.position.y = 0.0
		if _anim_lock <= 0.0:
			_play(&"idle")

	if absf(to_player.x) <= attack_reach * 0.72 and absf(to_player.y) < 56.0 \
			and _attack_cd <= 0.0 and not _attacking:
		_start_attack()


func _patrol(delta: float) -> void:
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		_body.position.y = 0.0
		if _anim_lock <= 0.0:
			_play(&"idle")
		return
	# 撞到箱子/掩体:掉头,不穿模
	if _on_floor and _is_wall(_patrol_dir):
		_patrol_dir = -_patrol_dir
		_patrol_pause = 0.5
		_body.position.y = 0.0
		if _anim_lock <= 0.0:
			_play(&"idle")
		return
	_facing = _patrol_dir
	_body.flip_h = _facing < 0
	if _on_floor:
		global_position.x += _facing * patrol_speed * delta
		_walk_t += delta * 9.0
		_body.position.y = sin(_walk_t) * 1.0
		if _anim_lock <= 0.0:
			_play(&"walk")
	elif _anim_lock <= 0.0:
		_play(&"idle")
	if global_position.x <= _spawn_x - patrol_range:
		_patrol_dir = 1
		_patrol_pause = 0.7
	elif global_position.x >= _spawn_x + patrol_range:
		_patrol_dir = -1
		_patrol_pause = 0.7


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


func _start_attack() -> void:
	_attacking = true
	_attack_hit_done = false
	_attack_cd = attack_cooldown
	_play(&"attack", 0.45)
	_body.position.x = _facing * 3.0
	var tw := create_tween()
	tw.tween_property(_body, "position:x", 0.0, 0.12)


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= damage
	_stun_time = hit_stun
	_attack_cd = maxf(_attack_cd, 0.8)
	_attacking = false
	_play(&"hurt", 0.3)
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
	tw.tween_interval(0.65)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.3)
	tw.chain().tween_callback(queue_free)
