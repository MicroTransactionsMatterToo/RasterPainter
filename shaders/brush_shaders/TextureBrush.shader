shader_type canvas_item;
render_mode blend_mix;

uniform float alpha_mult = 1.0;

/* 
 * Very simple shader to fix Line2D transparency being shit 
 * if it overlaps itself
 */
void fragment()
{
    vec3 texCol = texture( TEXTURE, UV ).rgb;
    COLOR.rgb = texCol;
    COLOR.a = texture(TEXTURE, UV).a * alpha_mult;
}
