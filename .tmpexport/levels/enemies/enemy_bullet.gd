extends Node2D
## 敌方弹幕:直线飞行,命中主角或场景后消失;可被主角攻击击落。

const HIT_SPARK := preload("res://player/character/effect/hit_spark.tscn")

@export var speed := 310.0
@export var damage := 9

var _dir := Vector2.RIGHT
var _life := 5.0
var _popped := false

@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("projectile")
	_hitbox.body_entered.connect(_on_body_entered)


func setup(dir: Vector2) -> void:
	_dir = dir.normalized()


func _physics_process(delta: float) -> void:
	if _popped:
		return
	global_position += _dir * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _popped:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	pop()


func pop() -> void:
	if _popped:
		return
	_popped = true
	_hitbox.set_deferred("monitorable", false)
	var spark := HIT_SPARK.instantiate()
	spark.global_position = global_position
	spark.scale = Vector2(0.55, 0.55)
	get_parent().add_child.call_deferred(spark)
	queue_free()
