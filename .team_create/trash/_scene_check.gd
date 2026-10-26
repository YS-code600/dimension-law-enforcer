extends SceneTree
## 临时自检脚本：加载 res:// 下所有 .tscn，报告加载失败的文件。
## 用法: godot --headless --path <项目目录> --script res://_scene_check.gd


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://", paths)
	var failed := 0
	for path in paths:
		var scene: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		if scene == null or not (scene is PackedScene):
			print("SCENE_FAIL ", path)
			failed += 1
	print("SCENE_CHECK total=", paths.size(), " failed=", failed)
	quit(0 if failed == 0 else 1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out)
			elif entry.ends_with(".tscn"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
