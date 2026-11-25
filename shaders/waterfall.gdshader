shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Dedicated waterfall / lavafall / icicle-curtain shader ported 1:1 from 31-terrain.js:10-40 (MAT.fall)
// u_fp: x=mode (0=water/bog, 1=frost icicles, 2=lavafall), y=speed, z=alpha_mul, w=unused
uniform vec4 u_fp = vec4(0.0, 1.0, 1.0, 0.0);
uniform vec3 u_fa = vec3(0.022, 0.034, 0.054);
uniform vec3 u_fb = vec3(0.20, 0.27, 0.38);

float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x),
		mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float t = TIME * u_fp.y;
	float edge = smoothstep(0.0, 0.14, x) * smoothstep(1.0, 0.86, x);

	if (u_fp.x > 0.5 && u_fp.x < 1.5) {
		// Frozen icicle curtain (Frostfall)
		float c1 = n2(vec2(x * 7.0, 2.0));
		float c2 = n2(vec2(x * 19.0 + 5.0, 7.0));
		float c3 = n2(vec2(x * 4.0 + 1.0, y * 2.2));
		float len = 0.34 + 0.46 * c1 + 0.16 * c2;
		float tip = smoothstep(len, len - 0.2, y);
		float rib = smoothstep(0.2, 0.8, c2 * 0.55 + n2(vec2(x * 34.0, y * 1.3)) * 0.45);
		float ed = smoothstep(0.0, 0.07, x) * smoothstep(1.0, 0.93, x);
		ALBEDO = mix(u_fa, u_fb, rib * (0.45 + 0.55 * c3));
		ALPHA = clamp(ed * tip * u_fp.z, 0.0, 1.0);
	} else {
		float s1 = n2(vec2(x * 6.0, y * 5.0 - t * 2.4));
		float s2 = n2(vec2(x * 13.0 + 3.1, y * 11.0 - t * 4.1));
		float s3 = n2(vec2(x * 3.0 - 1.7, y * 2.2 - t * 1.3));
		float strand = smoothstep(0.34, 0.72, s1 * 0.6 + s2 * 0.4);
		float sheet = 1.0 - smoothstep(0.03, 0.30, y);

		if (u_fp.x > 1.5) {
			// Molten lava fall (Emberscar): hot glowing body + flowing dark cooling streaks + soft bottom fade
			float body = mix(0.72 + 0.28 * s3, 1.0, sheet);
			float crust = strand * smoothstep(0.05, 0.50, y);
			ALBEDO = mix(u_fa * (0.7 + 0.5 * s3), u_fb, crust);
			ALPHA = clamp(edge * body * (1.0 - smoothstep(0.55, 1.0, y)) * u_fp.z, 0.0, 1.0);
		} else {
			// Frothy waterfall / bog fall
			float fade = 1.0 - smoothstep(0.40, 1.0, y);
			float body = mix(strand * (0.55 + 0.45 * s3), 1.0, sheet);
			float foam = strand * smoothstep(0.02, 0.22, y);
			ALBEDO = mix(u_fa, u_fb, foam * 0.85 + 0.06 * s3);
			ALPHA = clamp(edge * body * fade * (0.62 + 0.30 * foam) * u_fp.z, 0.0, 1.0);
		}
	}
}
