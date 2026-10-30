extends Node2D
## 骑士:第 3 阶段起由 Boss 召唤的精英近战,200 血,挥剑 20 点伤害。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const TOKEN_DROP := preload("res://levels/combat/token_drop.gd")
const ART_DIR := "res://levels/enemies/knight/"
const GRAVITY := 1500.0
## 前方障碍探测(箱子/掩体在碰撞层 1)
const WALL_PROBE := 28.0
const WALL_HEIGHTS: Array[float] = [-10.0, -30.0]

@export var max_hp := 200
@export var speed := 104.0
@export var damage := 20
@export var attack_reach := 92.0
@export var attack_cooldown := 1.5
## 攻击动画播到第几帧才结算伤害(两种挥剑各自的判定帧)
@export var attack1_hit_frame := 5
@export var attack2_hit_frame := 4

var _hp := 0
var _player: Node2D
var _facing := 1.0
var _dead := false
var _attack_cd := 0.0
var _attacking := false
var _attack_hit_done := false
var _attack_index := 0
var _anim_lock := 0.0
var _vel_y := 0.0
var _on_floor := false
var _move_dir := 0.0

@onready var _body: AnimatedSprite2D = $Body
@onready var _effect: Sprite2D = $Effect
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("knight")
	_hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	_body.sprite_frames = STRIPS.build([
		{"anim": &"idle", "path": ART_DIR + "idle.png", "fps": 8.0, "loop": true},
		{"anim": &"run", "path": ART_DIR + "run.png", "fps": 12.0, "loop": true},
		{"anim": &"attack1", "path": ART_DIR + "attack1.png", "fps": 16.0, "loop": false},
		{"anim": &"attack2", "path": ART_DIR + "attack2.png", "fps": 16.0, "loop": false},
		{"anim": &"hurt", "path": ART_DIR + "hurt.png", "fps": 14.0, "loop": false},
		{"anim": &"death", "path": ART_DIR + "death.png", "fps": 10.0, "loop": false},
	])
	_body.play(&"idle")
	_body.animation_finished.connect(_on_animation_finished)
	if _effect != null:
		_effect.visible = false


## 召唤时指定进场方向(+1 向右 / -1 向左)。
func set_move_dir(dir: float) -> void:
	_move_dir = signf(dir)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_apply_gravity(delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# 挥剑中:站定,只在判定帧结算一次伤害
	if _attacking:
		if not _attack_hit_done and _body.frame >= _current_hit_frame():
			_attack_hit_done = true
			_try_slash()
		return

	if not is_instance_valid(_player):
		_rest()
		return

	var to_player := _player.global_position - global_position
	_face(to_player.x)
	if absf(to_player.x) <= attack_reach and absf(to_player.y) <= 70.0:
		if _attack_cd <= 0.0:
			_start_attack()
		else:
			_rest()
		return
	_walk_toward(delta, signf(to_player.x) if absf(to_player.x) > 2.0 else _move_dir)


func _current_hit_frame() -> int:
	return attack1_hit_frame if _attack_index % 2 == 0 else attack2_hit_frame


## 朝主角走;前面有箱子就先起跳越过。
func _walk_toward(delta: float, dir: float) -> void:
	if dir == 0.0:
		dir = _move_dir
		_face(dir)
	global_position.x += dir * speed * delta
	if _anim_lock <= 0.0:
		_play(&"run")
	if _on_floor and _is_wall(int(signf(dir))):
		_vel_y = -520.0


func _rest() -> void:
	if _anim_lock <= 0.0:
		_play(&"idle")


func _face(dx: float) -> void:
	if absf(dx) < 1.0:
		return
	_facing = signf(dx)
	_body.flip_h = _facing < 0.0
	if _effect != null:
		_effect.flip_h = _facing < 0.0


func _play(anim: StringName, lock := 0.0) -> void:
	if lock > 0.0:
		_anim_lock = lock
	if _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	if _body.animation != anim:
		_body.play(anim)


func _on_animation_finished() -> void:
	if _body.animation == &"attack1" or _body.animation == &"attack2":
		_attacking = false
		if _effect != null:
			_effect.visible = false


func _start_attack() -> void:
	_attacking = true
	_attack_hit_done = false
	_attack_cd = attack_cooldown
	_attack_index += 1
	var anim: StringName = &"attack1" if _attack_index % 2 == 1 else &"attack2"
	_play(anim, 0.6)
	_show_effect(anim)


## 挥剑时闪一下刀光。
func _show_effect(anim: StringName) -> void:
	if _effect == null:
		return
	var path := ART_DIR + ("effect_attack1.png" if anim == &"attack1" else "effect_attack2.png")
	if ResourceLoader.exists(path):
		_effect.texture = load(path) as Texture2D
	else:
		var img := Image.new()
		if img.load(path) == OK:
			_effect.texture = ImageTexture.create_from_image(img)
	if _effect.texture == null:
		return
	_effect.flip_h = _facing < 0.0
	_effect.offset = Vector2(48.0 * _facing, -44.0)
	_effect.visible = true
	_effect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_effect, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void: _effect.visible = false)


func _try_slash() -> void:
	if not is_instance_valid(_player):
		return
	if absf(_player.global_position.x - global_position.x) > attack_reach + 18.0:
		return
	if absf(_player.global_position.y - global_position.y) > 80.0:
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", damage, global_position)


## 重力 + 地面吸附(和蘑菇兵同一套)。
func _apply_gravity(delta: float) -> void:
	_vel_y += GRAVITY * delta
	global_position.y += _vel_y * delta
	_on_floor = false
	var from := global_position + Vector2(0.0, -4.0)
	var to := from + Vector2(0.0, 24.0)
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


func take_hit(hit_damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= hit_damage
	_attacking = false
	if _effect != null:
		_effect.visible = false
	_play(&"hurt", 0.25)
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
	remove_from_group("knight")
	_hurtbox.set_deferred("monitorable", false)
	if _effect != null:
		_effect.visible = false
	_play(&"death", 1.5)
	_drop_tokens()
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)
	tw.chain().tween_callback(queue_free)


## 死亡掉 token,和其它小怪一致。
func _drop_tokens() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	TOKEN_DROP.burst(host, global_position + Vector2(0.0, -16.0))
