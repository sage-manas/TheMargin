// The page itself: warm paper with sparse fibres. Deterministic per page
// unit so the page never shimmers; fibres are soft-edged per screen pixel so
// they stay fine at any window size (ADR-0013).
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.968, 0.945, 0.882, 1.0);
uniform vec4 fiber : source_color = vec4(0.9, 0.862, 0.768, 1.0);
uniform vec2 size = vec2(640.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * size;
	vec2 cell = floor(p);
	vec4 c = paper;
	// Specks: a soft dot in a few cells.
	if (hash(cell) > 0.992) {
		float d = length(fract(p) - 0.5) - 0.35;
		c = mix(c, fiber, 0.9 * (1.0 - smoothstep(-fwidth(d), fwidth(d), d)));
	}
	// Fibres: short horizontal strands, thin and slightly faded.
	vec2 sc = floor(p / vec2(9.0, 1.0));
	if (hash(sc + vec2(0.0, floor(p.x / 9.0) * 0.37)) > 0.985) {
		float d = abs(fract(p.y) - 0.5) - 0.18;
		c = mix(c, fiber, 0.45 * (1.0 - smoothstep(-fwidth(d), fwidth(d), d)));
	}
	COLOR = c;
}
