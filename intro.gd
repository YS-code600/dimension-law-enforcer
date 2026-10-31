extends Control
## 黑幕 gal 风简报：开场与最终战复用。
## 默认播放开场六句；final_briefing.tscn 覆盖为单句并换用笑脸立绘。

const VOICE_DIR := "res://audio/voice/"
const MUSIC_TARGET_DB := -14.0
const MUSIC_DUCK_DB := -26.0

const LINES := [
	"喂喂——能听到吗？我是[color=#8fe9ff]大肥鱼[/color]，你的专属 Debug 导航员！",
	"别装没事啦，你开发的这个游戏，刚刚……全面 [color=#ff6b8a]BUG[/color] 暴走啦！",
	"角色穿墙、Boss 血条倒着涨、存档说没就没，连主菜单都在偷偷报错。",
	"作为作者，你得亲自进游戏里把 BUG 一个个修好；我呢，就负责在旁边给你报点、递工具、顺便吐槽。",
	"前面就是进入游戏世界的入口。穿过它，一关一关打过去，把跑偏的代码掰回正轨！",
	"准备完毕——3、2、1！[color=#ff6b8a]BUG 修复大作战[/color]，开始！",
]

## 导出兜底:Godot 把继承场景导出成 .scn 时，实例上覆盖的 PackedStringArray
## (custom_lines / voice_paths 等) 会在导出包里变空，表现就是 fire_room 前 /
## 结尾的鲸鱼娘简报退回成 world_main 那六句大肥鱼台词。这里按 header_tag 补回来。
## 注意:改简报台词时，这里和 whale_briefing.tscn / final_briefing.tscn 要一起改
## (导出后的游戏只认这里的文本)。
const BRIEFINGS := {
	"// BUG SOURCE": {
		"lines": [
			"BUG源就在附近了，嘿嘿。",
			"取出BUG源，作者你的游戏就会恢复正常啦。",
		],
		"voices": [
			"res://audio/voice/whale_01.wav",
			"res://audio/voice/whale_02.wav",
		],
		"portrait": "res://picture/whale_girl.png",
		"speaker": "鲸鱼娘",
		"next": "res://levels/void_room.tscn",
		"loading": "> 正在进入黑房间…",
	},
	"// FINAL BUG": {
		"lines": ["这就是最后的[color=#ff6b8a]bug[/color]了，上吧！"],
		"voices": ["res://audio/voice/final_01.wav"],
		"portrait": "res://picture/dafeiyu_grin.png",
		"next": "res://levels/fire_room.tscn",
		"loading": "> 正在进入火雨房间…",
	},
}

## 自定义简报：留空时使用开场六句；最终战简报只覆盖一句。
@export var custom_lines: PackedStringArray = []
@export var next_scene := "res://levels/game.tscn"
@export var voice_enabled := true
## 留空时按开场命名读取 intro_01..06.wav；自定义简报可逐句指定音频。
@export var voice_paths: PackedStringArray = []
@export var portrait_texture: Texture2D
@export var portrait_source_path := "res://picture/dafeiyu.png"
## 说话人名字(留空 = 用场景里原本的「大肥鱼」)
@export var speaker_name := ""
## 每句的说话人(留空的那句沿用 speaker_name)
@export var speaker_names: PackedStringArray = []
## 每句的立绘(留空的那句沿用上一张)
@export var portrait_paths: PackedStringArray = []
## true = 当成本场景里的浮层用:对白结束不切场景,而是发 finished 并淡出自己
@export var stay_in_scene := false

signal finished
@export var loading_text := "> 正在进入游戏世界…"
@export var header_tag := "// PRE-MISSION BRIEFING"

