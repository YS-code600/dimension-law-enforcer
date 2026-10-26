extends Node2D
## 终点撤离点:直升机垂下悬梯。带着同行者接触悬梯即胜利。

const EXPLOSION_FRAMES := preload("res://levels/goal/explosion_frames.tres")

@onready var _zone: Area2D = $Zone
@onready var _heli: Sprite2D = $Heli

var _t := 0.0
var _won := false
var _exploded := false


func _ready() -> void:
	add_to_group("extraction")
	_zone.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_t += delta
	_heli.position.y = -500.0 + sin(_t * 1.6) * 4.0
	if _won:
		return
	for body in _zone.get_overlapping_bodies():
		_try_win(body)


func _on_body_entered(body: Node) -> void:
	_try_win(body)


func _try_win(body: Node) -> void:
	if _won or not body.is_in_group("player"):
		return
	if body is CharacterBody2D and not (body as CharacterBody2D).is_on_floor():
		return
	var companion := get_tree().get_first_node_in_group("companion")
	if companion == null or not companion.has_method("is_following"):
		return
	if not companion.is_following():
		return
	if companion.global_position.distance_to(body.global_position) > 520.0:
		return
	if body.has_method("play_win") and body.play_win():
		_won = true


## 结局演出:在直升机的位置播放爆炸动画,并把直升机本身从画面上抹掉。
func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var anim := AnimatedSprite2D.new()
	anim.name = "Explosion"
	anim.sprite_frames = EXPLOSION_FRAMES
	anim.position = _heli.position + Vector2(0, 60)
	anim.scale = Vector2(3.6, 3.6)
	anim.z_index = 20
	add_child(anim)
	anim.play(&"explode")
	anim.animation_finished.connect(anim.queue_free)
	_heli.visible = false
