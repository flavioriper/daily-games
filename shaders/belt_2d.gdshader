shader_type canvas_item;

// The belts of Factory (factory/art.gd, `Art.belt_material`): set as the
// `material` of whatever draws `Art.belt()`, one mesh a belt tile under a
// transform or every belt on the land as the instances of one MultiMesh.
// Nothing is rebuilt and no instance carries a value (no instance uniform,
// CLAUDE.md): the mesh is drawn in tile space travelling to +x, and its UV
// says where on the belt a fragment is, x along the travel and y across,
// whichever way the instance's own transform has turned it. A rail's UV.y
// is -1: it is drawn as the mesh colours it and does not run.
//
// On the bed, slats are the gaps between them, darkened, with a little
// light on the edge that leads; a pale chevron a tile points the way. Both
// run toward +x at `speed` tiles a second by `time`, which `Art.belt_run`
// sets every frame, wrapped to one tile's travel so no driver takes the
// fraction of a large number. A chevron's period is a tile and a slat's a
// quarter of one, so belts in a row join without a step.

uniform float time = 0.0;
uniform float speed = 0.5;

const float SLATS = 4.0;

void fragment() {
	if (UV.y > -0.5) {
		float run = UV.x - fract(time * speed);
		float s = fract(run * SLATS);
		float board = smoothstep(0.0, 0.13, s) * (1.0 - smoothstep(0.87, 1.0, s));
		vec3 c = COLOR.rgb * mix(0.58, 1.0, board);
		c *= 1.0 + 0.08 * smoothstep(0.5, 0.88, s) * board;
		float u = fract(run);
		float v = abs(UV.y - 0.5);
		float d = abs(u - (0.64 - v * 0.85));
		float mark = (1.0 - smoothstep(0.035, 0.06, d)) * (1.0 - smoothstep(0.2, 0.235, v));
		COLOR.rgb = mix(c, vec3(1.0, 0.96, 0.84), mark * 0.7);
	}
}
