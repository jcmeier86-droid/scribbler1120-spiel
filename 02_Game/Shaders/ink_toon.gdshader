// Scribbler1120 – Tusche-Aquarell-Shader („Living Sketchbook“)
// Harte Licht-Schatten-Kante, Kreuzschraffur in TINTE in den Schatten, Aquarell-Wolken, Papierkorn.
// Muster: stripes = Ziegelreihen (Dach), cobble = Kopfsteinpflaster, masonry = Bruchstein, grass = Grasstriche.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(0.91, 0.9, 0.87, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool use_texture = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.118, 0.118, 0.110, 1.0);
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.45;
uniform float hatch_spacing = 7.0;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float watercolor : hint_range(0.0, 0.5) = 0.2;
uniform float stripes = 0.0;
uniform bool cobble = false;
uniform bool masonry = false;
uniform bool grass = false;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// Steinverband: Reihen mit versetzten, unterschiedlich breiten Steinen; liefert Fugen-Anteil (1 = Fuge)
float stones(vec2 p, vec2 size, float joint) {
	float row = floor(p.y / size.y);
	float x = p.x + hash(vec2(row, 3.0)) * size.x * 2.0;
	float w = size.x * (0.7 + 0.6 * hash(vec2(row, floor(x / size.x))));
	float col = floor(x / size.x);
	vec2 f = vec2(fract(x / size.x), fract(p.y / size.y));
	float wob = (noise(p * 9.0) - 0.5) * 0.04;
	float j = joint / size.x;
	float jy = joint / size.y;
	return max(step(f.x, j + wob) + step(1.0 - j + wob, f.x), step(f.y, jy + wob) + step(1.0 - jy + wob, f.y));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) { c *= texture(albedo_tex, UV * uv_scale).rgb; }
	vec2 q = wpos.xz * 0.18 + vec2(wpos.y * 0.31, -wpos.y * 0.17);
	float w = noise(q) * 0.6 + noise(q * 3.1) * 0.3 + noise(q * 9.0) * 0.1;
	c *= 1.0 - watercolor * 0.5 + watercolor * w;
	if (stripes > 0.0) {
		float s = fract(wpos.y / stripes + noise(wpos.xz * 2.0) * 0.08);
		if (s < 0.12) { c = mix(c, ink.rgb, 0.55); }
	}
	if (cobble) {
		float j = stones(wpos.xz, vec2(0.62, 0.46), 0.035);
		c *= 0.9 + 0.16 * hash(floor(wpos.xz * vec2(1.6, 2.2)));
		c = mix(c, ink.rgb, clamp(j, 0.0, 1.0) * 0.42);
	}
	if (masonry) {
		vec2 m = abs(wnrm.x) > abs(wnrm.z) ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		float j = stones(m, vec2(0.85, 0.42), 0.04);
		c *= 0.88 + 0.2 * hash(floor(m * vec2(1.2, 2.4)));
		c = mix(c, ink.rgb, clamp(j, 0.0, 1.0) * 0.5);
	}
	if (grass) {
		vec2 g = wpos.xz * 2.2;
		vec2 cell = floor(g);
		vec2 f = fract(g) - vec2(hash(cell), hash(cell + 7.0));
		float stroke = step(0.82, hash(cell + 3.0)) * step(abs(f.x + f.y * 0.35), 0.035) * step(abs(f.y), 0.3);
		c = mix(c, ink.rgb, stroke * 0.6);
	}
	float gr = hash(floor(FRAGCOORD.xy / 2.0));
	ALBEDO = c * (1.0 - grain_strength + grain_strength * gr);
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(0.42, 0.48, ndl);
	// Schatten als graue Tusche-Lavierung, nie schwarz
	float shade = mix(0.72, 1.0, lit);
	// Kreuzschraffur in TINTE nur im Schatten
	float h1 = step(0.78, fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing));
	float h2 = step(0.8, fract((FRAGCOORD.x - FRAGCOORD.y) / (hatch_spacing * 1.3)));
	float deep = 1.0 - smoothstep(-0.1, 0.2, ndl);
	float hatch = max(h1, h2 * deep) * (1.0 - lit) * hatch_strength;
	vec3 col = mix(ALBEDO * shade, ink.rgb, hatch);
	DIFFUSE_LIGHT += col * LIGHT_COLOR;
}
