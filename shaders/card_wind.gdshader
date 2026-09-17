shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, specular_disabled;

// The painted cards -- the camp's blossoms and the leaf sheets filling its
// tree line -- turned to the camera and blowing in the same gust as the
// grass around them. It replaces the StandardMaterial3D they wore
// (assets/models/card_*.tres), which could turn but could not lean; a field
// of flowers standing rigid while the lawn goes over in a wave is the one
// thing that gave the wind away.
//
// Y-billboard with the instance's scale kept, which is what the standard
// material did: the card turns about its stem only, so it never lies down
// when the camera looks from above.
#include "res://shaders/wind.gdshaderinc"

global uniform float motion_scale;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float sway_base = 0.0;
uniform float sway_height = 0.5;
uniform float sway_amount = 0.02;
uniform float sway_speed = 1.6;

void vertex() {
	// The world spot the card stands on: its own origin, since the card is
	// about to be turned to face the camera and its vertices' world
	// positions turn with it. One spot per card is what we want anyway --
	// a card is small beside a gust's wavelength, so it leans as one thing.
	vec3 wp = MODEL_MATRIX[3].xyz;
	float h = clamp((VERTEX.y - sway_base) / sway_height, 0.0, 1.0);
	h *= h;

	// Screen-right in world, so the lean below reads as a lean across the
	// picture rather than into it: a billboard has no depth to lean into.
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	float across = dot(normalize(vec3(wind_dir.x, 0.0, wind_dir.y)), right);
	float ph = TIME * sway_speed + wp.x * 0.9 + wp.z * 0.7;
	VERTEX.x += (sin(ph) * sway_amount
		+ gust_at(wp, TIME) * sway_amount * gust_amount * wind_gust * across) * h * motion_scale;

	// Billboard about Y, the instance's scale kept (BILLBOARD_FIXED_Y with
	// billboard_keep_scale, written out).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * albedo.rgb;
	ALPHA = tex.a * albedo.a;
}
