extends Node2D
## 训练木桩:只作为攻击试验目标,被击破后自动复原。

@export var max_hp := 60
@export var respawn_delay := 2.0

var _hp := 0
var _broken := false
var _respawn_timer := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _bar: Node2D = $HealthBar
@onready var _fill: ColorRect = $HealthBar/Fill


func _ready() -> void:
	_hp = max_hp
	_update_bar()


func _process(delta: float) -> void:
	if not _broken:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn()


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _broken:
		return
	_hp = maxi(0, _hp - damage)
	_update_bar()
	_flash(direction)
	if _hp <= 0:
		_break()


func get_hp() -> int:
	return _hp


func is_broken() -> bool:
	return _broken


func _flash(direction: int) -> void:
	_sprite.modulate = Color(1.0, 0.5, 0.55, 1.0)
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate", Color.WHITE, 0.18)

	_sprite.position = Vector2.ZERO
	var wobble := create_tween()
	wobble.tween_property(_sprite, "position:x", direction * 7.0, 0.05)
	wobble.tween_property(_sprite, "position:x", -direction * 3.0, 0.07)
	wobble.tween_property(_sprite, "position:x", 0.0, 0.1)


func _update_bar() -> void:
	var ratio := float(_hp) / float(max_hp)
	_fill.scale.x = maxf(0.001, ratio)


func _break() -> void:
	_broken = true
	_respawn_timer = respawn_delay
	_hurtbox.set_deferred("monitorable", false)
	_bar.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(_sprite, "scale", Vector2(2.0, 0.5), 0.3)


func _respawn() -> void:
	_broken = false
	_hp = max_hp
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2(2.0, 2.0)
	_sprite.modulate = Color(1, 1, 1, 0)
	_bar.visible = true
	_hurtbox.set_deferred("monitorable", true)
	_update_bar()
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.2)
