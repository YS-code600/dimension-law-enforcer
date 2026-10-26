extends Node
## 手雷投掷组件:按下 E(grenade)即向前掷雷,独立于 player.gd 的近战状态机。
## J 轻击不再附带手雷;投掷冷却由本组件独立计时,默认 2 秒。

const GRENADE_SCENE := preload("res://levels/combat/grenade.tscn")
const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")

@export var hand_offset := Vector2(40.0, -78.0)
@export var cooldown := 2.0

var _ready_at := -99.0

@onready var _player: CharacterBody2D = get_parent()
@onready var _sprite: AnimatedSprite2D = _player.get_node("Sprite")


func _physics_process(_delta: float) -> void:
	if not Input.is_action_just_pressed("grenade"):
		return
	if _player == null or not _player.is_inside_tree():
		return
	if not bool(_player.call("can_throw_grenade")):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ready_at:
		return
	_ready_at = now + maxf(cooldown, 0.0)
	_throw_grenade()


func _throw_grenade() -> void:
	var facing := -1 if _sprite.flip_h else 1
	var origin := _player.global_position + Vector2(hand_offset.x * facing, hand_offset.y)
	var host := _player.get_parent()
	if host == null:
		return

	var grenade := GRENADE_SCENE.instantiate()
	host.add_child(grenade)
	grenade.global_position = origin
	if grenade.has_method("setup"):
		grenade.call("setup", facing)

	# 极短的姿态前冲和脱手火花,补足投掷没有专门动画的问题。
	var sprite_start := _sprite.position
	var recoil := _player.create_tween()
	recoil.tween_property(_sprite, "position:x", sprite_start.x + facing * 5.0, 0.05)
	recoil.tween_property(_sprite, "position:x", sprite_start.x, 0.13)

	var release_fx := HIT_SPARK.instantiate()
	host.add_child(release_fx)
	release_fx.global_position = origin
	release_fx.scale = Vector2(0.7, 0.7)
	release_fx.rotation = randf_range(-0.4, 0.4)

	var shake = _player.get("_shake")
	if shake != null:
		_player.set("_shake", maxf(float(shake), 0.12))
