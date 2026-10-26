extends CanvasLayer
## 游戏内 HUD:血量、重来/退出按钮与死亡界面。

const MAIN_MENU := "res://main.tscn"
const BAR_WIDTH := 238.0
const BAR_HEIGHT := 10.0
const SKILL_BAR_WIDTH := 238.0
const SKILL_BAR_HEIGHT := 10.0

@onready var restart_button: Button = %RestartButton
@onready var exit_button: Button = %ExitButton
@onready var health_panel: Panel = $HealthPanel
@onready var health_fill: ColorRect = $HealthPanel/BarFrame/BarFill
@onready var health_value: Label = $HealthPanel/HPValue
@onready var skill_panel: Panel = $SkillPanel
@onready var skill_fill: ColorRect = $SkillPanel/BarFrame/BarFill
@onready var skill_status: Label = $SkillPanel/SkillStatus
@onready var top_buttons: VBoxContainer = $Buttons
@onready var combat_hint: Label = $CombatHint
@onready var death_overlay: Control = $DeathOverlay
@onready var death_restart: Button = %DeathRestart
@onready var death_exit: Button = %DeathExit
@onready var win_banner: Control = $WinBanner


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_restart)
	exit_button.pressed.connect(_exit)
	death_restart.pressed.connect(_restart)
	death_exit.pressed.connect(_exit)
	death_overlay.visible = false
	_bind_player.call_deferred()


func _bind_player() -> void:
	var player := get_parent().get_node_or_null("Player") as Node
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("health_changed"):
		player.connect("health_changed", _on_health_changed)
		_on_health_changed(int(player.get("health")), int(player.get("max_health")))
	if player.has_signal("died"):
		player.connect("died", _on_player_died)
	if player.has_signal("skill_changed"):
		player.connect("skill_changed", _on_skill_changed)
		_on_skill_changed(false, 0.0, 9.0, 0.0, 30.0)
	if player.has_signal("won"):
		player.connect("won", _on_won)


func _on_health_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	health_fill.size = Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)
	health_value.text = "%d / %d" % [current, maximum]
	var low := clampf((0.5 - ratio) * 2.0, 0.0, 1.0)
	health_fill.color = Color(0.2, 0.95, 1.0).lerp(Color(1.0, 0.28, 0.32), low)


func _on_won() -> void:
	win_banner.visible = true
	combat_hint.visible = false


func _on_player_died() -> void:
	if death_overlay.visible:
		return
	health_panel.visible = false
	skill_panel.visible = false
	top_buttons.visible = false
	combat_hint.visible = false
	death_overlay.visible = true
	get_tree().paused = true
	death_restart.grab_focus()


func _on_skill_changed(active: bool, active_left: float, active_total: float, cooldown_left: float, cooldown_total: float) -> void:
	var ratio := 0.0
	if active:
		ratio = clampf(active_left / active_total, 0.0, 1.0) if active_total > 0.0 else 0.0
		skill_status.text = "无敌 %.1fs" % active_left
		skill_fill.color = Color(0.72, 0.55, 1.0)
	elif cooldown_left > 0.0:
		ratio = 1.0 - clampf(cooldown_left / cooldown_total, 0.0, 1.0)
		skill_status.text = "冷却 %.1fs" % cooldown_left
		skill_fill.color = Color(0.2, 0.85, 1.0)
	else:
		ratio = 1.0
		skill_status.text = "就绪"
		skill_fill.color = Color(0.55, 1.0, 1.0)
	skill_fill.size = Vector2(SKILL_BAR_WIDTH * ratio, SKILL_BAR_HEIGHT)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _exit() -> void:
	get_tree().paused = false
	var packed := load(MAIN_MENU) as PackedScene
	if packed != null:
		get_tree().change_scene_to_packed(packed)


func _unhandled_input(event: InputEvent) -> void:
	if not death_overlay.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_exit()
