extends StaticBody2D
## 木质掩体:可被主角攻击破坏。

const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")

@export var max_hp := 24

var _hp := 0
var _broken := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	_hp = max_hp


func take_hit(damage: int, direction: int, _knockback: float, _launch: float) -> void:
	if _broken:
		return
	_hp -= damage
	_feedback(direction)
	if _hp <= 0:
		_break()


func _feedback(direction: int) -> void:
	_sprite.modulate = Color(1.0, 0.72, 0.45, 1.0)
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate", Color.WHITE, 0.2)

	_sprite.position = Vector2.ZERO
	var shake := create_tween()
	shake.tween_property(_sprite, "position:x", direction * 4.0, 0.05)
	shake.tween_property(_sprite, "position:x", -direction * 2.0, 0.07)
	shake.tween_property(_sprite, "position:x", 0.0, 0.1)


func _break() -> void:
	_broken = true
	_hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	_sprite.visible = false

	var spark := HIT_SPARK.instantiate()
	spark.global_position = global_position + Vector2(0, -32)
	var host := get_parent()
	if host != null and host.get_parent() != null:
		host = host.get_parent()
	if host != null:
		host.add_child.call_deferred(spark)
	queue_free()
