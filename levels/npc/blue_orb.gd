extends Area2D
## 衍月的蓝色爆球:向指定方向飞出,命中主角造成伤害,也可被主角攻击击落。

const DAMAGE := 7
const SPEED := 175.0
const LIFETIME := 4.0

var _dir := Vector2.RIGHT
var _life := LIFETIME
var _dead := false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	_sprite.play(&"burst")


func setup(dir: Vector2) -> void:
	_dir = dir.normalized()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += _dir * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		pop()


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.call("take_damage", DAMAGE, global_position)
	pop()


## 命中/超时/被主角击落时炸开消失。
func pop() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitorable", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", _sprite.scale * 2.2, 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
