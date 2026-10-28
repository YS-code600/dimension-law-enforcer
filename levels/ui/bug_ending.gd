extends CanvasLayer
## 三次击败豆包后的真结局：
## 对话框自白 → 黑屏「bug改完了 WIN」→ 回到主菜单。

const MAIN_MENU := "res://main.tscn"
const CONFESSION := "对不起，我以最直白，最不绕弯子的话告诉你，游戏的[color=#ff6b8a]bug[/color]是我修复出来的"
const FONT_NAMES := [
	"Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC",
	"Noto Sans CJK SC", "PingFang SC", "SimHei",
]

var _black: ColorRect
var _win: RichTextLabel
var _started := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_gameplay_ui()
	_build_ui()
	_run()


## 结局时收起战斗 HUD，避免残血/增援提示压住对话框。
func _hide_gameplay_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for child in scene.get_children():
		if child is CanvasLayer and child.name in [&"HUD", &"BossBar", &"Dialogue"]:
			(child as CanvasLayer).visible = false
	var player := scene.get_node_or_null("Player")
	if player != null:
		var raid := player.get_node_or_null("RaidHud")
		if raid is CanvasLayer:
			(raid as CanvasLayer).visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var font := _make_font(false)
	var font_bold := _make_font(true)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.62
	panel.anchor_bottom = 0.9
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.035, 0.07, 0.96)
	style.border_color = Color(0.22, 0.78, 1.0, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	var name_label := Label.new()
	name_label.text = "豆包"
	name_label.add_theme_font_override("font", font_bold)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.64, 0.95, 1.0))
	row.add_child(name_label)

	var role := Label.new()
	role.text = "// BUG REPORT"
	role.add_theme_font_override("font", font)
	role.add_theme_font_size_override("font_size", 11)
	role.add_theme_color_override("font_color", Color(0.3, 0.62, 0.74))
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(role)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var hint := Label.new()
	hint.text = "自动继续…"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.34, 0.52, 0.6))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.25, 0.8, 1.0, 0.2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = CONFESSION
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(0, 84)
	body.add_theme_font_override("normal_font", font)
	body.add_theme_font_size_override("normal_font_size", 22)
	body.add_theme_constant_override("line_separation", 9)
	body.add_theme_color_override("default_color", Color(0.88, 0.95, 1.0))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_black)


func _make_font(bold: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = 700 if bold else 400
	return font


func _run() -> void:
	if _started:
		return
	_started = true
	get_tree().paused = true
	await get_tree().create_timer(5.2, true).timeout
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_black, "color:a", 1.0, 0.7)
	await fade.finished
	_show_win()
	await get_tree().create_timer(3.4, true).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _show_win() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	_win = RichTextLabel.new()
	_win.bbcode_enabled = true
	_win.fit_content = true
	_win.scroll_active = false
	_win.custom_minimum_size = Vector2(560, 120)
	_win.text = "[center][color=#9feaff]bug改完了[/color] [color=#ffd24a]WIN[/color][/center]"
	_win.add_theme_font_override("normal_font", _make_font(true))
	_win.add_theme_font_size_override("normal_font_size", 72)
	_win.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.95))
	_win.add_theme_constant_override("outline_size", 14)
	_win.add_theme_color_override("font_shadow_color", Color(0.2, 0.8, 1.0, 0.25))
	_win.add_theme_constant_override("shadow_offset_y", 6)
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.modulate.a = 0.0
	center.add_child(_win)

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_win, "modulate:a", 1.0, 0.55)