@onready var portrait: TextureRect = %Portrait
@onready var portrait_glow: TextureRect = %PortraitGlow
@onready var dialog: PanelContainer = %Dialog
@onready var body: RichTextLabel = %Body
@onready var progress: Label = %Progress
@onready var continue_arrow: Label = %ContinueArrow
@onready var hint: Label = %Hint
@onready var fade: ColorRect = %Fade
@onready var sparkle_a: Label = %SparkleA
@onready var sparkle_b: Label = %SparkleB
@onready var voice: AudioStreamPlayer = %Voice

var _line_index := -1
var _portrait_path := ""
var _lines: Array = []
var _time := 0.0
var _leaving := false
var _portrait_base := Vector2.ZERO
var _input_ready_at := 0
var _entrance_tween: Tween
var _voice_streams: Array = []
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_apply_briefing_fallback()
	_lines = Array(custom_lines) if not custom_lines.is_empty() else Array(LINES)
	var brand_sub := get_node_or_null("Brand/BrandSub") as Label
	if brand_sub != null:
		brand_sub.text = header_tag
	var speaker := get_node_or_null("Dialog/Margin/Content/SpeakerRow/SpeakerName") as Label
	if speaker != null and not speaker_name.is_empty():
		speaker.text = speaker_name
	_input_ready_at = Time.get_ticks_msec() + 1100
	_load_voices()
	_duck_music()
	if portrait_texture != null:
		portrait.texture = portrait_texture
	else:
		var tex: Texture2D = null
		if ResourceLoader.exists(portrait_source_path):
			tex = load(portrait_source_path) as Texture2D
		if tex != null:
			portrait.texture = tex
		else:
			# 还没导入的立绘(或 jpg)直接从源文件建纹理,保证不空镜。
			var img := Image.new()
			if img.load(portrait_source_path) == OK:
				portrait.texture = ImageTexture.create_from_image(img)
	_portrait_base = portrait.position
	portrait.pivot_offset = portrait.size * 0.5
	portrait.scale = Vector2(0.94, 0.94)
	portrait.modulate.a = 0.0
	portrait_glow.modulate.a = 0.0
	dialog.modulate.a = 0.0
	_play_entrance()
	_start_intro_line()


## 导出包里继承场景的数组覆盖会丢，用 header_tag 找回这份简报该有的台词。
func _apply_briefing_fallback() -> void:
	if not custom_lines.is_empty():
		return
	var data: Dictionary = BRIEFINGS.get(header_tag, {})
	if data.is_empty():
		return
	custom_lines = PackedStringArray(data.get("lines", []))
	if voice_paths.is_empty():
		voice_paths = PackedStringArray(data.get("voices", []))
	if portrait_source_path.is_empty():
		portrait_source_path = String(data.get("portrait", portrait_source_path))
	if speaker_name.is_empty():
		speaker_name = String(data.get("speaker", speaker_name))
	if next_scene.is_empty():
		next_scene = String(data.get("next", next_scene))
	if loading_text.is_empty():
		loading_text = String(data.get("loading", loading_text))


## 等黑幕淡入后再开口，避免第一句被开场黑场盖掉。
func _start_intro_line() -> void:
	await get_tree().create_timer(0.55).timeout
	if _leaving:
		return
	_show_line(0)


func _load_voices() -> void:
	if not voice_enabled:
		return
	for i in _lines.size():
		_voice_streams.append(_load_voice(i))


func _load_voice(index: int) -> AudioStream:
	var path := ""
	if index < voice_paths.size():
		path = voice_paths[index]
		# 显式留空 = 这一句没有语音,不再回退到 intro_XX.wav
		if path.is_empty():
			return null
	else:
		path = VOICE_DIR + "intro_%02d.wav" % (index + 1)
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		if path.get_extension().to_lower() == "mp3":
			var bytes := FileAccess.get_file_as_bytes(path)
			if not bytes.is_empty():
				var mp3 := AudioStreamMP3.new()
				mp3.data = bytes
				stream = mp3
		else:
			stream = AudioStreamWAV.load_from_file(path)
	return stream


