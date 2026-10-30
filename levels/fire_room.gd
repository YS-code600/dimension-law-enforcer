extends Node2D
## 火雨房间(现在没有落火了):一块平地,衍月在这里露出真身,用法术迎战。
## 开场演出:衍月飘向画面右侧,身形闪烁几次后定住,随即进入敌对形态。
## 地板视觉、地面碰撞、血条和黑场都在运行时兜底构建,场景文件被外部工具覆盖也不会丢。

const FLOOR_TILE := preload("res://levels/hazards/fire_room_ground.png")
const BOSS_BAR_SCRIPT := preload("res://levels/ui/boss_bar.gd")
const DIALOGUE_SCRIPT := preload("res://levels/ui/boss_dialogue.gd")
const BG_BLUR := preload("res://shaders/bg_blur.gdshader")
## 打完最后一阶段 Boss 后先播鲸鱼娘的 galgame 式对白,再进黑房间
const WHALE_BRIEFING := "res://levels/whale_briefing.tscn"
const PLAYER_BASE_FRAMES := preload("res://player/red_frames.tres")
const BGM_PATH := "res://audio/music/level3.ogg"
const BGM_DB := -8.0
const GROUND_Y := 600.0
const BOSS_FLY_Y := 440.0
const ROOM_SIZE := Vector2(1152, 648)
const REVEAL_TINT := Color(0.55, 0.9, 1.0)
const REVEAL_NORMAL := Color(1, 1, 1)

## 背景:[0] 是最开始的场景;之后每被打倒一次就换成下一张(见 BOSS_REVIVES)。
const BG_PATHS := [
	"res://picture/fire_room_bg/07_kenney_desert.png",
	"res://picture/fire_room_bg/01_pink_city.png",
	"res://picture/fire_room_bg/08_blue_night_skyline.png",
	"res://picture/fire_room_bg/09_dark_city.webp",
	"res://picture/fire_room_bg/02_orange_silhouette.png",
]
## Boss 被打倒后原地复活的次数:每复活一次就换一张背景。
const BOSS_REVIVES := 4
## 第几次被打倒才真正结束(不再复活),进入真结局。
const FINAL_DEFEAT := BOSS_REVIVES + 1
## 每次打倒 Boss 掉的 token(按阶段顺序)
const TOKENS_PER_PHASE := [200, 400, 800, 1200, 1600]
## 死亡后退回的第一房间
const FIRST_ROOM := "res://levels/game.tscn"
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
var _defeats := 0
var _intro_done := false
var _returning_home := false


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


## 开场演出:衍月飘到右侧 → 身形蓝白闪烁几次 → 定住并进入敌对形态。
func _play_intro() -> void:
	# 上次死在 Boss 房间:直接从那一阶段开打,不放开场演出
	var resume_phase := int(BossProgress.phase)
	if resume_phase > 1:
		_resume_phase(resume_phase)
		return
	await get_tree().create_timer(1.0).timeout
	if _npc.has_method("set_following"):
		_npc.call("set_following", false)
	var target := Vector2(ROOM_SIZE.x - 190.0, BOSS_FLY_Y)
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
		_boss_bar.call("bind", _npc, "豆包")
	if not _npc.is_connected("defeated", _on_boss_defeated):
		_npc.connect("defeated", _on_boss_defeated)
	if not _npc.is_connected("revived", _on_boss_revived):
		_npc.connect("revived", _on_boss_revived)


## 从上次死亡的阶段继续:跳过开场演出,Boss 直接以该阶段的状态开战。
func _resume_phase(phase: int) -> void:
	_defeats = clampi(phase - 1, 0, FINAL_DEFEAT - 1)
	_intro_done = true
	if _npc.has_method("set_following"):
		_npc.call("set_following", false)
	_npc.global_position = Vector2(ROOM_SIZE.x - 190.0, BOSS_FLY_Y)
	_npc.set("_phase", _defeats)
	if _npc.has_method("become_hostile"):
		_npc.call("become_hostile")
	_apply_background_now(_defeats)
	if _boss_bar != null and _boss_bar.has_method("bind"):
		_boss_bar.call("bind", _npc, "豆包")
	if not _npc.is_connected("defeated", _on_boss_defeated):
		_npc.connect("defeated", _on_boss_defeated)
	if not _npc.is_connected("revived", _on_boss_revived):
		_npc.connect("revived", _on_boss_revived)


