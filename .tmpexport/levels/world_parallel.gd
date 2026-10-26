extends Node2D
## 平行世界配色脚本:把地形边缘/主体换成冷色霓虹。


func _ready() -> void:
	for child in $Terrain.get_children():
		if child.has_method("set"):
			child.set("edge_color", Color(0.3, 0.9, 1.0, 0.9))
			child.set("body_color", Color(0.04, 0.04, 0.10))
