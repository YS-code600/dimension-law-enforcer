extends Node
## 手雷投掷组件:监听主角的 J 轻击(attack1),在收招动画结束后向前掷雷。
## 独立于 player.gd 的攻击状态机,避免打断近战判定与连击缓冲。

const GRENADE_SCENE := preload("res://levels/combat/grenade.tscn")
const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")

@export var hand_offset := Vector2(40.0, -78.0)

var _pending := false

@onready var _player: CharacterBody2D = get_parent()
@onready var _sprite: AnimatedSprite2D = _player.get_node("Sprite")


func _ready() -> void:
	# 子节点先于父节点 _ready,此处连接可以确保在 player.gd 收招前处理完投掷。
	_sprite.animation_changed.connect(_on_animation_changed)
	_sprite.animation_finished.connect(_on_animation_finished)


func _on_animation_changed() -> void:
	if _sprite.animation == &"attack1":
		# 空中 J 也使用 attack1,只有地面起手的轻击才附带手雷。
		_pending = _player.is_on_floor()
	else:
		_pending = false


func _on_animation_finished() -> void:
	if not _pending:
		return
	_pending = false
	if _sprite.animation != &"attack1" or not _player.is_inside_tree():
		return
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

	# 极短的姿态前冲和脱手火花,补足 attack1 最后一帧没有专门投掷姿势的问题。
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
