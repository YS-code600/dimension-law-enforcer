extends Node2D
## 敌方坦克:从地图边缘开进场地,150 点生命,停在玩家前方开炮。
## 被主角近战/飞刀/弹反光弹击中会掉血,血量归零时播放爆炸并消失。

const BULLET := preload("res://levels/enemies/enemy_bullet.tscn")
const BOOM := preload("res://levels/combat/tank_boom.tscn")
const TOKEN_DROP := preload("res://levels/combat/token_drop.gd")

@export var max_health := 150
@export var speed := 95.0
## 与玩家保持的停车距离。
@export var stop_distance := 400.0
@export var fire_interval := 2.4

var health := 150

var _dir := -1.0
var _dead := false
var _fire_cd := 1.4
var _flash := 0.0
var _player: Node2D

@onready var _sprite: Sprite2D = $Sprite
@onready var _muzzle: Marker2D = $Muzzle
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("raid_tank")
	health = max_health
	_player = _tree_player()
	_apply_facing()


## 由生成器调用:direction 为 +1 表示朝右开,−1 表示朝左开。
func setup(direction: float) -> void:
	_dir = 1.0 if direction >= 0.0 else -1.0
	if is_inside_tree():
		_apply_facing()


func health_now() -> int:
	return health


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = _tree_player()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_sprite.modulate = Color(1.0 + _flash * 1.6, 1.0 + _flash * 0.6, 1.0 + _flash * 0.6)
	if _player == null:
		return

	var to_player := _player.global_position - global_position
	if absf(to_player.x) > stop_distance:
		global_position.x += _dir * speed * delta
		return

	_fire_cd -= delta
	if _fire_cd <= 0.0:
		_fire_cd = fire_interval
		_fire()


func _fire() -> void:
	var aim := (_player.global_position + Vector2(0.0, -38.0) - _muzzle.global_position)
	if aim.length() < 1.0:
		return
	var bullet := BULLET.instantiate()
	bullet.global_position = _muzzle.global_position
	get_parent().add_child(bullet)
	bullet.call("setup", aim.normalized())
	_flash = 0.35
	_sprite.modulate = Color(1.5, 1.15, 1.0)


## 主角的攻击与反弹光弹都会调用这里。
func take_hit(damage: int, _direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	health = maxi(0, health - damage)
	_flash = 1.0
	_sprite.modulate = Color(2.0, 1.2, 1.2)
	if health <= 0:
		_explode()


func _explode() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemy")
	remove_from_group("raid_tank")
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)
	var host := get_parent()
	if host != null:
		var boom := BOOM.instantiate()
		host.add_child(boom)
		boom.global_position = global_position + Vector2(0.0, -46.0)
		TOKEN_DROP.burst(host, global_position + Vector2(0.0, -46.0))
	queue_free()


func _apply_facing() -> void:
	if _sprite == null:
		return
	# 原图朝左;朝右开时水平翻转。
	_sprite.flip_h = _dir > 0.0
	if _muzzle != null:
		_muzzle.position = Vector2(120.0 * _dir, -60.0)


func _tree_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D
