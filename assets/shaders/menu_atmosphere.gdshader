shader_type canvas_item;

uniform float rain_intensity = 0.55;
uniform float ember_intensity = 0.65;
uniform vec4 tint_color : source_color = vec4(0.95, 0.14, 0.10, 0.22);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Heavy cinematic dark edge vignette
	vec2 centered = uv - 0.5;
	float vig = smoothstep(0.28, 0.92, length(centered * vec2(1.15, 1.35)));
	vec4 col = vec4(0.01, 0.012, 0.018, vig * 0.72);

	// Subtle left-side reading gradient so borderless typography pops cleanly
	float left_fade = smoothstep(0.56, 0.0, uv.x);
	col.a = max(col.a, left_fade * 0.76);

	// Animated diagonal neon rain streaks
	vec2 ruv = vec2(uv.x * 78.0 + uv.y * 14.0, uv.y * 9.0 - t * 4.8);
	vec2 rcell = floor(ruv);
	vec2 rf = fract(ruv);
	float rnd = hash(rcell);
	float streak = step(0.84, rnd) * smoothstep(0.18, 0.0, abs(rf.x - 0.5)) * smoothstep(0.0, 0.35, rf.y) * smoothstep(1.0, 0.6, rf.y);
	col.rgb += vec3(0.45, 0.72, 0.85) * streak * rain_intensity * 0.28;
	col.a = clamp(col.a + streak * rain_intensity * 0.14, 0.0, 0.94);

	// Rising fiery embers drifting upward
	vec2 euv = vec2(uv.x * 26.0 + sin(t * 0.9 + uv.y * 6.0) * 0.45, uv.y * 18.0 + t * 1.15);
	vec2 ecell = floor(euv);
	vec2 ef = fract(euv) - 0.5;
	float ernd = hash(ecell + 19.3);
	float ember = step(0.91, ernd) * smoothstep(0.14, 0.01, length(ef)) * (0.55 + 0.45 * sin(t * 7.0 + ernd * 30.0));
	col.rgb += vec3(1.0, 0.42, 0.08) * ember * ember_intensity * 1.3;
	col.a = clamp(col.a + ember * ember_intensity * 0.55, 0.0, 0.96);

	// Subtle film grain & bottom crimson mist
	float grain = (hash(uv * 512.0 + fract(t)) - 0.5) * 0.04;
	col.rgb += grain;
	col.rgb += tint_color.rgb * smoothstep(0.55, 1.0, uv.y) * tint_color.a;

	COLOR = col;
}
