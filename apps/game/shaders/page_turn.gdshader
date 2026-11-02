// Page turn: a fold line sweeps from the bottom-right corner to the left,
// revealing the next page underneath; the turned-over flap shows the back of
// the paper. `fade_only` is the reduced-motion alternative.
shader_type canvas_item;

uniform float progress = 0.0;
uniform bool fade_only = false;
uniform vec4 back_color : source_color = vec4(0.93, 0.89, 0.79, 1.0);
uniform vec4 ink : source_color = vec4(0.113, 0.105, 0.149, 1.0);

const float TILT = 0.35;

void fragment() {
	vec4 old = texture(TEXTURE, UV);
	if (fade_only) {
		COLOR = vec4(old.rgb, 1.0 - progress);
	} else {
		vec2 px = floor(UV * vec2(640.0, 360.0));
		float c0 = 640.0 + 360.0 * TILT;
		float c = mix(c0, -24.0, progress);
		float d = c - (px.x + (360.0 - px.y) * TILT);
		float flap = (c0 - c) * 0.5;
		if (d < 0.0) {
			COLOR = d > -6.0 ? vec4(ink.rgb, 0.22) : vec4(0.0);
		} else if (d < 1.0) {
			COLOR = ink;
		} else if (d < flap) {
			COLOR = vec4(mix(back_color.rgb, ink.rgb, 0.2 * (1.0 - d / flap)), 1.0);
		} else {
			COLOR = old;
		}
	}
}
