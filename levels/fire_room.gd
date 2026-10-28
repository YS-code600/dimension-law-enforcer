extends Node2D
## 火雨房间(现在没有落火了):一块平地,衍月在这里露出真身,用法术迎战。
## 开场演出:衍月飘向画面右侧,身形闪烁几次后定住,随即进入敌对形态。
## 地板视觉、地面碰撞、血条和黑场都在运行时兜底构建,场景文件被外部工具覆盖也不会丢。

const FLOOR_TILE := preload("res://levels/hazards/fire_room_ground.png")
const BOSS_BAR_SCRIPT := preload("res://levels/ui/boss_bar.gd")
const DIALOGUE_SCRIPT := preload("res://levels/ui/boss_dialogue.gd")
const BG_BLUR := preload("res://shaders/bg_blur.gdshader")
const VOID_SCENE := "res://levels/void_room.tscn"
const PLAYER_BASE_FRAMES := preload("res://player/red_frames.tres")
const PLAYER_DEATH_FRAMES := preload("res://player/character/death_frames.tres")
const PISTOL_BANG := preload("res://audio/explosions/grenade_bang.ogg")
const BGM_PATH := "res://audio/music/level3.ogg"
const BGM_DB := -8.0
const GROUND_Y := 600.0
const ROOM_SIZE := Vector2(1152, 648)
const REVEAL_TINT := Color(0.55, 0.9, 1.0)
const REVEAL_NORMAL := Color(1, 1, 1)

## 每击败衍月一次,背景按这个顺序循环切换。
const BG_PATHS := [
	"res://picture/fire_room_bg/01_pink_city.png",
	"res://picture/fire_room_bg/02_orange_silhouette.png",
	"res://picture/fire_room_bg/03_blue_night.png",
	"res://picture/fire_room_bg/04_pixel_city.png",
	"res://picture/fire_room_bg/05_rain_city.jpg",
	"res://picture/fire_room_bg/06_pixel_city_orange.png",
]
const DEFEAT_LINES := [
	"在平行时空穿越的你，是无法击败操控平行时空的我的",
	"我可以输无数次，而你一次都不行",
]
const REPEAT_LINES := ["放弃吧", "可笑", "没用的"]

@onready var _player: Node2D = $Player
@onready var _npc: Node2D = $WizardBoss

var _fade: ColorRect
var _boss_bar: Node
var _dialogue: Node
var _sky: ColorRect
var _bg: TextureRect
var _bg_mat: ShaderMaterial
var _music: AudioStreamPlayer
var _transitioning := false
var _pistol_window := 0.0
var _pistol_unlocked := false
var _self_shot_done := false
var _defeats := 0
var _intro_done := false


func _ready() -> void:
	randomize()
	_ensure_ground_body()
	_ensure_floor_visual()
	_ensure_fade()
	_sky = _ensure_sky()
	_ensure_background()
	_boss_bar = _ensure_boss_bar()
	_dialogue = _ensure_dialogue()
	_setup_camera()
	_ensure_music()
	_setup_death_handling.call_deferred()
	_fade_in()
	_play_intro()


func _process(delta: float) -> void:
	# 背景切换期间持续震动
	if _transitioning and _player != null:
		_player.set("_shake", maxf(float(_player.get("_shake")), 0.9))
	if _pistol_window > 0.0:
		_pistol_window = maxf(0.0, _pistol_window - delta)


