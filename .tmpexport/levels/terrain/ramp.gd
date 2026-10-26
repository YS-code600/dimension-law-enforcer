extends StaticBody2D
## 45° 斜坡地形。kind="up" 从左下角升到右上;kind="down" 从左上角降到右下。
## 放置:up 节点位置 = 斜坡与地面的交汇角(左下);down 节点位置 = (x, 落点地面高度)。
@export var run := 128.0
@export var rise := 96.0
@export var kind := "up"  # "up" | "down"
@export var body_color := Color(0.05, 0.06, 0.12)
@export var edge_color := Color(1.0, 0.6, 0.22, 0.9)

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _points() -> PackedVector2Array:
	if kind == "down":
		return PackedVector2Array([Vector2(0, 0), Vector2(run, 0), Vector2(0, -rise)])
	return PackedVector2Array([Vector2(0, 0), Vector2(run, 0), Vector2(run, -rise)])


func _ready() -> void:
	var ps := ConvexPolygonShape2D.new()
	ps.points = _points()
	_shape.shape = ps
	queue_redraw()


func _draw() -> void:
	var pts := _points()
	draw_colored_polygon(pts, body_color)
	# 斜面上的发光条(width 沿斜面约 5px)
	if kind == "up":
		draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[2] + Vector2(0, 5), pts[0] + Vector2(0, 5)]), edge_color)
	else:
		draw_colored_polygon(PackedVector2Array([pts[2], pts[1], pts[1] + Vector2(0, 5), pts[2] + Vector2(0, 5)]), edge_color)
