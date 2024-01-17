shader_type canvas_item;
render_mode blend_mix;

varying vec2 world_uv;
varying vec2 terrain_uv;

uniform sampler2D terrain_tex;
uniform bool brush_tex_enabled = false;
uniform sampler2D brush_tex;

uniform float cutoff = 0.02;
uniform float modifier;

uniform float alpha_mult;

vec2 texture2uv(sampler2D t, vec2 uv) {
	ivec2 size = textureSize(t, 0);
	uv.x /= float(size.x);
	uv.y /= float(size.y);
	return uv;
}

vec2 brush_uv(vec2 uv) {
	ivec2 size = textureSize(brush_tex, 0);
	uv.x = float(size.x) * uv.x;
	return uv;
}

void vertex() {
	world_uv = VERTEX;
	terrain_uv = texture2uv(terrain_tex, world_uv);
}

void fragment() {
	COLOR = texture(terrain_tex, terrain_uv);
	vec2 local_uv = UV;
	// float shift = modifier;
	
	
	
	// if (local_uv.x > 0.5) {
	// 	local_uv.x = 1.0 - local_uv.x;
	// }
	
	// if (local_uv.x < (shift)) {
	// 	local_uv.x = mix(
	// 		0.0, 0.5,
	// 		smoothstep(0.0, (shift), local_uv.x)
	// 	)
	// } else {
	// 	local_uv.x = 0.5;
	// }
	
	if (brush_tex_enabled) {
		local_uv.x = 0.5;
		COLOR.a = texture(brush_tex, local_uv).r;
	} else {
		COLOR.a = alpha_mult;
	}
}