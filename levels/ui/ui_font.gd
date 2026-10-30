extends RefCounted
## 中文 UI 字体:优先使用系统里的雅黑 / 思源黑体,避免中文变方块。

const FONT_NAMES := [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"Source Han Sans SC",
	"Noto Sans CJK SC",
	"PingFang SC",
	"WenQuanYi Micro Hei",
	"SimHei",
]


static func make(bold := false) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = 700 if bold else 400
	return font


## 给一个 Control 套上默认中文字体,子节点会自动继承。
static func apply(node: Control, size := 16) -> void:
	var theme := Theme.new()
	theme.default_font = make(false)
	theme.default_font_size = size
	node.theme = theme
