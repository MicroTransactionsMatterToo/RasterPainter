shader_type canvas_item;
render_mode blend_mix;

uniform vec4 brush_color;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a = COLOR.r;
	COLOR.rgb = brush_color.rgb;
}