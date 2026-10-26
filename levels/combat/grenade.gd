extends CharacterBody2D
## 主角投出的手雷:沿抛物线向前飞行,落地/撞墙后引爆;未命中时由引信兜底。
## 视觉使用像素手雷,爆炸交给独立的 grenade_explosion.tscn,不污染投掷物本体。

const EXPLOSION_SCENE := preload("res://player/character/effect/grenade_explosion.tscn")

@export var throw_speed := 340.0
@export var throw_lift := 330.0
@export var gravity := 1500.0
@export var arm_time := 0.16
@export var fuse_time := 1.35
@export var spin_speed := 7.0

var _facing := 1
var _elapsed := 0.0
var _detonated := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _trail: CPUParticles2D = $Trail


func _ready() -> void:
	add_to_group(&"player_grenade")
	_trail.emitting = true


## 由主角在投掷动作的最后一帧调用。
func setup(facing: int) -> void:
	_facing = -1 if facing < 0 else 1
	velocity = Vector2(throw_speed * _facing, -throw_lift)
	_sprite.flip_h = _facing < 0
	_sprite.rotation = -0.25 * _facing


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	_elapsed += delta
	velocity.y = minf(velocity.y + gravity * delta, 1450.0)
	_sprite.rotation += spin_speed * _facing * delta
	move_and_slide()

	# 手雷刚脱手时给一小段保险时间,避免贴墙投掷时炸到自己面前;
	# 超过保险时间后,碰到地形立刻引爆。
	if _elapsed >= arm_time and (is_on_floor() or is_on_wall() or is_on_ceiling()):
		_detonate()
		return
	if _elapsed >= fuse_time:
		_detonate()


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	_trail.emitting = false
	_trail.visible = false
	var host := get_parent()
	if host != null:
		var blast := EXPLOSION_SCENE.instantiate() as Node2D
		host.add_child(blast)
		blast.global_position = global_position + Vector2(0.0, -2.0)
	queue_free()
