shader_type canvas_item;

uniform float scroll_speed = 0.32;
uniform float tile_x = 3.0;
uniform vec4 water_tint : source_color = vec4(0.62, 0.86, 1.0, 0.9);

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x * tile_x + TIME * scroll_speed);
	uv.y += sin(uv.x * 6.2831 + TIME * 2.0) * 0.015;
	vec4 tex = texture(TEXTURE, uv);
	float edge = 0.1 + 0.035 * sin(UV.x * 22.0 + TIME * 3.0);
	float mask = smoothstep(edge, edge + 0.07, UV.y);
	float foam = (1.0 - smoothstep(edge, edge + 0.06, UV.y)) * smoothstep(edge - 0.04, edge, UV.y);
	vec3 col = tex.rgb * water_tint.rgb;
	col = mix(col, vec3(0.82, 0.96, 1.0), foam * 0.7);
	COLOR = vec4(col, tex.a * water_tint.a * mask);
}
