shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform float speed = 2.6;
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.55, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.42, 0.05, 1.0);
uniform vec4 tip_color : source_color = vec4(0.85, 0.08, 0.02, 1.0);
uniform float intensity = 3.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Organic upward flame sway
	float h = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 6.5 + VERTEX.y * 3.5) * 0.14 * h;
	VERTEX.z += cos(TIME * 5.2 + VERTEX.y * 3.0) * 0.14 * h;
}

void fragment() {
	float h = 1.0 - UV.y; // 0 at base, 1 at top
	float cx = abs(UV.x - 0.5) * 2.0; // 0 center, 1 edge
	vec2 n_uv = vec2(UV.x * 3.2, UV.y * 2.6 + TIME * speed);
	float n = fbm(n_uv);
	float n2 = fbm(n_uv * 2.1 - vec2(0.0, TIME * speed * 1.4));
	float taper = mix(0.92, 0.15, h);
	float shape = (1.0 - smoothstep(taper * 0.35, taper, cx + (n - 0.5) * 0.55));
	float flame = shape * (1.0 - smoothstep(0.35, 1.0, h + (n2 - 0.45) * 0.55));
	float alpha = smoothstep(0.12, 0.58, flame);
	vec3 col = mix(tip_color.rgb, mid_color.rgb, smoothstep(0.18, 0.55, flame));
	col = mix(col, core_color.rgb, smoothstep(0.58, 0.92, flame * (1.0 - h * 0.6)));
	ALBEDO = col * intensity;
	ALPHA = alpha * 0.95;
}
