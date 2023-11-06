shader_type canvas_item;
render_mode blend_mix;


void fragment()
{
	COLOR.rgb = texture(TEXTURE, UV).rgb;
    COLOR.g = texture(TEXTURE, UV).g * 2f;
}
