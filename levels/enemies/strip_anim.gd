extends RefCounted
## 把横排图集切成 SpriteFrames(运行时读取 PNG,不依赖导入缓存)。


static func build(specs: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for spec in specs:
		_add(frames, spec)
	return frames


static func _add(frames: SpriteFrames, spec: Dictionary) -> void:
	var tex := _load_texture(String(spec["path"]))
	if tex == null:
		return
	var cell := float(tex.get_height())
	var count := int(tex.get_width() / cell)
	var anim: StringName = spec["anim"]
	frames.add_animation(anim)
	frames.set_animation_speed(anim, float(spec.get("fps", 8.0)))
	frames.set_animation_loop(anim, bool(spec.get("loop", true)))
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(cell * float(i), 0.0, cell, cell)
		frames.add_frame(anim, atlas)


static func _load_texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path + ".import"):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null
