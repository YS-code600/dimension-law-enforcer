class_name GifDecoder
## 纯 GDScript 的 GIF89a 解码器(运行时逐帧合成)。
## 支持:全局/局部调色板、透明色、隔行扫描、GCE 延时、disposal 0/1/2/3。
## 返回: { frames: Array[Image], delays_ms: PackedFloat64Array, width: int, height: int }
##       解码失败时 frames 为空数组。


static func decode(path: String) -> Dictionary:
	var data := FileAccess.get_file_as_bytes(path)
	var result := { "frames": [], "delays_ms": PackedFloat64Array(), "width": 0, "height": 0 }
	if data.size() < 13:
		push_error("GIF 文件过小或无法读取: " + path)
		return result

	var pos := 0
	var header := ""
	for i in range(6):
		header += charv(data[i])
	if header != "GIF87a" and header != "GIF89a":
		push_error("不是 GIF 文件: " + path)
		return result

	var screen_w := _u16(data, 6)
	var screen_h := _u16(data, 8)
	var packed := _u8(data, 10)
	var global_table := []  # Array[Color]
	var gct_size := 0
	if packed & 0x80:
		gct_size = 1 << ((packed & 0x07) + 1)
		pos = 13
		global_table = _read_palette(data, pos, gct_size)
		pos += gct_size * 3
	else:
		pos = 13

	var canvas := Image.create(screen_w, screen_h, false, Image.FORMAT_RGBA8)
	var frames: Array = []
	var delays_ms := PackedFloat64Array()

	# 当前帧的 GCE(Graphic Control Extension)信息
	var delay_centis := 8
	var disposal := 0
	var has_transparency := false
	var transparent_index := 0
	var frame_rect := Rect2i(0, 0, 0, 0)

	var prev_disposal := 0
	var prev_rect := Rect2i(0, 0, 0, 0)
	var snapshot := Image.create(1, 1, false, Image.FORMAT_RGBA8)  # disposal=3 用

	while pos < data.size():
		var block := _u8(data, pos)
		if block == 0x3B:  # trailer
			break
		elif block == 0x21:  # extension
			var label := _u8(data, pos + 1)
			pos += 2
			if label == 0xF9:  # Graphic Control Extension
				pos += 1  # block size(通常是 4)
				var gce_packed := _u8(data, pos)
				disposal = (gce_packed >> 2) & 0x07
				has_transparency = (gce_packed & 0x01) != 0
				delay_centis = _u16(data, pos + 1)
				transparent_index = _u8(data, pos + 3)
				pos += 5  # 4 内容 + 1 终止符
			else:
				# 其它扩展:跳过子块
				while true:
					var sz := _u8(data, pos)
					pos += 1
					if sz == 0:
						break
					pos += sz
		elif block == 0x2C:  # Image Descriptor
			var left := _u16(data, pos + 1)
			var top := _u16(data, pos + 3)
			var iw := _u16(data, pos + 5)
			var ih := _u16(data, pos + 7)
			var img_packed := _u8(data, pos + 9)
			var interlaced := (img_packed & 0x40) != 0
			var palette := global_table
			pos += 10
			if img_packed & 0x80:
				var lct_size := 1 << ((img_packed & 0x07) + 1)
				palette = _read_palette(data, pos, lct_size)
				pos += lct_size * 3

			var min_code := _u8(data, pos)
			pos += 1
			# 收集图像数据子块
			var image_bytes := PackedByteArray()
			while true:
				var sz := _u8(data, pos)
				pos += 1
				if sz == 0:
					break
				image_bytes.append_array(data.slice(pos, pos + sz))
				pos += sz

			var raw := _lzw_decode(image_bytes, min_code)
			if raw.is_empty():
				push_error("GIF LZW 解码失败: " + path)
				break

			# 应用上一帧的 disposal
			if prev_disposal == 2:
				_fill_rect(canvas, prev_rect, Color(0, 0, 0, 0))
			elif prev_disposal == 3:
				canvas = snapshot.duplicate()

			# 隔行扫描行序
			var rows: Array[int] = []
			if interlaced:
				var y := 0
				for pass_start in [0, 4, 2, 1]:
					var step := 1 << (3 - [0, 4, 2, 1].find(pass_start))
					y = pass_start
					while y < ih:
						rows.append(y)
						y += step
			else:
				for y in range(ih):
					rows.append(y)

			var pal_size := palette.size()
			for yi in range(ih):
				var dst_row: int = rows[yi]
				for xi in range(iw):
					var idx := raw[yi * iw + xi]
					if has_transparency and idx == transparent_index:
						continue
					if idx < pal_size:
						var c: Color = palette[idx]
						canvas.set_pixel(left + xi, top + dst_row, Color(c.r, c.g, c.b, 1.0))

			# 记录当前帧
			frames.append(canvas.duplicate())
			delays_ms.append(float(delay_centis) * 10.0)
			frame_rect = Rect2i(left, top, iw, ih)

			prev_disposal = disposal
			prev_rect = frame_rect
			if disposal == 3:
				snapshot = canvas.duplicate()
			# disposal 归位(每帧 GCE 独立)
			disposal = 0
			delay_centis = 8
			has_transparency = false
		else:
			# 未知块,跳过
			pos += 1
			return result  # 异常结构,放弃

	result.frames = frames
	result.delays_ms = delays_ms
	result.width = screen_w
	result.height = screen_h
	print("[gif-decode] done: frames=%d delays=%d pos=%d/%d" % [frames.size(), delays_ms.size(), pos, data.size()])
	return result


