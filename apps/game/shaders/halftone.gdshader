// Ben-Day halftone shading for panel interiors. Dot radius ramps from `top`
// to `bottom` strength down the panel; rows are offset like printed comics.
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.95, 0.91, 0.81, 1.0);
uniform vec4 dot_color : source_color = vec4(0.79, 0.73, 0.58, 1.0);
uniform float spacing = 4.0;
uniform float top = 0.0;
uniform float bottom = 0.5;
uniform vec2 size = vec2(100.0, 100.0);

void fragment() {
	vec2 px = floor(UV * size);
	float row = floor(px.y / spacing);
	px.x += mod(row, 2.0) * spacing * 0.5;
	vec2 c = mod(px, spacing) - vec2(spacing * 0.5 - 0.5);
	float strength = mix(top, bottom, UV.y);
	float r = strength * spacing * 0.55;
	COLOR = length(c) < r ? dot_color : paper;
}
