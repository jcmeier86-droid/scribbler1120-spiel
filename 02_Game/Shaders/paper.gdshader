// Scribbler1120 – Papierwirkung über dem ganzen Bild
shader_type canvas_item;
uniform float strength : hint_range(0.0, 0.4) = 0.2;
uniform vec4 paper : source_color = vec4(0.98, 0.976, 0.965, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float n = noise(p * 0.35) * 0.6 + noise(p * 0.08) * 0.4;
	float fibre = noise(vec2(p.x * 0.02, p.y * 0.9)) * 0.3;
	COLOR = vec4(paper.rgb * (0.82 + 0.18 * n) - fibre * 0.05, strength);
}