static func _u8(b: PackedByteArray, i: int) -> int:
	return int(b[i])


static func _u16(b: PackedByteArray, i: int) -> int:
	return int(b[i]) | (int(b[i + 1]) << 8)


static func charv(byte_value: int) -> String:
	return char(byte_value)


static func _read_palette(b: PackedByteArray, start: int, count: int) -> Array:
	var pal := []
	for i in range(count):
		var o := start + i * 3
		pal.append(Color(_u8(b, o) / 255.0, _u8(b, o + 1) / 255.0, _u8(b, o + 2) / 255.0, 1.0))
	return pal


static func _fill_rect(img: Image, r: Rect2i, color: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(r.position.x, r.position.x + r.size.x):
			if x >= 0 and x < img.get_width():
				img.set_pixel(x, y, color)


static func _lzw_decode(bits: PackedByteArray, min_code: int) -> PackedByteArray:
	if min_code < 2:
		min_code = 2
	var clear_code := 1 << min_code
	var end_code := clear_code + 1
	var code_size := min_code + 1

	var dict: Array = []
	var i := 0
	while i < clear_code:
		dict.append(PackedByteArray([i]))
		i += 1
	dict.append(PackedByteArray())  # 占位: clear
	dict.append(PackedByteArray())  # 占位: end

	var out := PackedByteArray()
	var prev := -1
	var bit_pos := 0
	var bytes_total := bits.size()

	while true:
		var code := 0
		for k in range(code_size):
			var byte_idx := bit_pos + k >> 3
			var bit: int = 0
			if byte_idx < bytes_total:
				bit = (_u8(bits, byte_idx) >> ((bit_pos + k) & 7)) & 1
			code |= bit << k
		bit_pos += code_size

		if code == clear_code:
			dict.resize(clear_code)
			dict.append(PackedByteArray())
			dict.append(PackedByteArray())
			code_size = min_code + 1
			prev = -1
			continue
		elif code == end_code:
			break

		var entry: PackedByteArray
		if prev == -1:
			if code >= dict.size():
				break  # 数据损坏
			entry = dict[code]
			out.append_array(entry)
			prev = code
			continue
		elif code < dict.size():
			entry = dict[code]
		elif code == dict.size():
			# KWKWK 特殊情况:引用刚生成的字典项
			entry = dict[prev] + PackedByteArray([dict[prev][0]])
		else:
			break  # 数据损坏

		out.append_array(entry)
		dict.append(dict[prev] + PackedByteArray([entry[0]]))

		# 增长码宽(与 giflib 一致:TODO 对齐 RunningCode/MaxCode1)
		if dict.size() >= (1 << code_size) and code_size < 12:
			code_size += 1
		prev = code

	return out
