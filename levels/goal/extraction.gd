extends Node2D
## 终点撤离点:地面上的灰色传送门。带着同行者走进传送门即胜利。

const EXPLOSION_FRAMES := preload("res://levels/goal/explosion_frames.tres")
const PORTAL_PATH := "res://picture/portal_gray.png"

@onready var _zone: Area2D = $Zone
@onready var _portal: Sprite2D = $Portal

var _t := 0.0
var _won := false
var _exploded := false


func _ready() -> void:
	add_to_group("extraction")
	_portal.texture = _load_texture(PORTAL_PATH)
	_zone.body_entered.connect(_on_body_entered)


## 优先走导入资源;导入缓存缺失时直接读 PNG。
func _load_texture(path: String) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_t += delta
	# 传送门轻微呼吸
	_portal.scale = Vector2(2.4, 2.4) * (1.0 + sin(_t * 2.2) * 0.03)
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
	anim.position = _portal.position + Vector2(0, -30)
	anim.scale = Vector2(3.6, 3.6)
	anim.z_index = 20
	add_child(anim)
	anim.play(&"explode")
	anim.animation_finished.connect(anim.queue_free)
	_portal.visible = false
