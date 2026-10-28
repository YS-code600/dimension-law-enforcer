class_name CyberBox
extends StyleBox
## 赛博朋克切角面板:左上/右下切角六边形 + 霓虹描边。
## 用作 Button 与 PanelContainer 的 stylebox(normal/hover/pressed/focus/panel)。

@export var bg_color := Color(0, 0, 0, 0.78)
@export var border_color := Color(0, 1, 1, 0.85)
@export var border_width := 2.0
@export var corner := 12.0


func _draw(rid: RID, rect: Rect2) -> void:
	var outer := _clip(rect)
	RenderingServer.canvas_item_add_polygon(rid, outer, PackedColorArray([border_color]))
	var i := border_width
	var inner_rect := Rect2(rect.position + Vector2(i, i), rect.size - Vector2(i * 2.0, i * 2.0))
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return
	RenderingServer.canvas_item_add_polygon(rid, _clip(inner_rect), PackedColorArray([bg_color]))


func _clip(rect: Rect2) -> PackedVector2Array:
	var c := minf(corner, rect.size.x * 0.4)
	var p := rect.position
	var s := rect.size
	return PackedVector2Array([
		p + Vector2(c, 0.0),
		p + Vector2(s.x, 0.0),
		p + Vector2(s.x, s.y - c),
		p + Vector2(s.x - c, s.y),
		p + Vector2(0.0, s.y),
		p + Vector2(0.0, c),
	])
