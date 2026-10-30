extends Node2D
## 蘑菇小兵:第 3 阶段起由 Boss 每 30 秒召唤 4 只。
## 一蹦一蹦地贴向主角,靠近后咬一口,命中造成 contact_damage(默认 4 点)。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const TOKEN_DROP := preload("res://levels/combat/token_drop.gd")
const ART_DIR := "res://levels/enemies/mushroom/"
const GRAVITY := 1500.0
## 前方障碍探测(箱子/掩体在碰撞层 1)
const WALL_PROBE := 26.0
const WALL_HEIGHTS: Array[float] = [-8.0, -22.0]

@export var max_hp := 18
@export var speed := 92.0
@export var contact_damage := 4
@export var attack_reach := 48.0
@export var attack_cooldown := 1.25
@export var attack_damage_frame := 3
@export var hop_interval := 0.5
@export var hop_power := 300.0

var _hp := 0
var _player: Node2D
var _facing := 1.0
var _dead := false
var _attack_cd := 0.0
var _attacking := false
var _attack_hit_done := false
var _anim_lock := 0.0
var _vel_y := 0.0
var _on_floor := false
var _hop_cd := 0.0
var _move_dir := 0.0

@onready var _body: AnimatedSprite2D = $Body
@onready var _shadow: AnimatedSprite2D = $Shadow
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("mushroom")
	_hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	_body.sprite_frames = STRIPS.build([
		{"anim": &"idle", "path": ART_DIR + "idle.png", "fps": 8.0, "loop": true},
		{"anim": &"jump", "path": ART_DIR + "jump.png", "fps": 10.0, "loop": true},
		{"anim": &"attack", "path": ART_DIR + "attack.png", "fps": 14.0, "loop": false},
		{"anim": &"death", "path": ART_DIR + "death.png", "fps": 10.0, "loop": false},
	])
	_shadow.sprite_frames = STRIPS.build([
		{"anim": &"idle", "path": ART_DIR + "shadow_idle.png", "fps": 8.0, "loop": true},
		{"anim": &"jump", "path": ART_DIR + "shadow_jump.png", "fps": 10.0, "loop": true},
		{"anim": &"attack", "path": ART_DIR + "shadow_attack.png", "fps": 14.0, "loop": false},
		{"anim": &"death", "path": ART_DIR + "shadow_death.png", "fps": 10.0, "loop": false},
	])
	_body.play(&"idle")
	_shadow.play(&"idle")
	_body.animation_finished.connect(_on_animation_finished)


## 召唤时指定进场方向(+1 向右 / -1 向左)。
func set_move_dir(dir: float) -> void:
	_move_dir = signf(dir)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_apply_gravity(delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hop_cd = maxf(0.0, _hop_cd - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# 咬击动画播放中:站定,只在咬击帧结算一次伤害
	if _attacking:
		if not _attack_hit_done and _body.animation == &"attack" \
				and _body.frame >= attack_damage_frame:
			_attack_hit_done = true
			_try_bite()
		return

	if not is_instance_valid(_player):
		_rest()
		return

	var to_player := _player.global_position - global_position
	_face(to_player.x)
	if absf(to_player.x) <= attack_reach and absf(to_player.y) <= 56.0:
		if _attack_cd <= 0.0:
			_start_attack()
		else:
			_rest()
		return
	_walk_toward(delta, signf(to_player.x) if absf(to_player.x) > 2.0 else _move_dir)


## 一蹦一蹦地靠近主角。
func _walk_toward(delta: float, dir: float) -> void:
	if dir == 0.0:
		dir = _move_dir
		_face(dir)
	if _on_floor and _is_wall(int(signf(dir))):
		# 前面是箱子/掩体:原地起跳,不硬穿
		if _hop_cd <= 0.0:
			_hop_cd = hop_interval
			_vel_y = -hop_power * 1.7
		_rest()
		return
	global_position.x += dir * speed * delta
	if _on_floor and _hop_cd <= 0.0:
		_hop_cd = hop_interval
		_vel_y = -hop_power
	if _anim_lock <= 0.0:
		_play(&"jump")


func _rest() -> void:
	if _anim_lock <= 0.0:
		_play(&"idle")


func _face(dx: float) -> void:
	if absf(dx) < 1.0:
		return
	_facing = signf(dx)
	_body.flip_h = _facing < 0.0
	_shadow.flip_h = _facing < 0.0


func _play(anim: StringName, lock := 0.0) -> void:
	if lock > 0.0:
		_anim_lock = lock
	if _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	if _body.animation != anim:
		_body.play(anim)
	if _shadow.sprite_frames != null and _shadow.sprite_frames.has_animation(anim) \
			and _shadow.animation != anim:
		_shadow.play(anim)


func _on_animation_finished() -> void:
	if _body.animation == &"attack":
		_attacking = false


func _start_attack() -> void:
	_attacking = true
	_attack_hit_done = false
	_attack_cd = attack_cooldown
	_play(&"attack", 0.55)


func _try_bite() -> void:
	if not is_instance_valid(_player):
		return
	if absf(_player.global_position.x - global_position.x) > attack_reach + 12.0:
		return
	if absf(_player.global_position.y - global_position.y) > 60.0:
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", contact_damage, global_position)


## 重力 + 地面吸附(和骷髅兵同一套,只是数值更小)。
func _apply_gravity(delta: float) -> void:
	_vel_y += GRAVITY * delta
	global_position.y += _vel_y * delta
	_on_floor = false
	var from := global_position + Vector2(0.0, -4.0)
	var to := from + Vector2(0.0, 22.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _vel_y >= 0.0:
		if hit.position.y - global_position.y <= 14.0:
			global_position.y = hit.position.y
			_vel_y = 0.0
			_on_floor = true


## 朝 dir 方向前方是否有箱子/掩体等实体障碍(碰撞层 1)。
func _is_wall(dir: int) -> bool:
	if dir == 0:
		return false
	for dy in WALL_HEIGHTS:
		var from := global_position + Vector2(0.0, dy)
		var to := from + Vector2(float(dir) * WALL_PROBE, 0.0)
		var query := PhysicsRayQueryParameters2D.create(from, to, 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= damage
	_attacking = false
	_play(&"idle", 0.2)
	_body.modulate = Color(1.0, 0.5, 0.45)
	var tw := create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.18)
	global_position.x += float(direction) * 5.0
	if _hp <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemy")
	remove_from_group("mushroom")
	_hurtbox.set_deferred("monitorable", false)
	_play(&"death", 1.2)
	_drop_tokens()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(0.75, 0.75), 0.3)
	tw.chain().tween_callback(queue_free)


## 死亡掉 token,和其它小怪一致。
func _drop_tokens() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	TOKEN_DROP.burst(host, global_position + Vector2(0.0, -12.0))
