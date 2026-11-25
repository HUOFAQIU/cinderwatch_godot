shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// u_wat: x=mode (0=water, 1=frost ice, 2=lava, 3=bog), y=flow_speed, z=bump_scale, w=mask_bump
// Ported from 10-gfx.js:175-227 (exact dark basalt crust + molten cracks for Emberscar lava)
uniform vec4 u_wat = vec4(0.0, 1.0, 1.0, 0.0);
uniform vec3 u_wat_a = vec3(0.012, 0.02, 0.03);
uniform vec3 u_wat_b = vec3(0.3, 0.4, 0.5);
uniform vec3 u_sky = vec3(0.012, 0.022, 0.045);

varying vec4 v_surf;
varying vec3 v_wpos;
varying vec3 v_wnrm;

float cw_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cw_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(cw_hash(i), cw_hash(i + vec2(1.0, 0.0)), f.x),
		mix(cw_hash(i + vec2(0.0, 1.0)), cw_hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float cw_ripple(vec2 p, float t, float flow) {
	float a = cw_noise(vec2(p.x * 2.6, p.y * 1.3 - t * flow * 1.0));
	float b = cw_noise(vec2(p.x * 5.2 + 3.7, p.y * 2.6 - t * (0.15 + flow * 1.4)));
	float c = cw_noise(vec2(p.x * 13.0 - t * 0.12, p.y * 9.0 - t * (0.2 + flow * 2.1)));
	return a + b * 0.9 + c * 0.15;
}

void vertex() {
	v_surf = CUSTOM0;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Seamless world-space UV (horizontal streams/ponds use xz; vertical waterfalls use horiz + y)
	bool is_fall = abs(v_wnrm.y) < 0.5;
	vec2 wuv = is_fall ? vec2(v_wpos.x + v_wpos.z, v_wpos.y) * 0.85 : UV;

	float w_mask = 0.0;
	float w_heat = 0.0;
	float w_flow = TIME * u_wat.y;
	float wn1 = cw_noise(wuv * vec2(1.6, 0.8) + 3.0);
	float wn2 = cw_noise(wuv * vec2(5.0, 2.6) + 11.0);
	vec3 col = u_wat_a;
	float rough = 0.14;
	vec3 emis = vec3(0.0);
	bool is_lava = (u_wat.x > 1.5 && u_wat.x < 2.5);

	if (u_wat.x > 0.5 && u_wat.x < 1.5) {
		// Frozen stream (Frostfall)
		float frost = smoothstep(0.4, 0.74, wn1 * 0.65 + wn2 * 0.35);
		float ck = smoothstep(0.035, 0.0, abs(cw_noise(wuv * vec2(2.3, 1.2) + 40.0) - 0.5))
			+ smoothstep(0.03, 0.0, abs(cw_noise(wuv * vec2(1.2, 2.7) + 71.0) - 0.48));
		w_mask = clamp(frost * 0.85 + ck * 0.7, 0.0, 1.0);
		col = mix(u_wat_a * (0.7 + 0.6 * wn2), u_wat_b, w_mask);
		rough = mix(0.09, 0.62, w_mask);
	} else if (is_lava) {
		// Lava river (Emberscar): dark cooled basalt crust (w_mask) + sharp glowing molten cracks (10-gfx.js:184-190, 225)
		float t = w_flow * (0.16 + 0.34 * min(v_surf.z, 1.0));
		float c1 = cw_noise(vec2(wuv.x * 2.1, wuv.y * 1.1 - t));
		float c2 = cw_noise(vec2(wuv.x * 4.6 + 7.0, wuv.y * 2.4 - t * 1.7));
		float c3 = cw_noise(vec2(wuv.x * 9.0 - 3.0, wuv.y * 5.0 - t * 2.3));
		float ra = 1.0 - abs(2.0 * c1 - 1.0);
		float rb = 1.0 - abs(2.0 * c2 - 1.0);
		float crack = max(pow(ra, 3.2), pow(rb, 4.4) * 0.8);
		float pool = smoothstep(0.56, 0.74, c1 * 0.55 + c3 * 0.45);
		w_heat = clamp(crack * 0.85 + pool, 0.0, 1.0);
		w_mask = 1.0 - smoothstep(0.38, 0.70, w_heat);
		col = mix(u_wat_a, u_wat_b * (0.6 + 0.8 * c3), w_mask);
		rough = mix(0.55, 0.96, w_mask);
		if (is_fall) {
			// Molten lava waterfall pours hot & bright with vertical streaks
			float streak = smoothstep(0.25, 0.85, c2 * 0.6 + c3 * 0.4);
			emis = mix(vec3(0.85, 0.14, 0.015), vec3(2.2, 0.75, 0.10), streak);
		} else {
			emis = mix(vec3(0.7, 0.07, 0.008), vec3(1.45, 0.42, 0.05), w_heat * w_heat) * (1.0 - w_mask) * 2.4
				+ vec3(0.10, 0.012, 0.0) * w_mask * (0.3 + wn2);
		}
	} else if (u_wat.x > 2.5) {
		// Bog water (Mirefen)
		w_mask = smoothstep(0.56, 0.68, wn1 * 0.55 + wn2 * 0.45 + 0.12 * (1.0 - min(v_surf.z, 1.0))) * step(0.01, v_surf.z);
		col = mix(u_wat_a, u_wat_b * (0.75 + 0.5 * wn2), w_mask);
		rough = mix(0.18, 0.9, w_mask);
	} else {
		// Flowing stream / oasis / puddle dark glossy mirror (10-gfx.js:175-228)
		float foam = smoothstep(0.76, 0.96, cw_ripple(wuv * 1.4, w_flow, max(v_surf.z, 0.35)) * 0.5) * step(0.1, v_surf.z);
		col = mix(u_wat_a, u_wat_b, foam * 0.14);
		rough = mix(0.14, 0.22, min(v_surf.z, 1.0));
	}

	// Screen-space ripple normal perturbation
	float h0 = cw_ripple(wuv, w_flow, max(v_surf.z, 0.4)) + w_mask * u_wat.w;
	vec3 d_pos_x = dFdx(VERTEX);
	vec3 d_pos_y = dFdy(VERTEX);
	vec3 r1 = cross(d_pos_y, NORMAL);
	vec3 r2 = cross(NORMAL, d_pos_x);
	float det = dot(d_pos_x, r1);
	if (abs(det) > 1e-6) {
		vec3 grad = sign(det) * (dFdx(h0) * r1 + dFdy(h0) * r2);
		float sc = (0.03 + 0.11 * min(v_surf.z, 1.0)) * u_wat.z;
		NORMAL = normalize(abs(det) * NORMAL - sc * grad);
	}

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = is_lava ? 0.25 : 0.92;
	if (is_lava) {
		EMISSION = emis;
	} else {
		// Exact 10-gfx.js:228 deep midnight sky Fresnel reflection (dark mirror catching torch/moonlight)
		EMISSION = emis + u_sky * (0.14 + 1.35 * fres) * (1.15 - 0.35 * min(v_surf.z, 1.0)) * (1.0 - w_mask * 0.85);
	}
}
