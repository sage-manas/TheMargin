// Ben-Day halftone shading for panel interiors. Dot radius ramps from `top`
// to `bottom` strength down the panel; rows are offset like printed comics.
// Dots are measured in page units but edged per screen pixel, so they stay
// round and crisp at any window size (ADR-0013).
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.95, 0.91, 0.81, 1.0);
uniform vec4 dot_color : source_color = vec4(0.79, 0.73, 0.58, 1.0);
uniform float spacing = 4.0;
uniform float top = 0.0;
uniform float bottom = 0.5;
uniform vec2 size = vec2(100.0, 100.0);

void fragment() {
	vec2 p = UV * size;
	float row = floor(p.y / spacing);
	p.x += mod(row, 2.0) * spacing * 0.5;
	vec2 c = mod(p, spacing) - vec2(spacing * 0.5);
	float strength = mix(top, bottom, UV.y);
	float r = strength * spacing * 0.5;
	float d = length(c) - r;
	float aa = fwidth(d);
	float coverage = 1.0 - smoothstep(-aa, aa, d);
	COLOR = mix(paper, dot_color, r > 0.0 ? coverage : 0.0);
}
