// The gust: the one piece of weather the world shares. toon_wind.gdshader,
// outline.gdshader and card_wind.gdshader #include this, so a blade of grass,
// the line ringing it and a blossom card beside it all lean by the same
// figure at the same moment -- which is the whole point, since a gust that
// each shader reads differently is a shimmer, not a wind.
//
// The shape: a band travelling across the world along wind_dir, one crest
// every gust_length units, sharpened by a cube so the lull between crests is
// long and the crest itself arrives quickly. That is what a gust crossing a
// field looks like from a distance: the grass goes over in a wave, holds,
// and comes back, rather than everything waving at once.
//
// Gated on the wind_gust global (project.godot [shader_globals]), which is 0
// everywhere and 1 only while the campsite is on the stage
// (world/stage.gd show_setting): a board's rim grass keeps exactly the
// flutter it was calibrated with, and the first screen gets the weather.

global uniform float wind_gust;
// Which way the wind blows, in world x/z. Across the frame to the right and
// only a little toward the camera, so a gust lays the grass over sideways --
// the way the camp's path and river already lead the eye. Aimed much further
// toward the camera it lays the blades down the view instead, and a field
// leaning at the lens reads as growing rather than as bending.
uniform vec2 wind_dir = vec2(0.95, 0.31);
// The crest's lean, as a multiple of the layer's own sway_amount. Above 1 so
// a gust is plainly more than the flutter it rides over.
uniform float gust_amount : hint_range(0.0, 6.0) = 2.2;
// World units between one crest and the next, and how fast they travel.
// A long wave crossing slowly: the far side of the camp leans a beat after
// the near side, not a whole cycle after it.
uniform float gust_length = 13.0;
uniform float gust_speed = 0.75;

// How hard the gust is blowing at world point `wp`: 0 through the lull, 1 at
// a crest.
float gust_at(vec3 wp, float time) {
	float d = dot(wp.xz, normalize(wind_dir)) / max(gust_length, 0.001);
	float s = sin(d - time * gust_speed) * 0.5 + 0.5;
	return s * s * s;
}

// The gust's push at `wp`, in the model space of `model` and in the same
// units as sway_amount, so a caller adds it straight onto VERTEX and the
// model matrix carries it to the world at the model's own scale.
//
// The direction is taken back through the model's basis (transpose, then
// normalized, which is the inverse rotation for a rotation-and-scale basis
// and handles a mirrored one too), so every prop leans the same way in the
// world however it is turned. The flutter above this does not bother: it is
// a shimmer with no direction to read. A gust has one, and a field of tufts
// each blowing down its own local x reads as chaos.
vec3 gust_lean(mat4 model, vec3 wp, float time, float amount) {
	vec3 dir = normalize(vec3(wind_dir.x, 0.0, wind_dir.y));
	vec3 local = normalize(transpose(mat3(model)) * dir);
	return local * (gust_at(wp, time) * amount * gust_amount * wind_gust);
}
