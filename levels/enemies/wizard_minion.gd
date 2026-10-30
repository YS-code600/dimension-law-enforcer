extends Node2D
## 飞行法师:第 4 阶段起 Boss 每 40 秒召唤一个(开局先来一个)。
## 在空中随机漂浮,每 5 秒交替「朝主角散射 10 发火焰弹」/「四周发射蓝色光球」,伤害 5。

const STRIPS := preload("res://levels/enemies/strip_anim.gd")
const TOKEN_DROP := preload("res://levels/combat/token_drop.gd")
const FIREBALL := preload("res://levels/boss/fireball.tscn")
const BLUE_ORB := preload("res://levels/npc/blue_orb.tscn")
const ART_DIR := "res://levels/enemies/wizard_minion/"

@export var max_hp := 300
@export var projectile_damage := 5
@export var attack_interval := 5.0
@export var fireball_count := 10
## 火焰弹散射角度(以主角方向为中心左右摊开)
@export var fireball_spread := 0.5
@export var orb_count := 12
@export var drift_speed := 95.0
## 漂浮范围(火雨房间 1152 x 648)
@export var drift_min_x := 140.0
@export var drift_max_x := 1010.0
@export var drift_min_y := 210.0
@export var drift_max_y := 520.0

var _hp := 0
var _player: Node2D
var _dead := false
var _attack_cd := 1.5
var _attacking := false
var _attack_index := 0
var _target := Vector2.ZERO
var _retarget_cd := 0.0
var _bob_t := 0.0
var _base_y := 0.0

@onready var _body: AnimatedSprite2D = $Body
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("flying_wizard")
	_hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	_body.sprite_frames = STRIPS.build([
		{"anim": &"idle", "path": ART_DIR + "idle.png", "fps": 8.0, "loop": true},
		{"anim": &"run", "path": ART_DIR + "run.png", "fps": 12.0, "loop": true},
		{"anim": &"attack1", "path": ART_DIR + "attack1.png", "fps": 14.0, "loop": false},
		{"anim": &"attack2", "path": ART_DIR + "attack2.png", "fps": 14.0, "loop": false},
		{"anim": &"hurt", "path": ART_DIR + "hurt.png", "fps": 14.0, "loop": false},
		{"anim": &"death", "path": ART_DIR + "death.png", "fps": 10.0, "loop": false},
	])
	_body.play(&"idle")
	_bob_t = randf() * TAU
	_base_y = global_position.y
	_pick_target()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_bob_t += delta
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	_attack_cd -= delta
	_retarget_cd -= delta
	if _retarget_cd <= 0.0:
		_pick_target()

	# 朝目标漂浮
	var to_target := _target - global_position
	if to_target.length() > 6.0:
		global_position += to_target.normalized() * drift_speed * delta
		global_position.y += sin(_bob_t * 2.4) * 12.0 * delta
		if not _attacking:
			_play(&"run")
	elif not _attacking:
		_play(&"idle")

	if _attack_cd <= 0.0 and not _attacking:
		_attack_cd = attack_interval
		_start_attack()


## 随机挑一个空中落点。
func _pick_target() -> void:
	_retarget_cd = randf_range(1.8, 3.2)
	_target = Vector2(
		randf_range(drift_min_x, drift_max_x),
		randf_range(drift_min_y, drift_max_y))


func _play(anim: StringName) -> void:
	if _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	if _body.animation != anim:
		_body.play(anim)


func _face(dx: float) -> void:
	if absf(dx) < 1.0:
		return
	_body.flip_h = dx < 0.0


## 交替:attack1 = 朝主角散射火焰弹,attack2 = 四周蓝色光球。
func _start_attack() -> void:
	_attacking = true
	_attack_index += 1
	var use_fireball := _attack_index % 2 == 1
	_play(&"attack1" if use_fireball else &"attack2")
	if is_instance_valid(_player):
		_face(_player.global_position.x - global_position.x)
	await get_tree().create_timer(0.45).timeout
	if _dead or not is_inside_tree():
		return
	if use_fireball:
		_fire_fireballs()
	else:
		_fire_orb_ring()
	await get_tree().create_timer(0.35).timeout
	_attacking = false


## 朝主角方向散射 10 发火焰弹。
func _fire_fireballs() -> void:
	var host := get_parent()
	if host == null:
		return
	var aim := Vector2.RIGHT
	if is_instance_valid(_player):
		aim = (_player.global_position + Vector2(0.0, -40.0) - global_position).normalized()
	for i in fireball_count:
		var t := float(i) / float(maxi(1, fireball_count - 1))
		var angle := lerpf(-fireball_spread * 0.5, fireball_spread * 0.5, t) \
			+ randf_range(-0.05, 0.05)
		var ball := FIREBALL.instantiate()
		host.add_child(ball)
		ball.global_position = global_position
		ball.call("setup", aim.rotated(angle), projectile_damage)


## 向四周均匀发射蓝色光球。
func _fire_orb_ring() -> void:
	var host := get_parent()
	if host == null:
		return
	for i in orb_count:
		var angle := TAU * float(i) / float(maxi(1, orb_count))
		var orb := BLUE_ORB.instantiate()
		host.add_child(orb)
		orb.global_position = global_position
		orb.call("setup", Vector2.RIGHT.rotated(angle), projectile_damage)


func take_hit(hit_damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= hit_damage
	_play(&"hurt")
	_body.modulate = Color(1.0, 0.5, 0.45)
	var tw := create_tween()
	tw.tween_property(_body, "modulate", Color.WHITE, 0.18)
	global_position.x += float(direction) * 4.0
	if _hp <= 0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemy")
	remove_from_group("flying_wizard")
	_hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	_play(&"death")
	_drop_tokens()
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_property(self, "position:y", position.y + 40.0, 0.35)
	tw.chain().tween_callback(queue_free)


func _drop_tokens() -> void:
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	TOKEN_DROP.burst(host, global_position + Vector2(0.0, -16.0))
