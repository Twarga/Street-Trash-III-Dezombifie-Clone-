shader_type canvas_item;

uniform vec4 accent_color : source_color = vec4(1.0, 0.35, 0.2, 1.0);
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.35;
uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec2 mouse_uv = vec2(0.5, 0.5);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Subtle comic vignette on art edges
	float vig = smoothstep(0.95, 0.35, length((UV - 0.5) * vec2(1.2, 1.2)));
	vec3 col = tex.rgb * mix(0.78, 1.08, vig);
	// Diagonal metallic/holographic sweep reacting to mouse & time
	float sweep_pos = (mouse_uv.x - 0.5) * 1.6 + sin(TIME * 1.8) * 0.25;
	float diag = dot(UV - 0.5, vec2(0.75, 0.66)) - sweep_pos;
	float band = exp(-pow(diag * 7.5, 2.0));
	// Prismatic tint on sheen
	vec3 prism = 0.5 + 0.5 * cos(6.2831 * (diag * 1.4 + vec3(0.0, 0.33, 0.67)));
	vec3 sheen = mix(accent_color.rgb, prism, 0.45);
	col += sheen * band * (sheen_strength * 0.45 + hover_amount * 0.55);
	// Subtle halftone scanlines
	float scan = 0.96 + 0.04 * sin(UV.y * 220.0);
	COLOR = vec4(col * scan, tex.a);
}
