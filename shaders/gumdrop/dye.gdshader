shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The dye: each texel's three pigment amounts (red, yellow, blue, each
// over AMOUNT_TOP) carried along the velocity, with more squeezed in at
// the tip, and blended a little with its cell's neighbours each frame
// (`settle`), so a poured colour merges into one even shade in a few
// seconds instead of keeping its folds (the user, 2026-10-11: "liquid
// should merge color after being inserted, not keep as a vortex
// forever"). A texel keeps its own dye when the point it would read from
// lies in another cell or a wall: nothing crosses a wall. A tutorial page
// may fill a whole cell at once (`fill_cell`).

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D dye : filter_nearest, repeat_disable;
uniform sampler2D vel : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform ivec2 n = ivec2(128, 128);
uniform float dt = 0.016;
uniform vec2 tip = vec2(0.5, 0.5);
uniform int tip_cell = -1;
uniform float squeezing = 0.0;
uniform float radius = 0.045;
// Pigment a second at the tip's middle, in amounts, and the most the tip
// pours a texel up to (over AMOUNT_TOP): a strong pour that does not
// go black under the tip, and past which new dye displaces old.
uniform float rate = 4.0;
uniform float pour_top = 0.6;
uniform vec3 pigment = vec3(1.0, 0.0, 0.0);
uniform int fill_cell = -1;
uniform vec3 fill_pig = vec3(0.0);
uniform float clearing = 0.0;
// What of a texel is its neighbours' mean after a frame, and how far off
// the neighbours are read, in texels.
uniform float settle = 0.14;
uniform float settle_r = 3.0;

// One texel of the dye, or the texel's own when it lies in another cell
// or a wall: a wall is black, and reading it through the sampler's
// filter drained every cell from its rim (2026-10-11).
vec3 dye_texel(ivec2 p, vec3 own, int cell, ivec2 size) {
	p = clamp(p, ivec2(0), size - 1);
	if (int(round(texelFetch(mask, p, 0).r * 255.0)) - 1 != cell) {
		return own;
	}
	return texelFetch(dye, p, 0).rgb;
}

// The dye at a point, blended from the four texels about it, each one
// of its own cell.
vec3 dye_at(vec2 uv, vec3 own, int cell) {
	ivec2 size = textureSize(dye, 0);
	vec2 f = uv * vec2(size) - 0.5;
	vec2 fl = floor(f);
	ivec2 i = ivec2(fl);
	vec2 w = f - fl;
	vec3 a = dye_texel(i, own, cell, size);
	vec3 b = dye_texel(i + ivec2(1, 0), own, cell, size);
	vec3 c = dye_texel(i + ivec2(0, 1), own, cell, size);
	vec3 d = dye_texel(i + ivec2(1, 1), own, cell, size);
	return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

void fragment() {
	int cell = cell_of(mask, UV);
	if (clearing > 0.5 || cell < 0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		ivec2 size = textureSize(dye, 0);
		ivec2 here = ivec2(UV * vec2(size));
		vec3 own = texelFetch(dye, here, 0).rgb;
		vec2 v = vel_at(vel, UV * vec2(n), n);
		vec2 back = UV - v * dt / vec2(n);
		vec3 d = dye_at(back, own, cell);
		int o = int(settle_r);
		vec3 about = (dye_texel(here + ivec2(o, 0), own, cell, size) + dye_texel(here - ivec2(o, 0), own, cell, size)
			+ dye_texel(here + ivec2(0, o), own, cell, size) + dye_texel(here - ivec2(0, o), own, cell, size)) * 0.25;
		d = mix(d, about, settle);
		if (squeezing > 0.5 && tip_cell == cell) {
			vec2 off = UV - tip;
			float g = exp(-dot(off, off) / (radius * radius));
			// past the top the new dye takes the old one's place, so a
			// second flavour poured on a full cell shifts it toward itself
			d += pigment * (rate / AMOUNT_TOP) * g * dt;
			float tot = d.r + d.g + d.b;
			if (tot > pour_top) {
				d *= pour_top / tot;
			}
		}
		if (fill_cell == cell) {
			d = max(d, fill_pig / AMOUNT_TOP);
		}
		COLOR = vec4(min(d, vec3(1.0)), 1.0);
	}
}
