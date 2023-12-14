shader_type canvas_item;
render_mode blend_mix;

uniform float alpha_mult = 1.0;
uniform bool flip_y = true;
uniform bool invert_alpha = true;
uniform bool transition_in = true;
uniform bool transition_out = true;

uniform float transition_in_start = 0.02;
uniform float transition_out_start = 0.98;

uniform float y_offset = 0.0;

void fragment() {
	float Y_ALPHA;
	float X_MOD;
	float effective_y;
	
	if (UV.y > y_offset) {
		effective_y = UV.y;
		Y_ALPHA = mix(1.0, 0.0, 
			smoothstep(y_offset, 1.0, UV.y)
		);
	} else {
		Y_ALPHA = mix(0.0, 1.0, 
			smoothstep(0.0, y_offset, UV.y)
		);
	}
	

	
	if (flip_y) {
		Y_ALPHA = 1.0 - Y_ALPHA;
	}
	
	if (transition_in) {
		if (UV.x < transition_in_start) {
			X_MOD = mix(
				0.0,
				1.0,
				smoothstep(0.0, transition_in_start, UV.x)
			);
		}
	}
	
	if (transition_out) {
		if (UV.x > transition_out_start) {
			X_MOD = mix(
				1.0,
				0.0,
				smoothstep(transition_out_start, 1.0, UV.x)
			);
		}
	}
	
	if (X_MOD > 0.0) {
		Y_ALPHA = Y_ALPHA * X_MOD;
	}
	
	if (invert_alpha) {
		Y_ALPHA = abs(1.0 - Y_ALPHA);
	}
	
	COLOR.a = Y_ALPHA * alpha_mult;
}
