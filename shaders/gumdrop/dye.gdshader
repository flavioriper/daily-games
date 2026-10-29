shader_type canvas_item;
render_mode blend_disabled, unshaded;

// The dye: each texel's three pigment amounts (red, yellow, blue, each
// over AMOUNT_TOP) carried along the velocity, with more squeezed in at
// the tip, and blended a little with its cell's neighbours each frame
// (`settle`), so a poured colour merges into one even shade in a few
// seconds instead of keeping its folds (the user, 2026-10-11: "liquid
// should merge color after being inserted, not keep as a vortex
// forever"). A texel keeps its own dye when the point it would read from
// lies in another chunk or off the jelly: nothing crosses a seam. A tutorial page
// may fill a whole cell at once (`fill_cell`).
//
// That near blend alone irons a fold and leaves a cell two shades: read
// three texels off it crosses a cell in half a minute, and in eight bits
// it stops at a slope of two steps a read, a fifth of the scale across a
// petal (the user, 2026-10-11, of a petal red at one end and blue at the
// other: "colors are hard to mix"). Every texel of a chunk is blended
// with eight texels far off as well (`far`), which carries a pour to
// the chunk's far end in a few seconds.
//
// It is a tint in water (the user, 2026-10-14: "it should keep doing
// the exactly same behavior of moving around to fill available space,
// the difference is that the color will be way lighter after space
// filled ... It has to act exactly like water tint"): the dye rides the
// flow and both settles work on every texel, clear or tinted, whether
// the button is held or not, and nothing of them adds or takes pigment.
// Each settle is a mean over a symmetric stencil whose taps outside the
// chunk read the texel's own, so the chunk's pigment is kept while it
// spreads: a dab let go goes on spreading until it is one shade over its
// whole chunk, paler for it, and a pour held pushes what is in ahead of
// it until the chunk is full. For a day on 2026-10-14 a blob let go was
// frozen instead (a `front` under which a texel took nothing, the flow
// dropped a moment after the release), at the user's earlier word, read
// too far.

#include "res://shaders/gumdrop/fluid.gdshaderinc"

uniform sampler2D dye : filter_nearest, repeat_disable;
uniform sampler2D vel : filter_nearest, repeat_disable;
uniform sampler2D mask : filter_nearest, repeat_disable;
// The meter's last frame (meter.gdshader: a texel a chunk, its mean
// pigments over AMOUNT_TOP): the chunk under the tip takes no more past
// the card's shade (the user, 2026-10-14: "if 100% no more liquid can be
// added"), the pour easing to nothing over the last `full_ease` of C_FULL.
// Read here rather than on the CPU so the cap never waits on a readback.
uniform sampler2D meter : filter_nearest, repeat_disable;
uniform float full_ease = 0.06;
uniform ivec2 n = ivec2(128, 128);
uniform float dt = 0.016;
uniform vec2 tip = vec2(0.5, 0.5);
uniform int tip_cell = -1;
uniform float squeezing = 0.0;
// The grey button held: pigment taken out about the tip at `drain_rate`
// (the pour's own rate before the chunk's cap, which `rate` is under:
// at 100% `rate` is nothing, and a drain at `rate` took nothing out of a
// full chunk, 2026-10-14), every pigment in its share, while the far
// settle levels the chunk down with it.
uniform float draining = 0.0;
uniform float drain_rate = 4.0;
uniform float radius = 0.045;
// Pigment a second at the tip's middle, in amounts, and the most the tip
// pours a texel up to (over AMOUNT_TOP): a strong pour that does not
// go black under the tip, and past which new dye displaces old.
uniform float rate = 4.0;
uniform float pour_top = 0.6;
uniform vec3 pigment = vec3(1.0, 0.0, 0.0);
uniform int fill_cell = -1;
uniform vec3 fill_pig = vec3(0.0);
// The bulb's second press (2026-10-29): the cell set to fill_pig outright,
// whatever was in it, not only raised to it.
uniform bool fill_exact = false;
uniform float clearing = 0.0;
// What of a texel is its neighbours' mean after a frame, and how far off
// the neighbours are read, in texels.
uniform float settle = 0.14;
uniform float settle_r = 3.0;
uniform float far = 0.4;
uniform float far_r = 14.0;

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
		// the dye rides the flow, held or let go: a flow at rest is slow
		// but never nothing, and its drift is the tint's own spreading
		vec3 d = dye_at(back, own, cell);
		// the near settle: a fold ironed, the pour's edge softened
		int o = int(settle_r);
		ivec2 near[4] = {ivec2(o, 0), ivec2(-o, 0), ivec2(0, o), ivec2(0, -o)};
		vec3 about = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			about += dye_texel(here + near[i], own, cell, size);
		}
		d = mix(d, about * 0.25, settle);
		// the far settle: the chunk levelled, shade and amount, so a tint
		// reaches its far end in a few seconds and two flavours become one
		int a = int(far_r);
		int g = int(far_r * 0.7071 + 0.5);
		ivec2 taps[8] = {ivec2(a, 0), ivec2(-a, 0), ivec2(0, a), ivec2(0, -a), ivec2(g, g), ivec2(-g, -g), ivec2(g, -g), ivec2(-g, g)};
		vec3 wide = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			wide += dye_texel(here + taps[i], own, cell, size);
		}
		d = mix(d, wide * 0.125, far);
		if (squeezing > 0.5 && tip_cell == cell) {
			vec2 off = UV - tip;
			float g = exp(-dot(off, off) / (radius * radius));
			vec3 have = texelFetch(meter, ivec2(cell, 0), 0).rgb * AMOUNT_TOP;
			float room = clamp((C_FULL - (have.r + have.g + have.b)) / (C_FULL * full_ease), 0.0, 1.0);
			// past a texel's top the new dye takes the old one's place, so
			// nothing goes black under the tip
			d += pigment * (rate * room / AMOUNT_TOP) * g * dt;
			float tot = d.r + d.g + d.b;
			if (tot > pour_top) {
				d *= pour_top / tot;
			}
		}
		if (draining > 0.5 && tip_cell == cell) {
			vec2 off = UV - tip;
			float g = exp(-dot(off, off) / (radius * radius));
			float tot = d.r + d.g + d.b;
			if (tot > 0.0) {
				float take = (drain_rate / AMOUNT_TOP) * g * dt;
				d *= max(0.0, tot - take) / tot;
			}
		}
		if (fill_cell == cell) {
			d = fill_exact ? fill_pig / AMOUNT_TOP : max(d, fill_pig / AMOUNT_TOP);
		}
		COLOR = vec4(min(d, vec3(1.0)), 1.0);
	}
}
