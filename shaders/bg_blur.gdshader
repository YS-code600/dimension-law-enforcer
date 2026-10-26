shader_type canvas_item;
// 背景过渡用的模糊:沿 UV 做多方向采样,blur_amount 0→1 控制强度。

uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (blur_amount > 0.01) {
		vec4 sum = col;
		float total = 1.0;
		for (int i = 1; i <= 5; i++) {
			float r = float(i) * 0.007 * blur_amount;
			sum += texture(TEXTURE, UV + vec2(r, 0.0));
			sum += texture(TEXTURE, UV - vec2(r, 0.0));
			sum += texture(TEXTURE, UV + vec2(0.0, r * 0.6));
			sum += texture(TEXTURE, UV - vec2(0.0, r * 0.6));
			sum += texture(TEXTURE, UV + vec2(r, r) * 0.7);
			sum += texture(TEXTURE, UV - vec2(r, r) * 0.7);
			sum += texture(TEXTURE, UV + vec2(r, -r) * 0.7);
			sum += texture(TEXTURE, UV - vec2(r, -r) * 0.7);
			total += 8.0;
		}
		col = sum / total;
	}
	COLOR = col;
}
