extends CanvasLayer
## 蓝色精灵的交互菜单:按 F 后在她右边弹出「1：我要变强 / 2：技能改换 / 3：离开」,
## 选 1 打开变强界面,选 2 打开技能改换界面,选 3 / ESC 关闭。菜单打开时暂停游戏。

signal closed(used_upgrade: bool)

const UI_FONT := preload("res://levels/ui/ui_font.gd")
## 选项框相对精灵位置的偏移(屏幕像素,放在她右侧)
const OPTION_OFFSET := Vector2(48.0, -112.0)

@onready var _root: Control = $Root
@onready var _options: PanelContainer = $Root/Options
@onready var _screen: Control = $Root/UpgradeScreen
@onready var _skill_screen: Control = $Root/SkillScreen
@onready var _option_buttons := {
	"upgrade": $Root/Options/Lines/Option1,
	"skill": $Root/Options/Lines/Option2,
	"whale": $Root/Options/Lines/Option3,
	"leave": $Root/Options/Lines/Option4,
}

var _npc: Node2D
var _opened := false
var _used_upgrade := false
var _paused_by_us := false
## 时停时被冻结的角色(主角 + 同伴),关闭时按原样恢复
var _frozen: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI_FONT.apply(_root, 16)
	visible = false
	_options.visible = false
	_screen.visible = false
	_skill_screen.visible = false
	_screen.connect("close_requested", _on_screen_close)
	_skill_screen.connect("close_requested", _on_screen_close)
	# 三个选项也能直接用鼠标点
	for key in _option_buttons.keys():
		(_option_buttons[key] as Button).pressed.connect(_on_option_pressed.bind(key))
	set_process(false)


func is_open() -> bool:
	return _opened


func open(npc: Node2D) -> void:
	if _opened:
		return
	_npc = npc
	_opened = true
	_used_upgrade = false
	visible = true
	_options.visible = true
	_screen.visible = false
	_skill_screen.visible = false
	_pause_game()
	_refresh_position()
	set_process(true)


func close() -> void:
	if not _opened:
		return
	var used := _used_upgrade
	_opened = false
	_used_upgrade = false
	visible = false
	_options.visible = false
	_screen.visible = false
	_skill_screen.visible = false
	set_process(false)
	_resume_game()
	closed.emit(used)


func _show_upgrade() -> void:
	_used_upgrade = true
	_options.visible = false
	_screen.call("open")


func _show_skill() -> void:
	_used_upgrade = true
	_options.visible = false
	_skill_screen.call("open")


func _exit_tree() -> void:
	# 场景被卸载时别把游戏留在暂停里。
	_resume_game()


func _on_screen_close() -> void:
	close()


## 鼠标点选项:和按 1 / 2 / 3 / 4 等价。
func _on_option_pressed(key: String) -> void:
	if not _opened:
		return
	match key:
		"upgrade":
			_show_upgrade()
		"skill":
			_show_skill()
		"whale":
			_interact_with_npc()
		_:
			close()


## 与鲸鱼娘互动:关闭菜单,让跟随者随机播一段动作。
func _interact_with_npc() -> void:
	if is_instance_valid(_npc) and _npc.has_method("play_random_reaction"):
		_npc.call("play_random_reaction")
	close()


func _input(event: InputEvent) -> void:
	if not _opened or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	if _screen.visible or _skill_screen.visible:
		return
	if code == KEY_1 or code == KEY_KP_1:
		get_viewport().set_input_as_handled()
		_show_upgrade()
	elif code == KEY_2 or code == KEY_KP_2:
		get_viewport().set_input_as_handled()
		_show_skill()
	elif code == KEY_3 or code == KEY_KP_3:
		get_viewport().set_input_as_handled()
		_interact_with_npc()
	elif code == KEY_4 or code == KEY_KP_4:
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if _opened and _options.visible:
		_refresh_position()


## 把选项框放精灵右边(屏幕坐标),并夹在屏幕内。
func _refresh_position() -> void:
	if not is_instance_valid(_npc):
		return
	var vp := get_viewport().get_visible_rect().size
	var anchor: Vector2 = get_viewport().get_canvas_transform() * _npc.global_position
	# 布局还没算完时 size 是 0,退回最小尺寸,免得夹取算错。
	var size := _options.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = _options.get_combined_minimum_size()
	var target := anchor + OPTION_OFFSET
	target.x = clampf(target.x, 12.0, maxf(12.0, vp.x - size.x - 12.0))
	target.y = clampf(target.y, 12.0, maxf(12.0, vp.y - size.y - 12.0))
	_options.position = target


func _pause_game() -> void:
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	_freeze_actors()


func _resume_game() -> void:
	_unfreeze_actors()
	if not _paused_by_us:
		return
	_paused_by_us = false
	get_tree().paused = false


## 除了暂停整棵树,再把主角和同伴精灵本身停掉(速度清零 + 处理禁用),
## 这样哪怕外部把暂停解掉了,这两个也一定是「时停」状态。
func _freeze_actors() -> void:
	_unfreeze_actors()
	var targets: Array = []
	for node in get_tree().get_nodes_in_group("player"):
		targets.append(node)
	if is_instance_valid(_npc):
		targets.append(_npc)
	for node in targets:
		if node == null or not is_instance_valid(node) or not (node is Node):
			continue
		var body := node as Node
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity = Vector2.ZERO
		_frozen.append({"node": body, "mode": body.process_mode})
		body.process_mode = Node.PROCESS_MODE_DISABLED


func _unfreeze_actors() -> void:
	for entry in _frozen:
		var node: Variant = entry.get("node")
		if node != null and is_instance_valid(node):
			(node as Node).process_mode = int(entry.get("mode", Node.PROCESS_MODE_INHERIT))
	_frozen.clear()
