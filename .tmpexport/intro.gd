extends Control
## 开场简报:黑底展示档案文字,按 Enter 进入游戏。

const GAME_SCENE := "res://levels/game.tscn"
const MAIN_MENU := "res://main.tscn"
const BODY := "我国新型投影示人形AI––衍月
用于反间谍工作，守护国家安全

但由于信息泄露，外国敌对势力知道此情报后，盗取了衍月原型，准备运往境外。并派重兵把守。甚至设置了大型激光围笼。

这次，作为我国最优秀的反间谍人员，你将前往敌人老巢。带着衍月，突破重围。到达指定地点后由我方人员接应撤离，粉碎敌对势力的阴谋。"

@onready var text: RichTextLabel = $Text
@onready var prompt: Label = $Prompt

var _time := 0.0
var _leaving := false
var _input_ready_at := 0


func _ready() -> void:
	_input_ready_at = Time.get_ticks_msec() + 250
	_fit_text()
	text.modulate.a = 0.0
	prompt.modulate.a = 0.35
	var tw := create_tween()
	tw.tween_property(text, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func _fit_text() -> void:
	var compact := get_viewport_rect().size.y < 620.0
	var body_size := 18 if compact else 24
	var title_size := 40 if compact else 52
	text.add_theme_constant_override("line_separation", 6 if compact else 10)
	text.text = "[center][font_size=%d][color=#bfefff]你好[/color][/font_size][/center]\n[center][font_size=%d][color=#dce2ea]%s[/color][/font_size][/center]" % [title_size, body_size, BODY]


func _process(delta: float) -> void:
	_time += delta
	prompt.modulate.a = 0.5 + 0.25 * sin(_time * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or Time.get_ticks_msec() < _input_ready_at:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_ENTER or key == KEY_KP_ENTER:
			_leaving = true
			get_viewport().set_input_as_handled()
			_go(GAME_SCENE)
			return
		if key == KEY_ESCAPE:
			_leaving = true
			get_viewport().set_input_as_handled()
			_go(MAIN_MENU)


func _go(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		_leaving = false
