shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D brush_tex;
uniform bool brush_tex_enabled = false;

uniform float override_alpha = 1.0;

/* 
 * Very simple shader to fix Line2D transparency being shit 
 * if it overlaps itself
 */
void fragment()
{
	if (brush_tex_enabled) {
		vec2 brush_uv = UV;
		brush_uv.x = 0.5;
		COLOR.a = texture(brush_tex, brush_uv).r * override_alpha;
	} else {
		COLOR.a = override_alpha;	
	}
}