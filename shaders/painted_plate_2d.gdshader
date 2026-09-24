shader_type canvas_item;

// One painted plate on the first screen: a crop of a vista, masked to a
// rounded rect, with the menu's washes -- all in one draw call. Drawn on a
// ColorRect (never a Panel, so CozyTheme.dress() leaves it alone); the vista
// is a sampler uniform rather than TEXTURE so a missing file can still draw
// the fallback gradient. No instance uniforms: each plate owns its material.
// Spec: docs/superpowers/specs/2026-09-24-painted-menu-design.md, section 3.

uniform sampler2D vista : source_color, filter_linear, repeat_disable;
// x, y, w, h of the crop in the vista's UV.
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 0.0;
// strength, from, to (fractions of the width): a wash toward paper from
// the left edge, behind text.
uniform vec3 scrim = vec3(0.0, 0.0, 1.0);
// A radial glow toward paper under the cast (card banners).
uniform float wash = 0.0;
// from, to (fractions of the height): fade to transparent. Past 1 is none.
uniform vec2 fade = vec2(2.0, 3.0);
uniform bool fallback = false;
uniform vec4 tint : source_color = vec4(0.30, 0.60, 0.58, 1.0);
uniform vec4 paper : source_color = vec4(0.965, 0.937, 0.890, 1.0);
uniform vec4 surface : source_color = vec4(1.0, 0.992, 0.973, 1.0);

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec3 c;
	if (fallback) {
		// Sky over a ground band, in the card's own colour let down into
		// paper -- the concept page's gradient fallback.
		float sky_t = clamp(UV.y / 0.62, 0.0, 1.0);
		vec3 sky = mix(tint.rgb, paper.rgb, mix(0.82, 0.70, sky_t));
		vec3 ground = mix(tint.rgb, paper.rgb, mix(0.55, 0.50, clamp((UV.y - 0.62) / 0.38, 0.0, 1.0)));
		c = UV.y < 0.62 ? sky : ground;
	} else {
		c = texture(vista, uv_rect.xy + UV * uv_rect.zw).rgb;
	}
	float s = scrim.x * (1.0 - smoothstep(scrim.y, scrim.z, UV.x));
	c = mix(c, paper.rgb, s);
	float d = length((UV - vec2(0.5, 0.58)) / vec2(0.46, 0.70));
	c = mix(c, surface.rgb, wash * (1.0 - smoothstep(0.0, 1.0, d)));
	vec2 p = (UV - 0.5) * rect_size;
	float edge = clamp(0.5 - rounded_box(p, rect_size * 0.5, radius), 0.0, 1.0);
	float a = edge * (1.0 - smoothstep(fade.x, fade.y, UV.y));
	// Multiply by the incoming COLOR so modulate (entrances, page-turn
	// crossfades) still reaches the plate.
	COLOR = vec4(c, a) * COLOR;
}
