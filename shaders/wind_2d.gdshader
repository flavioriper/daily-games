shader_type canvas_item;

// Wind over the Grove (valley/grove_art.gd, `Art.wind`): set as the
// `material` of a Control that draws trees or grass, each a cached mesh
// standing on its own (0, 0) with y running up into the negative, drawn
// under a transform or as an instance of a MultiMesh. Nothing is rebuilt:
// the mesh leans in the vertex stage, more the higher a vertex is above its
// foot, so a trunk stays planted and a crown travels.
//
// The wind is a gust that crosses the land from the left as a slow wave,
// with a quicker sway riding on it, both read from where the thing stands
// (the model matrix's origin, which carries a draw's transform and a
// MultiMesh instance's alike), so neighbours move nearly together and the
// far side of the land follows a moment later. `Art.gust` is the same wave
// in script, for what the screen blows along with it (the loose leaves).
// On top, a crown rustles: every vertex shivers on a time of its own.
//
// What is drawn where it lies (a mesh under no transform, a rectangle, a
// circle: all at y >= 0 in their item) has no height and does not move.
// No instance uniform anywhere (CLAUDE.md): the looks (trees, grass, and
// the shadows the trees throw) are materials off this one file. `clock` is
// set from script every frame and `amp` is 0 under reduce motion.
//
// A shadow (`Art.shade_wind`) is a tree's own outline, standing, drawn
// under a transform that lays it on the ground (`Art.cast`): the vertex
// still has the tree's height, so it leans on the same gust as its tree,
// but `along` turns that lean into the way a shadow goes when a crown moves
// downwind. `land_half` over 0 keeps what is drawn to the land (a diamond
// that far across about `land_at`, `land_u` pixels a unit, its corners cut
// as the land's are rounded): a shadow stops at the turf's edge and never
// lies on the earth's side or the pond.

uniform float clock = 0.0;
uniform float amp = 1.0;
// The height, in the mesh's own units, that leans `reach` of them in a full
// gust; what stands taller leans further.
uniform float tall = 120.0;
uniform float reach = 7.0;
// How far a vertex shivers, at most.
uniform float rustle = 1.0;
// The way a lean moves a vertex, in the mesh's own units, and how much of
// it bows the top down.
uniform vec2 along = vec2(1.0, 0.0);
uniform float droop = 0.22;
uniform float land_half = 0.0;
uniform vec2 land_at = vec2(0.0);
uniform float land_u = 1.0;
uniform float land_deep = 0.66;

varying vec2 spot;

void vertex() {
	float h = max(0.0, -VERTEX.y);
	vec2 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float gust = 0.5 + 0.5 * sin(clock * 0.55 - at.x * 0.0035 + 1.7 * sin(clock * 0.19));
	float sway = sin(clock * 1.9 - at.x * 0.012 + at.y * 0.009);
	// leaning downwind while it blows, and swaying about that lean
	float lean = 0.15 + 0.6 * gust + (0.2 + 0.4 * gust) * sway;
	float k = pow(h / tall, 1.5);
	float shiver = sin(clock * 6.3 + VERTEX.x * 0.19 + VERTEX.y * 0.23 + at.x * 0.05);
	VERTEX += along * amp * (reach * lean * k + rustle * (0.3 + 0.7 * gust) * shiver * min(k, 1.0));
	VERTEX.y += amp * reach * droop * lean * k * k;
	spot = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - land_at) / land_u;
}

void fragment() {
	if (land_half > 0.0) {
		vec2 q = abs(spot);
		q.y /= land_deep;
		float m = max(q.x + q.y, max(q.x + 40.0, q.y + 60.0));
		COLOR.a *= 1.0 - smoothstep(land_half - 5.0, land_half - 1.0, m);
	}
}
