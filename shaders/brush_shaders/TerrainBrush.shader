shader_type canvas_item;
render_mode blend_mix;

varying vec2 world_uv;
varying vec2 terrain_uv;

uniform sampler2D terrain_tex;
uniform float alpha_mult;

vec2 texture2uv(sampler2D t, vec2 uv) {
	ivec2 size = textureSize(t, 0);
	uv.x /= float(size.x);
	uv.y /= float(size.y);
	return uv;
}

void vertex() {
	world_uv = VERTEX;
	terrain_uv = texture2uv(terrain_tex, world_uv);
}

void fragment() {
	COLOR = texture(terrain_tex, terrain_uv);
	COLOR.a = alpha_mult;
}