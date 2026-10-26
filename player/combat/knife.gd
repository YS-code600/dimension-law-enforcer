extends Area2D
## 远程风格投出的飞刀:水平飞行,命中敌人/木箱/敌方弹幕或地形后消失。

const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")

@export var speed := 820.0
@export var max_range := 720.0
@export var damage := 12
@export var knockback := 170.0
@export var launch := -40.0

var _dir := 1
var _travel := 0.0
var _done := false

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(&"player_knife")
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(dir: int) -> void:
	_dir = 1 if dir >= 0 else -1
	_sprite.flip_h = _dir < 0


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	global_position.x += step * _dir
	_travel += step
	if _travel >= max_range:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _done:
		return
	var target = area.get_parent()
	if target == null:
		return
	if target.is_in_group(&"projectile"):
		_done = true
		target.call("pop")
		_burst()
		queue_free()
		return
	if target.has_method("take_hit"):
		_done = true
		target.call("take_hit", damage, _dir, knockback, launch)
		_burst()
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _done or body.is_in_group(&"player"):
		return
	_done = true
	if body.has_method("take_hit"):
		body.call("take_hit", damage, _dir, knockback, launch)
	_burst()
	queue_free()


func _burst() -> void:
	var spark := HIT_SPARK.instantiate()
	spark.scale = Vector2(0.55, 0.55)
	spark.rotation = randf_range(-0.5, 0.5)
	var host := get_parent()
	if host == null:
		return
	host.add_child(spark)
	spark.global_position = global_position
