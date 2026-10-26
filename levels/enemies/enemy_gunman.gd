extends Node2D
## 西装枪手:唯一会发射弹幕的敌人。

const BULLET := preload("res://levels/enemies/enemy_bullet.tscn")

@export var max_hp := 30
@export var fire_interval := 3.0
@export var detection_range := 680.0
@export var detection_vertical := 420.0
@export var hit_stun := 0.55

var _hp := 0
var _player: Node2D
var _cooldown := 1.0
var _dead := false
var _facing := 1
var _muzzle_time := 0.0
var _stun_time := 0.0

@onready var _body: Sprite2D = $Body
@onready var _muzzle: Sprite2D = $Muzzle
@onready var _hurtbox: Area2D = $Hurtbox

const MUZZLE_X := 24.0
const GUN_Y := -34.0


func _ready() -> void:
	add_to_group("enemy")
	_hp = max_hp
	_cooldown = randf_range(0.7, 1.3)
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _muzzle_time > 0.0:
		_muzzle_time -= delta
		_muzzle.visible = _muzzle_time > 0.0
	if _stun_time > 0.0:
		_stun_time -= delta
		_muzzle.visible = false
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return

	var to_player := _player.global_position - global_position
	if absf(to_player.x) > detection_range or absf(to_player.y) > detection_vertical:
		_cooldown = maxf(_cooldown, 0.35)
		return

	_facing = -1 if to_player.x < 0.0 else 1
	_body.flip_h = _facing < 0
	_muzzle.position = Vector2(MUZZLE_X * _facing, GUN_Y)

	_cooldown -= delta
	if _cooldown <= 0.0:
		_shoot()
		_cooldown = fire_interval


func _shoot() -> void:
	var target: Vector2 = _player.global_position + Vector2(0, -30)
	var origin: Vector2 = _muzzle.global_position
	var base := (target - origin).normalized()
	for angle_offset in [-0.13, 0.0, 0.13]:
		var bullet := BULLET.instantiate()
		bullet.global_position = origin
		get_parent().add_child(bullet)
		bullet.call("setup", base.rotated(angle_offset))

	_muzzle.rotation = base.angle()
	_muzzle.visible = true
	_muzzle_time = 0.08
	_body.position.y = -1.0
	var tw := create_tween()
	tw.tween_property(_body, "position:y", 0.0, 0.1)


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= damage
	_stun_time = hit_stun
	_cooldown = fire_interval
	_muzzle_time = 0.0
	_muzzle.visible = false
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
	_muzzle.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.28)
	tw.chain().tween_callback(queue_free)
