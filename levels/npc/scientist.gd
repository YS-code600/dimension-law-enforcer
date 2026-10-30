extends Node2D
## 仪器前的研究员:开场播完台词后转为近战敌人(100 血),被打倒后淡出。

signal health_changed(current: int, maximum: int)
signal defeated

@export var max_health := 100
@export var move_speed := 150.0
@export var attack_range := 130.0
@export var attack_interval := 1.4
@export var damage := 12

var _health := 100
var _player: Node2D
var _facing_right := true
var _state := "idle"
var _attack_cd := 0.6
var _hurtbox: Area2D

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_health = max_health
	add_to_group("npc")
	_player = get_tree().get_first_node_in_group("player")
	_hurtbox = get_node_or_null("Hurtbox")
	if _hurtbox != null:
		_hurtbox.collision_layer = 0
	# 初始朝向:素材默认面朝左
	_facing_right = false
	_sprite.flip_h = false


func health_now() -> int:
	return _health


func is_fighting() -> bool:
	return _state == "chase"


## 转向主角。
func face_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_facing_right = _player.global_position.x >= global_position.x
	# 素材本身面朝左,只有要朝右时才镜像
	_sprite.flip_h = _facing_right


func start_talk() -> void:
	_state = "talk"


## 台词播完,转为近战敌人。
func start_fight() -> void:
	_state = "chase"
	add_to_group("enemy")
	_health = max_health
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 4)
	_attack_cd = 0.5
	health_changed.emit(_health, max_health)


func _physics_process(delta: float) -> void:
	if _state == "dead" or _player == null or not is_instance_valid(_player):
		return
	if _state == "talk":
		return
	face_player()
	var dx := _player.global_position.x - global_position.x
	if _state == "chase":
		if absf(dx) > attack_range * 0.75:
			global_position.x = move_toward(global_position.x, _player.global_position.x, move_speed * delta)
		_attack_cd -= delta
		if _attack_cd <= 0.0 and absf(dx) <= attack_range and absf(_player.global_position.y - global_position.y) < 160.0:
			_attack_cd = attack_interval
			_do_attack()


## 近战:向前突刺一下,命中范围内的主角造成伤害。
func _do_attack() -> void:
	_state = "chase"
	var dir := 1.0 if _facing_right else -1.0
	var tw := create_tween()
	tw.tween_property(_sprite, "position:x", dir * 18.0, 0.08)
	tw.tween_property(_sprite, "position:x", 0.0, 0.16)
	if _player == null or not is_instance_valid(_player):
		return
	var dx := absf(_player.global_position.x - global_position.x)
	if dx <= attack_range * 0.8 and _player.has_method("take_damage"):
		_player.call("take_damage", damage, global_position)


## 被主角攻击命中。
func take_hit(hit_damage: int, _direction: int, _knockback: float, _launch: float) -> void:
	if _state == "dead" or _state != "chase":
		return
	_health = maxi(0, _health - hit_damage)
	health_changed.emit(_health, max_health)
	_sprite.modulate = Color(1.8, 0.55, 0.55)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)
	if _health <= 0:
		_die()


func _die() -> void:
	if _state == "dead":
		return
	_state = "dead"
	remove_from_group("enemy")
	if _hurtbox != null:
		_hurtbox.set_deferred("collision_layer", 0)
	defeated.emit()


## 淡出并消失。
func fade_out(duration := 2.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)