## 击败豆包:前 BOSS_REVIVES 次回满血量 + 换背景并复活;最后一次直接进全黑房间。
func _on_boss_defeated() -> void:
	_defeats += 1
	_award_tokens(_defeats)
	if _defeats >= FINAL_DEFEAT:
		_finish_run()
		return
	_heal_player()
	_start_background_transition(_defeats)


## 打倒一次 Boss 掉一份 token(200/400/800/1200/1600),并在它身上飘一行字。
func _award_tokens(index: int) -> void:
	if index <= 0 or index > TOKENS_PER_PHASE.size():
		return
	var amount := int(TOKENS_PER_PHASE[index - 1])
	var tokens := get_node_or_null("/root/Tokens")
	if tokens != null:
		tokens.call("add", amount)
	_pop_token_text(amount)


func _pop_token_text(amount: int) -> void:
	var label := Label.new()
	label.text = "+%d TOKEN" % amount
	label.z_index = 40
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var start := Vector2(560.0, 360.0)
	if _npc != null and is_instance_valid(_npc):
		start = _npc.global_position + Vector2(-52.0, -140.0)
	label.global_position = start
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", start.y - 96.0, 1.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)


## 打完最后一阶段 Boss:黑屏后直接进入全黑房间(不再放 BUG 结局演出)。
func _finish_run() -> void:
	if _returning_home:
		return
	_returning_home = true
	# Boss 打完,清掉「从某阶段继续」的进度
	var progress := get_node_or_null("/root/BossProgress")
	if progress != null:
		progress.call("clear")
	if _npc != null and _npc.has_method("stop_revive"):
		_npc.call("stop_revive")
	if _fade != null:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 1.0)
		await get_tree().create_timer(1.1).timeout
	get_tree().change_scene_to_file(WHALE_BRIEFING)


## 衍月复活(倒地 2 秒后)时才弹出对应台词。
func _on_boss_revived() -> void:
	_show_defeat_line()


# ---------------------------------------------------------------- 手枪 / 死亡

## 接管主角的死亡:进入最后一轮后改为原地满血复活(并弹出字幕),之前仍是原来的死亡菜单。
func _setup_death_handling() -> void:
	var hud := get_node_or_null("HUD")
	if hud != null:
		var cb := Callable(hud, "_on_player_died")
		if _player.is_connected("died", cb):
			_player.disconnect("died", cb)
	if not _player.is_connected("died", _on_player_died):
		_player.connect("died", _on_player_died)


## 死在 Boss 房间:记住打到第几阶段,黑屏后退回第一房间的传送门前。
func _on_player_died() -> void:
	if _returning_home:
		return
	_returning_home = true
	var progress := get_node_or_null("/root/BossProgress")
	if progress != null:
		progress.call("remember_phase", clampi(_defeats + 1, 1, FINAL_DEFEAT))
	if _fade != null:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.9)
		await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file(FIRST_ROOM)


## 背景切换演出:模糊 → 画面震动 → 全黑 → 换图 → 淡出黑场,共 2 秒。
func _start_background_transition(index: int) -> void:
	if _bg == null or _transitioning:
		return
	_transitioning = true
	var path: String = BG_PATHS[index % BG_PATHS.size()]
	var next_tex := _load_texture(path)
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


## 直接把背景换成第 index 张,不播切换演出(从存档阶段继续时用)。
func _apply_background_now(index: int) -> void:
	if _bg == null:
		return
	var path: String = BG_PATHS[clampi(index, 0, BG_PATHS.size() - 1)]
	var tex := _load_texture(path)
	if tex != null:
		_bg.texture = tex


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
	_bg.texture = _load_texture(BG_PATHS[0])
	get_viewport().size_changed.connect(_fit_background)
	# 背景图铺满后,Sky 色块就不再需要了(它会把图挡住)
	if _sky != null and _bg.texture != null:
		_sky.visible = false


## 优先走导入资源;导入缓存缺失时直接读原始图片(PNG/WebP 都行),保证背景不会丢。
func _load_texture(path: String) -> Texture2D:
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


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
