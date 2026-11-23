// Scribbler1120 – Tusche-Aquarell-Shader
// Flache Farbstufen, Schraffur in den Schatten, Aquarell-Wolken, Papierkorn.
// Optional: Ziegelreihen (stripes) für Dächer, Grasstriche (grass) für den Boden.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(0.91, 0.9, 0.87, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool use_texture = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float hatch_strength : hint_range(0.0, 0.6) = 0.28;
uniform float hatch_spacing = 6.0;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.05;
uniform float watercolor : hint_range(0.0, 0.5) = 0.22;
uniform float stripes = 0.0;
uniform bool grass = false;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) { c *= texture(albedo_tex, UV * uv_scale).rgb; }
	// Aquarell: ungleichmäßige, weiche Farbwolken
	vec2 q = wpos.xz * 0.18 + vec2(wpos.y * 0.31, -wpos.y * 0.17);
	float w = noise(q) * 0.6 + noise(q * 3.1) * 0.3 + noise(q * 9.0) * 0.1;
	c *= 1.0 - watercolor * 0.55 + watercolor * w;
	if (stripes > 0.0) {
		float s = fract(wpos.y / stripes + noise(wpos.xz * 2.0) * 0.08);
		if (s < 0.13) { c *= 0.68; }
	}
	if (grass) {
		vec2 g = wpos.xz * 2.2;
		vec2 cell = floor(g);
		vec2 f = fract(g) - vec2(hash(cell), hash(cell + 7.0));
		float stroke = step(0.8, hash(cell + 3.0)) * step(abs(f.x + f.y * 0.35), 0.035) * step(abs(f.y), 0.3);
		c = mix(c, c * 0.55, stroke);
	}
	float gr = hash(floor(FRAGCOORD.xy / 2.0));
	ALBEDO = c * (1.0 - grain_strength + grain_strength * gr);
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float step_l = ndl > 0.4 ? 1.0 : (ndl > 0.0 ? 0.74 : 0.58);
	float hatch = step(0.6, fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing));
	if (step_l < 0.9) { step_l -= hatch_strength * hatch * (1.05 - step_l); }
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * step_l;
}
