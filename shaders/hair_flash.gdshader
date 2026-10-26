shader_type canvas_item;
// 只对紫色像素(头发与衣服)换色,皮肤/白色不受影响。用于衍月头发闪烁的演出。

uniform vec4 flash_color : source_color = vec4(1.0, 0.18, 0.14, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// 紫色判定: 蓝 > 红 > 绿;皮肤(r>g>b)与白色(r≈g≈b)会被排除
	float mask = step(0.02, tex.b - tex.r) * step(0.0, tex.r - tex.g);
	// 用原图的蓝通道当明暗,保留原有的阴影层次
	float shade = clamp(tex.b * 2.2, 0.35, 1.4);
	vec3 tint = flash_color.rgb * shade;
	COLOR = vec4(mix(tex.rgb, tint, mask * amount), tex.a);
}
