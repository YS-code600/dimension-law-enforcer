extends Area2D
## 从天而降的火焰:落到地面后停留 1 秒熄灭,碰到主角造成 5 点伤害。

const DAMAGE := 5
const LINGER_TIME := 1.0
const FADE_TIME := 0.35

@export var fall_speed := 210.0
@export var ground_y := 600.0

var _landed := false
var _life := 0.0
var _damaged := false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_sprite.play(&"burn")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not _landed:
		position.y += fall_speed * delta
		if position.y >= ground_y:
			position.y = ground_y
			_landed = true
		return

	_life += delta
	var fade_from := LINGER_TIME - FADE_TIME
	if _life > fade_from:
		modulate.a = clampf((LINGER_TIME - _life) / FADE_TIME, 0.0, 1.0)
	if _life >= LINGER_TIME:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _damaged or not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		_damaged = true
		body.call("take_damage", DAMAGE, global_position)
