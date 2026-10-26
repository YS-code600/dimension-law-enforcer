extends Node2D
## 近战兵:持刀冲向主角,不发射弹幕。

@export var max_hp := 24
@export var speed := 72.0
@export var detection_range := 460.0
@export var contact_damage := 12
@export var hit_stun := 0.5

var _hp := 0
var _player: Node2D
var _spawn_x := 0.0
var _facing := 1
var _dead := false
var _attack_cd := 0.0
var _walk_t := 0.0
var _stun_time := 0.0

@onready var _body: Sprite2D = $Body
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemy")
	_hp = max_hp
	_spawn_x = global_position.x
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _stun_time > 0.0:
		_stun_time -= delta
		_body.position.y = 0.0
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return

	var to_player := _player.global_position - global_position
	if absf(to_player.x) > detection_range or absf(to_player.y) > 160.0:
		_walk_t += delta * 3.0
		_body.position.y = sin(_walk_t) * 0.8
		return

	_facing = -1 if to_player.x < 0.0 else 1
	_body.flip_h = _facing < 0

	if absf(to_player.x) > 34.0:
		global_position.x = clampf(
			global_position.x + _facing * speed * delta,
			_spawn_x - 44.0,
			_spawn_x + 44.0
		)
		_walk_t += delta * 10.0
		_body.position.y = sin(_walk_t) * 1.0
	else:
		_body.position.y = 0.0

	if absf(to_player.x) < 42.0 and absf(to_player.y) < 56.0 and _attack_cd <= 0.0:
		_attack_cd = 1.0
		if _player.has_method("take_damage"):
			_player.take_damage(contact_damage, global_position)
		_body.position.x = _facing * 4.0
		var tw := create_tween()
		tw.tween_property(_body, "position:x", 0.0, 0.12)


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _dead:
		return
	_hp -= damage
	_stun_time = hit_stun
	_attack_cd = maxf(_attack_cd, 0.8)
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
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.28)
	tw.chain().tween_callback(queue_free)
