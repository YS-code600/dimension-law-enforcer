extends Node2D
## 视差背景的根节点：窗口尺寸变化时让所有绘制层重绘。


func _ready() -> void:
	get_viewport().size_changed.connect(_redraw_all)
	_redraw_all()


func _redraw_all() -> void:
	_redraw_node(self)


func _redraw_node(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child in node.get_children():
		_redraw_node(child)