## 开场演出:衍月飘到右侧 → 身形蓝白闪烁几次 → 定住并进入敌对形态。
func _play_intro() -> void:
	await get_tree().create_timer(1.0).timeout
	if _npc.has_method("set_following"):
		_npc.call("set_following", false)
	var target := Vector2(ROOM_SIZE.x - 190.0, GROUND_Y - 2.0)
	var glide := create_tween()
	glide.tween_property(_npc, "global_position", target, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await glide.finished
	await get_tree().create_timer(0.2).timeout
	for i in 2:
		_npc.modulate = REVEAL_TINT
		await get_tree().create_timer(0.16).timeout
		_npc.modulate = REVEAL_NORMAL
		await get_tree().create_timer(0.16).timeout
	_intro_done = true
	# 真身显现:结束跟随、无法再交互、300 血量,用法术迎战
	if _npc.has_method("become_hostile"):
		_npc.call("become_hostile")
	if _boss_bar != null and _boss_bar.has_method("bind"):
		_boss_bar.call("bind", _npc, "衍月")
	if not _npc.is_connected("defeated", _on_boss_defeated):
		_npc.connect("defeated", _on_boss_defeated)
	if not _npc.is_connected("revived", _on_boss_revived):
		_npc.connect("revived", _on_boss_revived)


## 击败衍月:回满血量,并开始 2 秒的背景切换演出。
func _on_boss_defeated() -> void:
	_defeats += 1
	_heal_player()
	_start_background_transition(_defeats)


## 衍月复活(倒地 2 秒后)时才弹出对应台词;从第 3 次循环起,台词念完再给手枪提示。
func _on_boss_revived() -> void:
	_show_defeat_line()
	if _defeats >= 3:
		await get_tree().create_timer(2.2).timeout
		_open_pistol_window()


# ---------------------------------------------------------------- 手枪 / 死亡

## 接管主角的死亡:第 3 次循环后改为原地满血复活(并弹出字幕),之前仍是原来的死亡菜单。
func _setup_death_handling() -> void:
	var hud := get_node_or_null("HUD")
	if hud != null:
		var cb := Callable(hud, "_on_player_died")
		if _player.is_connected("died", cb):
			_player.disconnect("died", cb)
	if not _player.is_connected("died", _on_player_died):
		_player.connect("died", _on_player_died)


func _on_player_died() -> void:
	if _defeats >= 3:
		_revive_player()
	else:
		var hud := get_node_or_null("HUD")
		if hud != null and hud.has_method("_on_player_died"):
			hud.call("_on_player_died")


func _revive_player() -> void:
	var max_hp := int(_player.get("max_health"))
	_player.set("state", 0)
	_player.set("velocity", Vector2.ZERO)
	_player.set("health", max_hp)
	_player.set("_death_confirmed", false)
	_player.set("_invuln_until", Time.get_ticks_msec() / 1000.0 + 1.2)
	var sprite := _player.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite != null:
		sprite.sprite_frames = PLAYER_BASE_FRAMES
		sprite.play(&"idle")
	_player.emit_signal("health_changed", max_hp, max_hp)
	if _player.global_position.y > 660.0:
		_player.global_position = Vector2(420.0, 600.0)
	_player.set("_shake", 0.0)
	_open_pistol_window()


## 头顶出现 3 秒字幕;字幕第一次出现后,Q 就一直有效(不再受 3 秒限制)。
func _open_pistol_window() -> void:
	if _self_shot_done:
		return
	_pistol_unlocked = true
	_pistol_window = 3.0
	if _dialogue != null:
		_dialogue.call("show_line", "怀里的手枪似乎在震动\n[按 Q 举枪]", _player.global_position + Vector2(0, -150), 3.0)
	print("[fire_room] 手枪已解锁:任何时候按 Q 都能自尽")


func _unhandled_input(event: InputEvent) -> void:
	if _self_shot_done or not _pistol_unlocked:
		return
	if event.is_action_pressed("switch_dimension"):
		get_viewport().set_input_as_handled()
		_play_self_shot()


## 开枪自尽演出:举枪 → 枪口火光 → 枪响 → 倒地 → 淡出 → 进入全黑房间。
func _play_self_shot() -> void:
	if _self_shot_done:
		return
	_self_shot_done = true
	_pistol_window = 0.0
	print("[fire_room] 按 Q → 开枪自尽")
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	var sprite := _player.get_node_or_null("Sprite") as AnimatedSprite2D
	var gun := _player.get_node_or_null("Gun") as Sprite2D
	var muzzle := _player.get_node_or_null("GunMuzzle") as Sprite2D
	if gun != null:
		gun.visible = true
		gun.z_index = 20
		gun.position = Vector2(2.0, -104.0)
		gun.rotation = -PI * 0.5
	if muzzle != null:
		muzzle.visible = true
		muzzle.z_index = 21
		muzzle.position = Vector2(4.0, -136.0)
		muzzle.rotation = 0.0
	var sfx := AudioStreamPlayer.new()
	sfx.stream = PISTOL_BANG
	sfx.volume_db = -3.0
	add_child(sfx)
	sfx.play()
	if sprite != null:
		sprite.sprite_frames = PLAYER_DEATH_FRAMES
		sprite.play(&"death")
	await get_tree().create_timer(0.35).timeout
	if muzzle != null:
		muzzle.visible = false
	await get_tree().create_timer(0.5).timeout
	if _fade != null:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.7)
		await tw.finished
	get_tree().change_scene_to_file(VOID_SCENE)


## 背景切换演出:模糊 → 画面震动 → 全黑 → 换图 → 淡出黑场,共 2 秒。
func _start_background_transition(index: int) -> void:
	if _bg == null or _transitioning:
		return
	_transitioning = true
	var path: String = BG_PATHS[index % BG_PATHS.size()]
	var next_tex := load(path) as Texture2D
	if _bg_mat != null:
		var blur := create_tween()
		blur.tween_method(func(v: float) -> void: _bg_mat.set_shader_parameter("blur_amount", v), 0.0, 1.0, 0.8)
	if _fade != null:
		var dark := create_tween()
		dark.tween_property(_fade, "color:a", 1.0, 1.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.6).timeout
	if next_tex != null:
		_bg.texture = next_tex
	if _bg_mat != null:
		_bg_mat.set_shader_parameter("blur_amount", 0.0)
	if _fade != null:
		var back := create_tween()
		back.tween_property(_fade, "color:a", 0.0, 0.38)
	await get_tree().create_timer(0.4).timeout
	_transitioning = false


