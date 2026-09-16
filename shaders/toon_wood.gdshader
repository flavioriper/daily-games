shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Cozy cel shading with wood grain: the same lit body as toon.gdshader, with
// the include's WOOD_GRAIN block switched on. core/toon.gd hands this to any
// surface whose colour is one of the palette's woods, and sets grain_axis
// from the mesh's own longest side.
#define WOOD_GRAIN
#include "res://shaders/toon_lit.gdshaderinc"
