shader_type canvas_item;
render_mode blend_add, unshaded;

// One dot of the swarm (ui/menu/swarm_tab.gd): a unit quad per instance of a
// MultiMesh, drawn from its UV, no texture. The instance's custom data says
// what it is: x the shape (0 a soft mote, 0.5 a hex crystal, 1 a bokeh disc,
// the lens's out-of-focus circle with its bright rim, 0.15 a square: a pixel
// of a picture the draw tool put up, kept inside 0..1 so no driver's packing
// of the custom data can lose it), y how far out of focus
// it is (0 sharp .. 1 a blur), z its fringe (a fast dot splits its colours
// along its streak, the way a lens does), w its hot core (how white its
// middle burns). The bloom copy draws the same instances bigger (`grow`).
//
// Additive: what reaches the screen is COLOR.rgb * COLOR.a, so the cover is
// folded into the colour and the alpha left at one. No instance uniform.

uniform float grow = 1.0;

varying vec4 v_c;

void vertex() {
	v_c = INSTANCE_CUSTOM;
	VERTEX *= grow;
}

float shape(vec2 p, float kind) {
	if (kind > 0.1 && kind < 0.2) {
		return max(abs(p.x), abs(p.y));
	}
	if (kind > 0.25 && kind < 0.75) {
		return max(abs(p.x) * 0.866 + abs(p.y) * 0.5, abs(p.y));
	}
	return length(p);
}

float cover(vec2 p, float kind, float soft) {
	float d = shape(p, kind);
	// A pixel's square keeps a hard edge, a hair soft against the shimmer.
	float edge = (kind > 0.1 && kind < 0.2) ? mix(0.08, 0.5, soft) : mix(0.22, 0.95, soft);
	float a = 1.0 - smoothstep(1.0 - edge, 1.0, d);
	if (kind >= 0.75) {
		// A bokeh disc: a bright rim round a dimmer plate.
		a *= 0.3 + 0.7 * smoothstep(0.5, 0.86, d);
	} else if (kind > 0.25) {
		// A crystal: its facets catch the light at the edge.
		a *= 0.62 + 0.38 * smoothstep(0.45, 0.92, d);
	}
	return a;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float kind = v_c.x;
	float soft = v_c.y;
	float fringe = v_c.z * 0.18;
	float a = cover(p, kind, soft);
	float ar = a;
	float ab = a;
	if (fringe > 0.001) {
		ar = cover(p - vec2(fringe, 0.0), kind, soft);
		ab = cover(p + vec2(fringe, 0.0), kind, soft);
	}
	float core = (1.0 - smoothstep(0.0, 0.5, shape(p, kind))) * v_c.w * (1.0 - soft);
	vec3 col = mix(COLOR.rgb, vec3(1.0), core);
	COLOR = vec4(col.r * ar * COLOR.a, col.g * a * COLOR.a, col.b * ab * COLOR.a, 1.0);
}
