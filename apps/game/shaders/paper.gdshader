// The page itself: warm paper with sparse fibres. Deterministic per pixel so
// the page never shimmers.
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.968, 0.945, 0.882, 1.0);
uniform vec4 fiber : source_color = vec4(0.9, 0.862, 0.768, 1.0);
uniform vec2 size = vec2(640.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * size);
	float speck = hash(px);
	float strand = hash(floor(px / vec2(9.0, 1.0)) + vec2(0.0, floor(px.x / 9.0) * 0.37));
	vec4 c = paper;
	if (speck > 0.992) {
		c = mix(paper, fiber, 0.9);
	} else if (strand > 0.985) {
		c = mix(paper, fiber, 0.45);
	}
	COLOR = c;
}
