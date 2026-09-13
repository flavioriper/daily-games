shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Cozy cel shading. The body lives in toon_lit.gdshaderinc so the wind
// variant (toon_wind.gdshader) shares it.
#include "res://shaders/toon_lit.gdshaderinc"
