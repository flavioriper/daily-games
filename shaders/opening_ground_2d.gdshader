shader_type canvas_item;

// The opening's paper (ui/opening.gd): the app icon's cream with light on it
// behind the grid, a pale heart and a warm skirt lower down, neither with an
// edge. It is a shader for one reason: a light this wide and this faint is
// a few levels of colour over hundreds of pixels, and drawn as a mesh it
// showed as rings. The grain here is under one level and breaks them up.
//
// `size` is the control's, in its own pixels, and the two lights are given
// in those; `lit` brings the light up after the first frame, which is the
// bare ground, the colour the screen already was. No instance uniform.

uniform vec4 ground : source_color = vec4(0.988, 0.961, 0.914, 1.0);
uniform vec4 heart : source_color = vec4(1.0, 1.0, 1.0, 0.75);
uniform vec4 skirt : source_color = vec4(1.0, 0.824, 0.627, 0.22);
uniform vec2 size = vec2(1080.0, 1920.0);
uniform vec2 heart_at = vec2(540.0, 810.0);
uniform float heart_reach = 680.0;
uniform vec2 skirt_at = vec2(540.0, 980.0);
uniform float skirt_reach = 1040.0;
uniform float lit : hint_range(0.0, 1.0) = 1.0;
uniform float level : hint_range(0.0, 1.0) = 1.0;

// Level at the middle and at the rim, so the light has no heart to see and
// no edge.
float fall(vec2 p, vec2 at, float reach) {
	float c = cos(min(distance(p, at) / reach, 1.0) * 1.5707963);
	return c * c;
}

void fragment() {
	vec2 p = UV * size;
	vec3 colour = mix(ground.rgb, skirt.rgb, fall(p, skirt_at, skirt_reach) * skirt.a * lit);
	colour = mix(colour, heart.rgb, fall(p, heart_at, heart_reach) * heart.a * lit);
	float grain = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	COLOR = vec4(colour + (grain - 0.5) / 255.0, level);
}
