extends Node2D
## 全白房间:仪器前的研究员。三句台词播完才开打,被打倒后留下最后一句话并淡出。

const DIALOGUE_SCRIPT := preload("res://levels/ui/boss_dialogue.gd")
const BOSS_BAR_SCRIPT := preload("res://levels/ui/boss_bar.gd")
const CORE_ORB := preload("res://levels/goal/core_orb.tscn")
const MAIN_MENU := "res://main.tscn"
const ROOM_SIZE := Vector2(1152, 648)
## 光球生成在仪器(700,600,0.75 倍)右侧的水平位置。
const ORB_POSITION := Vector2(892.0, 566.0)
const ENDING_WHITE := "已获取衍月核心"
const ENDING_YELLOW := "任务完成"
const LINES := [
	"衍月，出自我手",
	"设计之初就是为了阻止军方泛滥地穿越平行时空",
	"她不会为你们所用",
]
const DEATH_LINE := "你们又会将这个混乱的世界变得如何呢"

@onready var _player: Node2D = $Player
@onready var _npc: Node2D = $Scientist

var _dialogue: Node
var _bar: Node
var _fade: ColorRect
var _orb: Node2D
var _ending := false


func _ready() -> void:
	_setup_camera()
	_dialogue = _ensure_dialogue()
	_bar = _ensure_bar()
	_fade = get_node_or_null("Fade/Rect") as ColorRect
	if _fade == null:
		_fade = _make_fade()
	_fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	if not _npc.is_connected("defeated", _on_npc_defeated):
		_npc.connect("defeated", _on_npc_defeated)
	_run_intro.call_deferred()


## 进场演出:锁定操作 → 研究员转向 → 三句台词(每句 2 秒) → 开打。
func _run_intro() -> void:
	await get_tree().create_timer(0.8).timeout
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_npc.call("start_talk")
	_npc.call("face_player")
	await get_tree().create_timer(0.3).timeout
	for line in LINES:
		_dialogue.call("show_line", line, _npc.global_position + Vector2(0, -215), 2.0)
		await get_tree().create_timer(2.15).timeout
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_npc.call("start_fight")
	if _bar != null and _bar.has_method("bind"):
		_bar.call("bind", _npc, "研究员")


func _on_npc_defeated() -> void:
	if _npc == null or not is_instance_valid(_npc):
		_spawn_core_orb()
		return
	_dialogue.call("show_line", DEATH_LINE, _npc.global_position + Vector2(0, -215), 2.0)
	_npc.call("fade_out", 2.0)
	_spawn_core_orb()


## 研究员倒下后,在仪器右侧生成衍月核心光球。
func _spawn_core_orb() -> void:
	if _orb != null or _ending:
		return
	_orb = CORE_ORB.instantiate()
	_orb.position = ORB_POSITION
	add_child(_orb)
	if _orb.has_signal("collected") and not _orb.is_connected("collected", _on_core_collected):
		_orb.connect("collected", _on_core_collected)


func _on_core_collected() -> void:
	if _ending:
		return
	_ending = true
	_play_ending()


## 结束演出:黑屏 → 白字「已获取衍月核心」2 秒 → 黄字「任务完成」→ 回主菜单。
func _play_ending() -> void:
	if _player != null and is_instance_valid(_player):
		_player.process_mode = Node.PROCESS_MODE_DISABLED
	var layer := CanvasLayer.new()
	layer.name = "Ending"
	layer.layer = 20
	add_child(layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC",
		"Noto Sans CJK SC", "PingFang SC", "SimHei",
	])

	var white := Label.new()
	white.text = ENDING_WHITE
	white.add_theme_font_override("font", font)
	white.add_theme_font_size_override("font_size", 40)
	white.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	white.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	white.modulate.a = 0.0
	layer.add_child(white)

	var yellow := Label.new()
	yellow.text = ENDING_YELLOW
	yellow.add_theme_font_override("font", font)
	yellow.add_theme_font_size_override("font_size", 30)
	yellow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1))
	yellow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	yellow.offset_top = 96.0
	yellow.offset_bottom = 96.0
	yellow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yellow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	yellow.visible = false
	layer.add_child(yellow)

	if _fade != null:
		var fade := create_tween()
		fade.tween_property(_fade, "color:a", 1.0, 0.7)
		await fade.finished
	var show_white := create_tween()
	show_white.tween_property(white, "modulate:a", 1.0, 0.45)
	await show_white.finished
	await get_tree().create_timer(2.0).timeout
	yellow.visible = true
	var show_yellow := create_tween()
	show_yellow.tween_property(yellow, "modulate:a", 1.0, 0.4).from(0.0)
	await show_yellow.finished
	await get_tree().create_timer(1.8).timeout
	get_tree().change_scene_to_file(MAIN_MENU)


func _setup_camera() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 16
	cam.limit_right = int(ROOM_SIZE.x)
	cam.limit_bottom = 16 + int(ROOM_SIZE.y)


func _ensure_dialogue() -> Node:
	var node := get_node_or_null("Dialogue")
	if node != null:
		return node
	var layer := CanvasLayer.new()
	layer.name = "Dialogue"
	layer.layer = 4
	layer.set_script(DIALOGUE_SCRIPT)
	add_child(layer)
	return layer


func _ensure_bar() -> Node:
	var bar := get_node_or_null("BossBar")
	if bar != null:
		return bar
	var layer := CanvasLayer.new()
	layer.name = "BossBar"
	layer.layer = 3
	layer.set_script(BOSS_BAR_SCRIPT)
	add_child(layer)
	return layer


func _make_fade() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 10
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "Rect"
	rect.color = Color(0, 0, 0, 1)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	return rect
