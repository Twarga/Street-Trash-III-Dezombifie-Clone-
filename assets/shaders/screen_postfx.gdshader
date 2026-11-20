shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float ca_strength : hint_range(0.0, 0.025) = 0.0012;
uniform float hurt_vignette : hint_range(0.0, 1.0) = 0.0;
uniform float chaos_glow : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.08) = 0.024;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - 0.5;
	float dist = length(centered);
	// Radial Chromatic Aberration (subtle always, spikes on explosions/hits!)
	vec2 dir = centered * (ca_strength * (0.6 + dist * 2.2));
	float r = texture(screen_tex, uv + dir).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - dir).b;
	vec3 col = vec3(r, g, b);

	// Cinematic dark corner vignette
	float vig = smoothstep(0.45, 1.05, dist * 1.25);
	col *= mix(1.0, 0.62, vig);

	// Crimson blood-edge damage pulse
	if (hurt_vignette > 0.001) {
		float h_edge = smoothstep(0.32, 0.88, dist * 1.35);
		col = mix(col, vec3(0.95, 0.05, 0.08), h_edge * hurt_vignette * 0.68);
	}
	// Blazing orange/gold Chaos overdrive border shimmer!
	if (chaos_glow > 0.001) {
		float c_edge = smoothstep(0.45, 0.95, dist * 1.35) * (0.75 + 0.25 * sin(TIME * 8.0));
		col += vec3(1.0, 0.42, 0.05) * c_edge * chaos_glow * 0.32;
	}
	// Subtle grindhouse film grain
	float n = (rand(uv * 512.0 + fract(TIME * 17.0)) - 0.5) * grain_strength;
	col += vec3(n);
	COLOR = vec4(col, 1.0);
}
