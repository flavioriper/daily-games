// planet_chart.gdshaderinc — shader twin of world/planet_chart.gd. The
// planet center is the world origin: radial up at any world point is
// normalize(point). Chart heights are radial offsets (old world Y).
const float PLANET_RADIUS = 43.7676;
const vec2 CHART_ORIGIN = vec2(-80.0, -55.0);
const vec2 CHART_SIZE = vec2(160.0, 110.0);
const float PLANET_TAU = 6.28318530;
const float PLANET_PI = 3.14159265;

// Returns (chart_x, height, chart_z) for a world-space point.
vec3 chart_from_world(vec3 p) {
	float r = length(p);
	vec3 u = p / max(r, 0.000001);
	float theta = acos(clamp(u.y, -1.0, 1.0));
	float lon = atan(u.x, u.z);
	lon += lon < 0.0 ? PLANET_TAU : 0.0;
	return vec3(
		CHART_ORIGIN.x + lon / PLANET_TAU * CHART_SIZE.x,
		r - PLANET_RADIUS,
		CHART_ORIGIN.y + theta / PLANET_PI * CHART_SIZE.y);
}

float chart_wrap_dx(float dx) {
	return dx - CHART_SIZE.x * round(dx / CHART_SIZE.x);
}

// Shortest chart-space delta a - b, seam-aware in x. Arguments are chart
// (x, z) pairs.
vec2 chart_delta(vec2 a, vec2 b) {
	return vec2(chart_wrap_dx(a.x - b.x), a.y - b.y);
}

vec3 chart_east(vec3 up) {
	vec3 east = vec3(up.z, 0.0, -up.x);
	float len = length(east);
	return len > 0.001 ? east / len : vec3(1.0, 0.0, 0.0);
}

vec3 chart_south(vec3 up) {
	return cross(chart_east(up), up);
}
