shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 beam_color : source_color = vec4(0.82, 0.93, 1.0, 0.09);
uniform float falloff_power = 1.7;
uniform float dust_speed = 0.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Cone UV.y: 0 at apex, 1 at far end
	float dist_fade = pow(clamp(1.0 - UV.y, 0.0, 1.0), falloff_power) * smoothstep(0.0, 0.08, UV.y);
	float fresnel = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.35);
	float dust = 0.78 + 0.22 * noise(vec2(UV.x * 8.0, UV.y * 6.0 - TIME * dust_speed));
	ALBEDO = beam_color.rgb * 1.45;
	ALPHA = dist_fade * fresnel * dust * beam_color.a;
}
