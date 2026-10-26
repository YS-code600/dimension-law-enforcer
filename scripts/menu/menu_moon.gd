extends Node2D
## 霓虹月亮:洋红光晕 + 脉动光环。


func _draw() -> void:
	var vp := get_viewport_rect()
	var c := Vector2(vp.size.x * 0.78, vp.size.y * 0.10)
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 26.0 + 3.0 * sin(t * 7.85)
	# 光晕(多层半透明)
	for i in range(8, 0, -1):
		draw_circle(c, 16.0 + float(i) * 7.0, Color(1.0, 0.2, 0.4, 0.028 * float(9 - i)))
	# 月面
	draw_circle(c, 15.0, Color(1.0, 0.24, 0.42, 0.95))
	# 环形
	draw_arc(c, pulse, 0.0, TAU, 64, Color(1.0, 0.25, 0.45, 0.35), 2.0, true)
	draw_arc(c, pulse + 3.0, 0.0, TAU, 64, Color(1.0, 0.25, 0.45, 0.12), 1.0, true)
