extends Node2D
## 程序化城市剪影：一栋栋楼 + 点亮的窗格。
## 横向比视口更宽，滚动交给父级 ParallaxLayer 处理。

@export var layer_seed: int = 1
@export var building_color: Color = Color(0.0705882, 0.0823529, 0.152941, 1.0)
@export var window_color: Color = Color(1.0, 0.8, 0.45, 0.85)
@export var window_chance: float = 0.35
@export var min_height: float = 70.0
@export var max_height: float = 210.0
@export var min_width: float = 26.0
@export var max_width: float = 62.0
@export var baseline_offset: float = 0.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = layer_seed

	var ground := view.y + baseline_offset
	var x := -view.x * 0.2
	var limit := view.x * 1.2

	while x < limit:
		var width := rng.randf_range(min_width, max_width)
		var height := rng.randf_range(min_height, max_height)
		var top := ground - height
		draw_rect(Rect2(x, top, width, height), building_color)

		var cols := int(max(1.0, floor((width - 12.0) / 12.0)))
		var rows := int(max(1.0, floor((height - 18.0) / 15.0)))
		var cell_w := (width - 12.0) / cols
		var cell_h := (height - 18.0) / rows
		for c in cols:
			for r in rows:
				if rng.randf() < window_chance:
					var wx := x + 8.0 + c * cell_w + cell_w * 0.22
					var wy := top + 10.0 + r * cell_h + cell_h * 0.25
					draw_rect(Rect2(wx, wy, cell_w * 0.45, cell_h * 0.4), window_color)

		x += width + rng.randf_range(3.0, 14.0)
