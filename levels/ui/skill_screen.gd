extends Control
## 技能改换界面:和变强界面同一套 UI。
## 上面两个框对应按键 U(框一) / I(框二);
## 技能 100 token 解锁,解锁后点一下装进空框,已装上的再点一下卸下。
## 最多只能携带两个(框满了就装不进去)。

signal close_requested

const UI_FONT := preload("res://levels/ui/ui_font.gd")
const SKILL_COST := 100
const SLOT_HOTKEYS := ["U", "I"]
const SLOT_NAMES := ["框一", "框二"]

@onready var _token_hud: Panel = $TokenHud
@onready var _close_button: Button = $CloseButton
@onready var _state_label: Label = $Body/Lines/BodyTag
@onready var _slot_values: Array = [
	$Body/Lines/Slots/Slot1/Inner/Value,
	$Body/Lines/Slots/Slot2/Inner/Value,
]
@onready var _option_list: VBoxContainer = $Body/Lines/OptionList
@onready var _template: Button = $Body/Lines/OptionList/TemplateOption

## key -> Button
var _buttons := {}


func _ready() -> void:
	visible = false
	UI_FONT.apply(self, 16)
	_close_button.pressed.connect(_on_close_pressed)
	_token_hud.call("build", null, null)
	var tokens := get_node_or_null("/root/Tokens")
	if tokens != null and tokens.has_signal("changed") \
			and not tokens.is_connected("changed", _on_tokens_changed):
		tokens.connect("changed", _on_tokens_changed)
	var stats := get_node_or_null("/root/PlayerStats")
	if stats != null and stats.has_signal("changed") \
			and not stats.is_connected("changed", _on_stats_changed):
		stats.connect("changed", _on_stats_changed)
	_build_options()
	_refresh_state()


## 打开界面。
func open() -> void:
	_token_hud.call("build", null, null)
	_refresh_state()
	visible = true


func close() -> void:
	visible = false


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_tokens_changed(_total: int) -> void:
	if is_inside_tree():
		_refresh_state()


func _on_stats_changed() -> void:
	if is_inside_tree():
		_refresh_state()


## 按 PlayerStats.SKILLS 里的顺序生成选项按钮;以后加技能只改那张表。
func _build_options() -> void:
	var stats := get_node_or_null("/root/PlayerStats")
	if stats == null or _template == null:
		return
	if not _buttons.is_empty():
		return
	for key in stats.call("skill_keys"):
		var id := String(key)
		var btn: Button = _template.duplicate() as Button
		btn.name = "Skill_" + id
		btn.visible = true
		btn.pressed.connect(_on_press.bind(id))
		_option_list.add_child(btn)
		_buttons[id] = btn


## 点技能条目:没解锁先解锁,解锁了就装/卸。
func _on_press(key: String) -> void:
	var stats := get_node_or_null("/root/PlayerStats")
	if stats == null:
		return
	var btn: Button = _buttons.get(key)
	match String(stats.call("skill_state", key)):
		"locked":
			if bool(stats.call("unlock_skill", key)):
				_refresh_state()
				_flash(btn)
		_:
			if bool(stats.call("toggle_skill", key)):
				_refresh_state()
				_flash(btn)


func _refresh_state() -> void:
	var stats := get_node_or_null("/root/PlayerStats")
	var tokens := get_node_or_null("/root/Tokens")
	if stats == null or _state_label == null:
		return
	var held := int(tokens.get("total")) if tokens != null else 0

	# 两个框:显示装着的技能
	for i in _slot_values.size():
		var label: Label = _slot_values[i]
		var key := String(stats.call("slot_skill", i))
		if key == "":
			label.text = "—— 空 ——"
			label.add_theme_color_override("font_color", Color(0.42, 0.5, 0.66, 0.9))
		else:
			label.text = String(stats.call("skill_name", key))
			label.add_theme_color_override("font_color", Color(0.78, 1, 1, 1))

	var unlocked_count := 0
	var carried := 0
	var free_slot := int(stats.call("next_free_slot"))

	for key in _buttons.keys():
		var btn: Button = _buttons[key]
		var state := String(stats.call("skill_state", key))
		var label := String(stats.call("skill_label", key))
		var cd := _cd_text(float(stats.call("skill_cd", key)))
		if state != "locked":
			unlocked_count += 1
		match state:
			"locked":
				var cost := int(stats.call("skill_cost", key))
				btn.text = "%s（%s · 解锁 %d token）" % [label, cd, cost]
				btn.disabled = held < cost
			"equipped":
				carried += 1
				var slot := int(stats.call("slot_of", key))
				var slot_index := clampi(slot, 0, SLOT_NAMES.size() - 1)
				btn.text = "%s（%s · %s · %s）" % [
					label, cd, SLOT_NAMES[slot_index], SLOT_HOTKEYS[slot_index]]
				btn.disabled = false
			_:
				if free_slot < 0:
					btn.text = "%s（%s · 两个框都满了）" % [label, cd]
					btn.disabled = true
				else:
					btn.text = "%s（%s · 点击装进%s）" % [label, cd, SLOT_NAMES[free_slot]]
					btn.disabled = false

	_state_label.text = "// 已解锁 %d / %d · 已携带 %d / 2 · 持有 %d token" % [
		unlocked_count, _buttons.size(), carried, held]


## 冷却显示:0 秒 = 无冷却。
func _cd_text(seconds: float) -> String:
	if seconds <= 0.0:
		return "无冷却"
	return "CD %d 秒" % int(round(seconds))


func _flash(btn: Button) -> void:
	if btn == null:
		return
	var tw := create_tween()
	tw.tween_property(btn, "modulate", Color(1.7, 1.7, 1.7), 0.08)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.22)
