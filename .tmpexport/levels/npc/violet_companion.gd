extends Node2D
## 紫发少女(全息投影):在主线地图 1/4 处等待。
## 靠近后按任意攻击键缔结同行,之后跨维度跟随主角。

@export var interact_range := 130.0
@export var follow_offset := Vector2(74.0, 80.0)

var _following := false
var _player: Node2D
var _time := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _glow: Sprite2D = $Glow
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	add_to_group("companion")
	_prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player")


func is_following() -> bool:
	return _following


func _physics_process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * 2.0) * 3.0
	_glow.modulate.a = 0.3 + sin(_time * 2.4) * 0.06

	if _following:
		_follow(delta)
	else:
		_idle()


func _idle() -> void:
	if _player == null:
		return
	var distance := global_position.distance_to(_player.global_position)
	_prompt.visible = distance < 240.0
	if distance <= interact_range and _attack_pressed():
		_recruit()


func _attack_pressed() -> bool:
	return Input.is_action_just_pressed("attack_light") \
		or Input.is_action_just_pressed("attack_heavy") \
		or Input.is_action_just_pressed("attack_dash")


func _recruit() -> void:
	_following = true
	_prompt.visible = false
	_persist.call_deferred()
	var tween := create_tween()
	tween.tween_property(_glow, "scale", Vector2(0.78, 0.78), 0.16)
	tween.tween_property(_glow, "scale", Vector2(0.65, 0.65), 0.32)


## 离开主线世界节点,保证切换维度后仍跟随主角。
func _persist() -> void:
	var target := get_tree().current_scene
	if target == null:
		target = get_parent()
		while target != null and target.name != "Game":
			target = target.get_parent()
	if target != null and get_parent() != target:
		reparent(target, true)


func _follow(delta: float) -> void:
	if _player == null:
		return
	var facing := int(_player.get("_facing"))
	var target := _player.global_position + Vector2(-facing * follow_offset.x, -follow_offset.y)
	target.y += sin(_time * 2.0) * 4.0
	var weight := 1.0 - exp(-5.0 * delta)
	global_position = global_position.lerp(target, weight)
	if global_position.distance_to(target) > 700.0:
		global_position = target
	_sprite.flip_h = facing < 0
