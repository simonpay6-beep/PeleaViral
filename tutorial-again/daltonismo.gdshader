shader_type canvas_item;
// Corrección de color para daltonismo (algoritmo "daltonize").
// 1) Simula cómo ve la imagen una persona con el tipo de daltonismo elegido.
// 2) Calcula la información de color que esa persona pierde.
// 3) La redistribuye hacia los canales que sí distingue.
// tipo: 0 = protanopia (rojo), 1 = deuteranopia (verde), 2 = tritanopia (azul).

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform int tipo = 1;
uniform float intensidad : hint_range(0.0, 1.0) = 1.0;

const mat3 RGB_A_LMS = mat3(
	vec3(17.8824, 3.45565, 0.0299566),
	vec3(43.5161, 27.1554, 0.184309),
	vec3(4.11935, 3.86714, 1.46709));
const mat3 LMS_A_RGB = mat3(
	vec3(0.0809444479, -0.0102485335, -0.000365296938),
	vec3(-0.130504409, 0.0540193266, -0.00412161469),
	vec3(0.116721066, -0.113614708, 0.693511405));

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	vec3 lms = RGB_A_LMS * c;
	vec3 sim = lms;
	if (tipo == 0) {
		sim.x = 2.02344 * lms.y - 2.52581 * lms.z;
	} else if (tipo == 1) {
		sim.y = 0.494207 * lms.x + 1.24827 * lms.z;
	} else {
		sim.z = -0.395913 * lms.x + 0.801109 * lms.y;
	}
	vec3 visto = LMS_A_RGB * sim;
	vec3 perdido = c - visto;
	vec3 correccion = vec3(0.0,
		0.7 * perdido.r + perdido.g,
		0.7 * perdido.r + perdido.b);
	COLOR = vec4(clamp(c + correccion * intensidad, 0.0, 1.0), 1.0);
}
