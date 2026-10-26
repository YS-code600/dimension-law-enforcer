shader_type canvas_item;

uniform float line_spacing : hint_range(1.0, 16.0) = 4.0;
uniform float line_density : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float flicker_strength : hint_range(0.0, 0.2) = 0.02;
uniform float flicker_speed : hint_range(1.0, 40.0) = 18.0;

void fragment() {
	vec2 uv = UV;
	float pixel_y = uv.y / max(SCREEN_PIXEL_SIZE.y, 0.000001);
	float scan_wave = 0.5 + 0.5 * sin(pixel_y * 3.14159265359 / line_spacing);
	float alpha = scan_wave * line_density;
	float dist = distance(uv, vec2(0.5));
	alpha += smoothstep(0.32, 0.88, dist) * vignette_strength;
	float flick = 1.0 - flicker_strength * (0.5 + 0.5 * sin(TIME * flicker_speed));
	alpha = clamp(alpha, 0.0, 1.0) * flick;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
