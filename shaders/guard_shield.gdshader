shader_type canvas_item;
// 幽兰色圆形护盾:外圈高亮 + 内部淡填充,带脉动。

uniform vec4 shield_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv) * 2.0;
	float ring = smoothstep(0.78, 0.88, d) * (1.0 - smoothstep(0.93, 0.995, d));
	float glow = (1.0 - smoothstep(0.0, 0.98, d)) * 0.14;
	float alpha = (ring * (0.55 + 0.35 * pulse) + glow) * fade;
	COLOR = vec4(shield_color.rgb, alpha);
}
