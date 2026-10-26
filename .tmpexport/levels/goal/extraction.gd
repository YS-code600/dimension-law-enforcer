extends Node2D
## 终点撤离点:直升机垂下悬梯。带着同行者接触悬梯即胜利。

@onready var _zone: Area2D = $Zone
@onready var _heli: Sprite2D = $Heli

var _t := 0.0
var _won := false


func _ready() -> void:
	_zone.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
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
