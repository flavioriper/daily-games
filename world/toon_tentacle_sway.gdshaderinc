// Procedural tentacle sway, shared by the base pass (toon_prop_tex) and the
// ink hull (toon_prop_outline) so the silhouette follows the flesh exactly.
//
// The deform runs in mesh-local space on the still GLB and reads the strand
// data SageStrands.bake() writes into the vertex colours (see that file for
// the channel contract): R the root-to-tip ratio along this strand, G its
// phase seed, B its azimuth around the bell, A the ownership gate. Baking the
// identity per strand is what makes the tentacles individuals — the old
// version keyed everything off a smooth function of vertex.xz, which handed
// neighbouring strands near-identical phase and swung them as one mass.
//
// G is exact per strand, so it jumps across the fused webbing between two
// tentacles. That is safe only because A is zero exactly there: read the two
// together or the mesh creases.
//
// Defaults keep the deform off for every prop that shares these shaders
// without opting in: at zero amplitude this is an exact no-op, so a crop with
// no COLOR array (which defaults to vec4(1.0)) never moves.

uniform float sway_amplitude = 0.0;
// Radians of phase per unit of root-to-tip ratio: the travelling-wave twist
// running down each strand.
uniform float sway_wave = 2.6;
uniform float sway_speed = 1.4;
// Share of the swing spent curling in and out under the bell, driven by the
// swim stroke rather than the free undulation.
uniform float sway_curl = 0.0;
// Mesh-local drop of a fully weighted tip as the bell accelerates away.
uniform float sway_trail = 0.0;
// Radians the stroke takes to travel from a strand's root to its tip.
uniform float sway_lag = 0.0;
// Live swim beat in radians, fed by SageIdle so the strands answer the same
// contraction the bell is playing instead of running on an unrelated clock.
uniform float sway_beat = 0.0;

const float SWAY_TAU = 6.28318530718;

vec3 tentacle_sway(vec3 vertex, vec4 strand, float time) {
	if (sway_amplitude <= 0.0) {
		return vertex;
	}
	float drop = strand.r;
	float gate = strand.a;
	if (drop <= 0.0 || gate <= 0.0) {
		return vertex;
	}
	// Quadratic in the baked ratio: the root barely stirs while the tip
	// carries the whole stroke. The gate closes over fused webbing.
	float weight = drop * drop * gate;
	float seed = strand.g;
	// The strand's amplitude bias is hashed back out of its phase seed rather
	// than baked: both are exact per strand, so this is stable, and it leaves
	// the alpha channel free for the gate.
	float bias = 0.6 + 0.8 * fract(seed * 7.3 + 0.31);
	float own = seed * SWAY_TAU;
	float ring = strand.b * SWAY_TAU;

	// Swing in the strand's own frame instead of world xz: radial is the curl
	// in and out under the bell, tangential the sweep around it. A jellyfish
	// gathers its tentacles; it does not wobble them sideways.
	vec2 footprint = vertex.xz;
	float reach = length(footprint);
	vec2 radial = reach > 0.0001 ? footprint / reach : vec2(1.0, 0.0);
	vec2 tangent = vec2(-radial.y, radial.x);

	// The stroke reaches the tip after it has left the root.
	float beat = sway_beat - drop * sway_lag;
	float pulse = sin(beat);
	float travel = drop * sway_wave;
	float clock = time * sway_speed;
	float primary = sin(clock + own - travel);
	// Second octave on an unrelated rate, keyed to the strand's place around
	// the bell: a slow ripple runs the ring while each strand does its own.
	float secondary = sin(clock * 0.41 + ring * 2.0 - travel * 0.63);
	float swing = primary + 0.45 * secondary;

	vec2 offset = radial * (sway_curl * pulse + 0.3 * swing)
		+ tangent * (0.85 * swing);
	vec3 swayed = vertex;
	swayed.xz += offset * (sway_amplitude * bias * weight);
	// cos is the contraction's rate of change, so the tips hang back hardest
	// while the body is accelerating away from them.
	swayed.y -= sway_trail * bias * weight * cos(beat);
	return swayed;
}
