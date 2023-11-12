shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float alpha_mult = 2.0;

void fragment() {
	//COLOR.rgb = COLOR.rgb;
	COLOR.r = 0.0;
	COLOR.g = 0.0;
	COLOR.b *= UV.y;
	COLOR.a = 1.0 - (alpha_mult * abs(UV.y - 0.5));
}