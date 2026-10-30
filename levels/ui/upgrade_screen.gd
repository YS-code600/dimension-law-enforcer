extends Control
## 变强界面:整屏覆盖的强化面板。左上 token 数,右上关闭叉号,中间是四条强化线。
## 只负责显示与发信号;开关、暂停与按键由 npc_menu.gd 控制。

signal close_requested

const UI_FONT := preload("res://levels/ui/ui_font.gd")

## 六条强化线的显示名
const LABELS := {
	"attack": "加强攻击伤害+50%",
	"health": "加强血量+50%",
	"invuln": "加强无敌时间+30%",
	"parry": "加强弹反范围+30%",
	"skill": "加强技能+30%",
	"cd": "技能冷却-20%",
}

@onready var _token_hud: Panel = $TokenHud
@onready var _close_button: Button = $CloseButton
@onready var _state_label: Label = $Body/Lines/BodyTag
@onready var _buttons := {
	"attack": $Body/Lines/AttackButton,
	"health": $Body/Lines/HealthButton,
	"invuln": $Body/Lines/InvulnButton,
	"parry": $Body/Lines/ParryButton,
	"skill": $Body/Lines/SkillButton,
	"cd": $Body/Lines/CooldownButton,
}


func _ready() -> void:
	visible = false
	UI_FONT.apply(self, 16)
	_close_button.pressed.connect(_on_close_pressed)
	for key in _buttons.keys():
		(_buttons[key] as Button).pressed.connect(_on_buy.bind(key))
	_token_hud.call("build", null, null)
	var tokens := get_node_or_null("/root/Tokens")
	if tokens != null and tokens.has_signal("changed") \
			and not tokens.is_connected("changed", _on_tokens_changed):
		tokens.connect("changed", _on_tokens_changed)
	_refresh_state()


## 打开界面(刷新 token 数与各条强化线的状态)。
func open() -> void:
	_token_hud.call("build", null, null)
	_refresh_state()
	visible = true


func close() -> void:
	visible = false


func _on_close_pressed() -> void:
	close_requested.emit()


## 买一条强化线的一级(扣 token 由 PlayerStats 负责)。
func _on_buy(key: String) -> void:
	var stats := get_node_or_null("/root/PlayerStats")
	if stats == null:
		return
	if bool(stats.call("buy", key)):
		_refresh_state()
		_flash(_buttons[key] as Button)


func _on_tokens_changed(_total: int) -> void:
	if is_inside_tree():
		_refresh_state()


func _refresh_state() -> void:
	var stats := get_node_or_null("/root/PlayerStats")
	var tokens := get_node_or_null("/root/Tokens")
	if stats == null or _state_label == null:
		return
	var held := int(tokens.get("total")) if tokens != null else 0

	for key in _buttons.keys():
		var btn: Button = _buttons[key]
		var level := int(stats.call("level_of", key))
		var max_level := int(stats.call("max_level_of", key))
		var cost := int(stats.call("next_cost", key))
		var label := String(LABELS.get(key, key))
		if cost < 0:
			btn.text = "%s（已满级 Lv.%d）" % [label, level]
			btn.disabled = true
		else:
			btn.text = "%s（Lv.%d/%d · %d token）" % [label, level, max_level, cost]
			btn.disabled = held < cost

	_state_label.text = "// 攻击 ×%.2f · 血量 ×%.2f · 无敌 ×%.2f · 弹反 ×%.2f · 技能 ×%.2f · 冷却 ×%.2f · 持有 %d token" % [
		stats.call("multiplier", "attack"),
		stats.call("multiplier", "health"),
		stats.call("multiplier", "invuln"),
		stats.call("multiplier", "parry"),
		stats.call("multiplier", "skill"),
		stats.call("multiplier", "cd"),
		held,
	]


func _flash(btn: Button) -> void:
	if btn == null:
		return
	var tw := create_tween()
	tw.tween_property(btn, "modulate", Color(1.7, 1.7, 1.7), 0.08)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.22)
