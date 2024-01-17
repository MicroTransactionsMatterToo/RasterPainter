shader_type canvas_item;
render_mode blend_mix;

varying vec2 world_uv;
varying vec2 terrain_uv;

uniform sampler2D terrain_tex;

uniform mat4 sprite_transform;

uniform float alpha_mult = 1.0;

vec2 texture2uv(sampler2D t, vec2 uv) {
	ivec2 size = textureSize(t, 0);
	uv.x /= float(size.x);
	uv.y /= float(size.y);
	return uv;
}

void vertex() {
	world_uv = VERTEX;
	world_uv = (sprite_transform * vec4(world_uv, 0.0, 1.0)).xy;
	//VERTEX = (EXTRA_MATRIX * (WORLD_MATRIX * vec4(VERTEX, 0.0, 1.0))).xy;
	terrain_uv = texture2uv(terrain_tex, world_uv);
}

void fragment() {
	COLOR = texture(terrain_tex, terrain_uv);
	COLOR.a = texture(TEXTURE, UV).r;
	COLOR.a *= alpha_mult;
}