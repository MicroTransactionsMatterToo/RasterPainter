shader_type canvas_item;
render_mode blend_disabled;

uniform float override_alpha = 1.0;

/* 
 * Very simple shader to fix Line2D transparency being shit 
 * if it overlaps itself
 */
void fragment()
{
    COLOR.a = override_alpha;
}