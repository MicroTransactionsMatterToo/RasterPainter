shader_type canvas_item;
render_mode blend_premul_alpha;

uniform sampler2D stroke_texture;
uniform sampler2D base_texture;
uniform sampler2D erase_mask;

uniform bool enable_erase = false;


void fragment() {
	vec4 output_color;
	vec4 stroke_color = texture(stroke_texture, UV);
	vec4 base_color = texture(base_texture, UV);
	bool erase = texture(erase_mask, UV).a > 0.0f;
	if (stroke_color != vec4(0, 0, 0, 0)) {
		// Unmultiply colours
		if (stroke_color.a > 0.0f) {
			stroke_color.r = stroke_color.r / stroke_color.a;
			stroke_color.g = stroke_color.g / stroke_color.a;
			stroke_color.b = stroke_color.b / stroke_color.a;
		}
		
		
		// Mimic Color.blend
		float sa = 1.0f - stroke_color.a;
		output_color.a = base_color.a * sa + stroke_color.a;
		output_color.r = (
			base_color.r * base_color.a * sa + 
			stroke_color.r * stroke_color.a
		) / output_color.a;
		
		output_color.g = (
			base_color.g * base_color.a * sa + 
			stroke_color.g * stroke_color.a
		) / output_color.a;
		
		output_color.b = (
			base_color.b * base_color.a * sa + 
			stroke_color.b * stroke_color.a
		) / output_color.a;
		
		COLOR = output_color;
	} else {
		COLOR = base_color;
	}
	
	if (erase && enable_erase) {
		COLOR.a -= texture(erase_mask, UV).a;
	}
}