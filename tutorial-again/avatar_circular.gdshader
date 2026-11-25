shader_type canvas_item;
// Recorta la imagen en forma de círculo (foto de perfil del canal).
// El borde se suaviza un poco para que no se vea pixelado.

void fragment() {
	float r = length(UV - vec2(0.5));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(0.485, 0.5, r);
}
