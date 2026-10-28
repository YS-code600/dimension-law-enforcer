extends StaticBody2D
## 地形组件:地板/平台(可单向往上穿过),运行时按导出尺寸生成碰撞体与外观。
## 外观使用 Kenney 像素素材:顶部草皮 + 下方泥土,按 25px 平铺。

const GRASS_PATH := "res://picture/kenney_grass.png"
const DIRT_PATH := "res://picture/kenney_dirt.png"
const TILE := 25.0
const FALLBACK_BODY := Color(0.42, 0.26, 0.18)
const FALLBACK_TOP := Color(0.24, 0.78, 0.45)

@export var size := Vector2(128, 24)
@export var one_way := false
## 以下为旧版外观参数,保留只为兼容已有场景,当前不再参与绘制。
@export var body_color := Color(0.05, 0.06, 0.12)
@export var edge_color := Color(1.0, 0.6, 0.22, 0.9)
@export_enum("Circuit", "Lattice") var pattern_style := 0
@export var pattern_modulate := Color(0.62, 0.8, 1.0, 0.85)

var _grass: Texture2D
var _dirt: Texture2D

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var rs := RectangleShape2D.new()
	rs.size = size
	_shape.shape = rs
	_shape.one_way_collision = one_way
	_shape.one_way_collision_margin = 3.0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grass = _load_texture(GRASS_PATH)
	_dirt = _load_texture(DIRT_PATH)
	queue_redraw()


## 优先走导入资源;导入缓存缺失时直接读 PNG,保证贴图不会丢。
func _load_texture(path: String) -> Texture2D:
	var tex := load(path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rect := Rect2(-w / 2.0, -h / 2.0, w, h)
	var band_h := minf(h, TILE)
	var band := Rect2(-w / 2.0, -h / 2.0, w, band_h)

	if _dirt != null:
		draw_texture_rect(_dirt, rect, true, Color.WHITE)
	else:
		draw_rect(rect, FALLBACK_BODY)

	if _grass != null:
		draw_texture_rect(_grass, band, true, Color.WHITE)
	else:
		draw_rect(band, FALLBACK_TOP)

	# 底部压一层暗色,和背景拉开层次
	if not one_way:
		draw_rect(Rect2(-w / 2.0, h / 2.0 - 3.0, w, 3.0), Color(0, 0, 0, 0.28))
