// Scribbler1120 – Tusche-Toon-Shader
// Flache Farbstufen, Schraffur in den Schatten, leichte Papierkörnung.
// Gilt für Gebäude, Gelände, Figur und Natur, damit alles „aus demselben Zeichenbuch“ wirkt.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 albedo : source_color = vec4(0.91, 0.9, 0.87, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool use_texture = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float hatch_strength : hint_range(0.0, 0.5) = 0.18;
uniform float hatch_spacing = 7.0;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.06;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 c = albedo.rgb;
	if (use_texture) { c *= texture(albedo_tex, UV * uv_scale).rgb; }
	float g = hash(floor(FRAGCOORD.xy / 2.0));
	ALBEDO = c * (1.0 - grain_strength + grain_strength * g);
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float step_l = ndl > 0.45 ? 1.0 : (ndl > 0.0 ? 0.72 : 0.55);
	float hatch = step(0.55, fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing));
	if (step_l < 0.9) { step_l -= hatch_strength * hatch * (1.0 - step_l + 0.3); }
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * step_l;
}
