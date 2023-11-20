shader_type canvas_item;
render_mode blend_mix;

uniform float alpha_mult = 2.0;

void fragment() {
	COLOR.rgb = COLOR.rgb;
	COLOR.a = 1.0 - (alpha_mult * abs(UV.y - 0.5));
}