func _heal_player() -> void:
	if _player == null:
		return
	var max_hp := int(_player.get("max_health"))
	_player.set("health", max_hp)
	_player.emit_signal("health_changed", max_hp, max_hp)


func _show_defeat_line() -> void:
	if _dialogue == null:
		return
	var text := ""
	if _defeats <= DEFEAT_LINES.size():
		text = DEFEAT_LINES[_defeats - 1]
	else:
		text = REPEAT_LINES[randi() % REPEAT_LINES.size()]
	_dialogue.call("show_line", text, _npc.global_position + Vector2(0, -168))


# ---------------------------------------------------------------- 运行时兜底构建

func _ensure_node2d(node_name: String) -> Node2D:
	var node := get_node_or_null(node_name) as Node2D
	if node == null:
		node = Node2D.new()
		node.name = node_name
		add_child(node)
	return node


## 地面碰撞:场景里没有就建一个。
func _ensure_ground_body() -> void:
	if get_node_or_null("Ground") != null:
		return
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.position = Vector2(576.0, 680.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1600.0, 160.0)
	cs.shape = rect
	body.add_child(cs)
	add_child(body)


## 地板视觉:平铺图二裁出的地砖。无论场景里那份配置是否被改坏,这里都会校正。
func _ensure_floor_visual() -> void:
	var tex := get_node_or_null("GroundTex") as TextureRect
	if tex == null:
		tex = TextureRect.new()
		tex.name = "GroundTex"
		add_child(tex)
	tex.texture = FLOOR_TILE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tex.stretch_mode = TextureRect.STRETCH_TILE
	tex.position = Vector2(-160.0, GROUND_Y)
	tex.size = Vector2(1472.0, 200.0)
	tex.z_index = 1
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_fade() -> void:
	_fade = get_node_or_null("Fade/Rect") as ColorRect
	if _fade != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 10
	add_child(layer)
	_fade = ColorRect.new()
	_fade.name = "Rect"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _ensure_boss_bar() -> Node:
	var bar := get_node_or_null("BossBar")
	if bar != null:
		return bar
	var layer := CanvasLayer.new()
	layer.name = "BossBar"
	layer.layer = 3
	layer.set_script(BOSS_BAR_SCRIPT)
	add_child(layer)
	return layer


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


## 背景音乐:循环播放 level3,进入房间时淡入。
func _ensure_music() -> void:
	if _music != null:
		return
	var stream := load(BGM_PATH) as AudioStream
	if stream == null:
		push_warning("火雨房间背景音乐加载失败: " + BGM_PATH)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music = AudioStreamPlayer.new()
	_music.name = "Bgm"
	_music.stream = stream
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", BGM_DB, 2.5)


func _ensure_sky() -> ColorRect:
	var sky := get_node_or_null("Sky") as ColorRect
	if sky != null:
		return sky
	sky = ColorRect.new()
	sky.name = "Sky"
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.position = Vector2(-400.0, -400.0)
	sky.size = Vector2(1952.0, 1160.0)
	sky.z_index = -2
	add_child(sky)
	return sky


## 背景图:始终铺满屏幕(按比例裁切),放在最底层的 CanvasLayer 里。
func _ensure_background() -> void:
	if _bg != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "BackgroundLayer"
	layer.layer = -1
	add_child(layer)
	_bg = TextureRect.new()
	_bg.name = "BackdropImage"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_BLUR
	_bg_mat.set_shader_parameter("blur_amount", 0.0)
	_bg.material = _bg_mat
	layer.add_child(_bg)
	_bg.size = get_viewport().get_visible_rect().size
	_bg.texture = load(BG_PATHS[0])
	get_viewport().size_changed.connect(_fit_background)
	# 背景图铺满后,Sky 色块就不再需要了(它会把图挡住)
	if _sky != null and _bg.texture != null:
		_sky.visible = false


func _fit_background() -> void:
	if _bg == null:
		return
	_bg.size = get_viewport().get_visible_rect().size


# ---------------------------------------------------------------- 演出/工具

## 把主角自带的相机锁死在房间画面内。
func _setup_camera() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 16
	cam.limit_right = int(ROOM_SIZE.x)
	cam.limit_bottom = 16 + int(ROOM_SIZE.y)


func _fade_in() -> void:
	if _fade == null:
		return
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.9)
