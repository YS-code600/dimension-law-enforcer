extends SceneTree
## 临时探测:验证精简后场景加载,统计平台节点。


func _init() -> void:
	var ps: PackedScene = load("res://levels/world_main.tscn")
	print("load -> ", ps)
	if ps == null:
		print("FAIL")
		quit()
		return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	await process_frame
	var terrain: Node = inst.get_node("Terrain")
	var count := 0
	var one_way := 0
	for child in terrain.get_children():
		count += 1
		if child.get("one_way"):
			one_way += 1
	print("Terrain children=", count, " one_way=", one_way)
	inst.queue_free()
	quit()
