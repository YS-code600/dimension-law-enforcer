extends Node2D
## 终点传送门:玩家接触后先播放最后一句简报,再进入火雨房间。
## 不播放 WIN/WARNING,也不播放爆炸。

const NEXT_SCENE := "res://levels/final_briefing.tscn"
const BOSS_ROOM := "res://levels/fire_room.tscn"
const PORTAL_PATH := "res://picture/portal_gray.png"

@onready var _zone: Area2D = $Zone
@onready var _portal: Sprite2D = $Portal

var _t := 0.0
var _leaving := false


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
	if _leaving:
		return
	_t += delta
	# 传送门轻微呼吸
	_portal.scale = Vector2(2.4, 2.4) * (1.0 + sin(_t * 2.2) * 0.03)
	for body in _zone.get_overlapping_bodies():
		_try_enter(body)


func _on_body_entered(body: Node) -> void:
	_try_enter(body)


func _try_enter(body: Node) -> void:
	if _leaving or not body.is_in_group("player"):
		return
	_leaving = true
	# 已经在打 Boss 的途中(死过一次再进来):跳过简报,直接回火雨房间继续那一阶段
	var progress := get_node_or_null("/root/BossProgress")
	if progress != null and int(progress.get("phase")) > 1:
		get_tree().call_deferred("change_scene_to_file", BOSS_ROOM)
		return
	get_tree().call_deferred("change_scene_to_file", NEXT_SCENE)