func _duck_music() -> void:
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	_music_player = music.get_node_or_null("Underwater") as AudioStreamPlayer
	if _music_player == null:
		return
	var tw := music.create_tween()
	tw.tween_property(_music_player, "volume_db", MUSIC_DUCK_DB, 0.7) \
		.set_trans(Tween.TRANS_SINE)


func _restore_music() -> void:
	if _music_player == null:
		return
	var music := get_node_or_null("/root/Music")
	if music == null:
		return
	var tw := music.create_tween()
	tw.tween_property(_music_player, "volume_db", MUSIC_TARGET_DB, 0.8) \
		.set_trans(Tween.TRANS_SINE)


func _play_entrance() -> void:
	fade.color.a = 1.0
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(fade, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	_entrance_tween.tween_property(portrait, "modulate:a", 1.0, 0.8).set_delay(0.12)
	_entrance_tween.tween_property(portrait, "scale", Vector2.ONE, 0.55) \
		.set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(portrait_glow, "modulate:a", 0.5, 0.9).set_delay(0.12)
	_entrance_tween.tween_property(dialog, "modulate:a", 1.0, 0.5).set_delay(0.18)


func _process(delta: float) -> void:
	_time += delta
	# 立绘轻微漂浮；说话时再加一点上下点头。
	var bob := sin(_time * 1.6) * 5.0
	var talk := sin(_time * 16.0) * 2.5 if voice.playing else 0.0
	portrait.position = _portrait_base + Vector2(0.0, bob + talk)
	sparkle_a.modulate.a = 0.2 + 0.5 * (0.5 + 0.5 * sin(_time * 2.1))
	sparkle_b.modulate.a = 0.2 + 0.5 * (0.5 + 0.5 * sin(_time * 2.1 + 2.4))
	if continue_arrow.visible:
		continue_arrow.modulate.a = 0.45 + 0.55 * absf(sin(_time * 2.8))


func _show_line(index: int) -> void:
	_line_index = index
	body.text = _lines[index]
	body.visible_characters = -1
	progress.text = "%02d / %02d" % [index + 1, _lines.size()]
	continue_arrow.visible = true
	var label := get_node_or_null("Dialog/Margin/Content/SpeakerRow/SpeakerName") as Label
	if label != null:
		if index < speaker_names.size() and not speaker_names[index].is_empty():
			label.text = speaker_names[index]
		elif not speaker_name.is_empty():
			label.text = speaker_name
	_apply_line_portrait(index)
	_play_voice(index)


## 逐句换立绘(留空或和上一句相同就不动)。
func _apply_line_portrait(index: int) -> void:
	if index >= portrait_paths.size():
		return
	var path := portrait_paths[index]
	if path.is_empty() or path == _portrait_path:
		return
	_portrait_path = path
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		return
	portrait.texture = tex
	# 像素小图放大用最近邻,立绘大图保持平滑
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST \
		if tex.get_width() < 256 else CanvasItem.TEXTURE_FILTER_LINEAR


func _play_voice(index: int) -> void:
	voice.stop()
	var stream: AudioStream = _voice_streams[index] if index < _voice_streams.size() else null
	if stream == null:
		return
	voice.stream = stream
	voice.play()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or Time.get_ticks_msec() < _input_ready_at:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_finish()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_advance()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_advance()


func _advance() -> void:
	if _leaving:
		return
	if _line_index + 1 < _lines.size():
		_show_line(_line_index + 1)
		return
	_finish()


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	continue_arrow.visible = false
	voice.stop()
	_restore_music()
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	hint.text = loading_text
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if stay_in_scene:
		# 浮层用法:不切场景,发个信号让调用方继续流程,自己淡出销毁
		finished.emit()
		var out := create_tween()
		out.tween_property(self, "modulate:a", 0.0, 0.35)
		out.tween_callback(queue_free)
		return
	get_tree().change_scene_to_file(next_scene)
