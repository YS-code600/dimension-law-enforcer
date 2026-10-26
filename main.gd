extends Control
## 主菜单:维度执法者(用户进入游戏的 UI 界面)

const GAME_SCENE := "res://levels/game.tscn"
const INTRO_SCENE := "res://intro.tscn"
const FONT_NAMES := ["Microsoft YaHei UI", "Microsoft YaHei", "Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC", "WenQuanYi Micro Hei", "SimHei"]
const WIZARD_DIR := "res://levels/npc/wizard/"
const WIZARD_FRAME := Vector2(64, 64)
const WIZARD_IDLE_FRAMES := 6

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var menu_layout: VBoxContainer = %MenuLayout
@onready var version_label: Label = %VersionLabel
@onready var toast_label: Label = %ToastLabel
@onready var exit_screen: Control = %ExitScreen
@onready var exit_bar: ColorRect = %ExitBar
@onready var violet_preview: AnimatedSprite2D = %VioletPreview

var _settings_dialog: AcceptDialog
var _exiting := false


func _ready() -> void:
	version_label.text = "VER 0.1.0 // 开发预览"
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_build_settings_dialog()
	_setup_button_prefix(start_button, "开始游戏")
	_setup_button_prefix(settings_button, "设置")
	_setup_button_prefix(quit_button, "退出")
	start_button.grab_focus()
	_build_wizard_preview()
	_play_intro()
	_animate_violet()


## 主界面左侧预览:换成蓝帽法师的待机动画。
func _build_wizard_preview() -> void:
	if violet_preview == null:
		return
	var tex := load(WIZARD_DIR + "idle.png") as Texture2D
	if tex == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 8.0)
	frames.set_animation_loop("idle", true)
	for i in WIZARD_IDLE_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(WIZARD_FRAME.x * float(i), 0.0, WIZARD_FRAME.x, WIZARD_FRAME.y)
		frames.add_frame("idle", atlas)
	violet_preview.sprite_frames = frames
	violet_preview.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not (_settings_dialog and _settings_dialog.visible):
		_on_quit_pressed()


func _on_start_pressed() -> void:
	var packed := load(INTRO_SCENE) as PackedScene
	if packed == null:
		packed = load(GAME_SCENE) as PackedScene
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		_show_toast("游戏场景尚未就绪,敬请期待")


func _on_settings_pressed() -> void:
	_settings_dialog.popup_centered(Vector2i(400, 0))


func _on_quit_pressed() -> void:
	if _exiting:
		return
	_exiting = true
	exit_screen.visible = true
	exit_bar.scale = Vector2(0.001, 1.0)
	start_button.disabled = true
	settings_button.disabled = true
	quit_button.disabled = true
	var tween := create_tween()
	tween.tween_property(exit_bar, "scale:x", 1.0, 2.0)
	tween.tween_callback(func() -> void: get_tree().quit())


func _setup_button_prefix(button: Button, base: String) -> void:
	button.text = base
	button.mouse_entered.connect(func() -> void: button.text = "> " + base)
	button.mouse_exited.connect(func() -> void: button.text = base)
	button.focus_entered.connect(func() -> void: button.text = "> " + base)
	button.focus_exited.connect(func() -> void: button.text = base)


func _build_settings_dialog() -> void:
	_settings_dialog = AcceptDialog.new()
	_settings_dialog.title = "设置"
	_settings_dialog.ok_button_text = "关闭"
	_settings_dialog.min_size = Vector2(380, 0)
	var theme := Theme.new()
	theme.default_font = _make_font(false)
	theme.default_font_size = 16
	_settings_dialog.theme = theme

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var fullscreen := CheckBox.new()
	fullscreen.text = "全屏模式"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fullscreen)

	var vsync := CheckBox.new()
	vsync.text = "垂直同步"
	vsync.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	vsync.toggled.connect(_on_vsync_toggled)
	vbox.add_child(vsync)

	_settings_dialog.add_child(vbox)
	add_child(_settings_dialog)


func _make_font(bold: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = 700 if bold else 400
	return font


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_vsync_toggled(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)


func _play_intro() -> void:
	var target_y := menu_layout.position.y
	menu_layout.position.y = target_y + 24.0
	menu_layout.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(menu_layout, "modulate:a", 1.0, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_layout, "position:y", target_y, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_violet() -> void:
	if violet_preview == null:
		return
	violet_preview.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(violet_preview, "modulate:a", 1.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.modulate.a = 0.0
	toast_label.visible = true
	var tween := create_tween()
	tween.tween_property(toast_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.8)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: toast_label.visible = false)
