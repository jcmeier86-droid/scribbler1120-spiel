// Scribbler1120 – Tuschekontur (Inverted Hull)
// Wird als „next_pass“ an jedes Material gehängt: zeichnet eine dunkle, leicht unruhige Kontur.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.118, 0.118, 0.11, 1.0);
uniform float width = 0.05;
uniform float wobble = 0.35;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void vertex() {
	float w = width * (1.0 - wobble * 0.5 + wobble * hash(floor(VERTEX * 3.0)));
	VERTEX += NORMAL * w;
}

void fragment() {
	ALBEDO = ink.rgb;
}
