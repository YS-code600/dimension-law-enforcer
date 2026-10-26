extends Node2D
## 即死激光:贯穿全高的能量束,玩家接触立刻死亡。

@onready var _beam: AnimatedSprite2D = $Beam
@onready var _hitbox: Area2D = $Hitbox

var _t := 0.0


func _ready() -> void:
	_hitbox.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_beam.modulate.a = 0.85 + 0.15 * sin(_t * 12.0)
	for body in _hitbox.get_overlapping_bodies():
		_try_kill(body)


func _on_body_entered(body: Node) -> void:
	_try_kill(body)


func _try_kill(body: Node) -> void:
	if not is_visible_in_tree():
		return
	if body.is_in_group("player") and body.has_method("kill_instant"):
		body.call("kill_instant")
