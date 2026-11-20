shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float ghost_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float skew_amt = 0.07;
uniform vec4 bg_color : source_color = vec4(0.07, 0.08, 0.11, 0.88);
uniform vec4 fill_color : source_color = vec4(0.95, 0.16, 0.20, 1.0);
uniform vec4 fill_hi : source_color = vec4(1.0, 0.52, 0.35, 1.0);
uniform vec4 ghost_color : source_color = vec4(1.0, 0.95, 0.85, 0.92);
uniform vec4 border_color : source_color = vec4(0.95, 0.25, 0.22, 0.75);

void fragment() {
	// Slanted parallelogram coordinate
	float sx = UV.x + (UV.y - 0.5) * skew_amt;
	if (sx < 0.0 || sx > 1.0) {
		discard;
	}
	float edge_x = min(sx, 1.0 - sx);
	float edge_y = min(UV.y, 1.0 - UV.y);
	bool is_border = (edge_x < 0.012) || (edge_y < 0.11);
	if (is_border) {
		COLOR = border_color;
	} else {
		vec4 c = bg_color;
		// Subtle diagonal tactical stripes in background
		float stripe = step(0.5, fract((sx * 18.0 - UV.y * 2.5)));
		c.rgb += stripe * 0.025;
		if (sx <= ghost_ratio) {
			c = ghost_color;
		}
		if (sx <= fill_ratio) {
			float grad = smoothstep(1.0, 0.0, UV.y);
			vec3 fcol = mix(fill_color.rgb, fill_hi.rgb, grad * 0.55);
			// Animated shimmer & bright leading edge!
			float lead = smoothstep(fill_ratio - 0.045, fill_ratio, sx);
			float moving = step(0.65, fract(sx * 14.0 - UV.y * 1.6 - TIME * 0.8));
			fcol += moving * 0.06 + lead * 0.45;
			c = vec4(fcol, 1.0);
		}
		COLOR = c;
	}
}
