shader_type canvas_item;

// Paper Planes' frenzy on the board's own three meshes: every dart at rest
// quivers on its own beat and everything warms toward a hot ramp, with no
// mesh rebuilt and no draw call added. Only a dart carries a phase, in UV.x
// (RunMesh.stamp, 0 is not a dart): the lines stay put, because a whole maze
// moving reads as the screen shaking (the user, 2026-11-01). No `instance
// uniform`, which is garbage on Android past 16.
uniform float heat = 0.0;
uniform float shake = 0.0;

const vec3 AMBER = vec3(1.0, 0.72, 0.22);
const vec3 EMBER = vec3(0.95, 0.25, 0.12);

void vertex() {
	if (shake > 0.0 && UV.x > 0.0) {
		float p = UV.x * 6.2832;
		float w = TIME * 52.0 + p * 9.0;
		VERTEX += shake * vec2(sin(w) + 0.5 * sin(w * 2.3 + p),
			cos(w * 1.17) + 0.5 * cos(w * 1.9 + p * 2.0));
	}
	if (heat > 0.0) {
		float luma = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
		vec3 hot = mix(AMBER, EMBER, heat) * (0.6 + 0.8 * luma);
		COLOR.rgb = mix(COLOR.rgb, hot, 0.25 + 0.5 * heat);
	}
}
