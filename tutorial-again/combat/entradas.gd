class_name Entradas
extends RefCounted
## Fuentes de control del jugador: cámara Python (UDP / MediaPipe) y teclado.
##
## PATRÓN: Adapter. Cada fuente traduce "su idioma" (paquetes JSON por UDP,
## teclas) al mismo idioma común:
##   - defensa: bool
##   - esquiva: "IZQUIERDA" | "CENTRO" | "DERECHA"
##   - señal ataque(tipo)   -> "RECTO_DER", "HOOK_IZQ", "UPPERCUT_DER", "PATADA_DER"...
## fightSystem.gd solo conoce esa interfaz, no sabe si juegas con cámara o teclado.


class Fuente extends RefCounted:
	signal ataque(tipo: String)

	var defensa: bool = false
	var esquiva: String = "CENTRO"

	func iniciar() -> void:
		pass

	## Se llama una vez por frame.
	func actualizar(_delta: float) -> void:
		pass

	func cerrar() -> void:
		pass


## Cámara: el detector de Python (camara/detector_peleaviral.py, con MediaPipe)
## manda JSON por UDP al autoload CamaraEnVivo, que reenvía cada paquete aquí:
## {"defensa": bool, "esquiva": "IZQUIERDA"|"CENTRO"|"DERECHA", "ataque": "NINGUNO"|...}
class Camara extends Fuente:
	signal conectada

	const PUERTO: int = 4242

	## Último golpe recibido: mientras el gesto se mantiene NO se repite (un golpe por gesto).
	var _ultimo_ataque: String = "NINGUNO"
	## ¿El servicio de cámara tiene el puerto abierto?
	var escuchando: bool = false
	## ¿Ya llegó al menos un paquete de la cámara?
	var activa: bool = false
	var _servicio: Node

	func iniciar() -> void:
		var arbol: SceneTree = Engine.get_main_loop() as SceneTree
		_servicio = arbol.root.get_node_or_null("CamaraEnVivo") if arbol != null else null
		if _servicio == null:
			return
		escuchando = _servicio.escuchando
		_servicio.datos_recibidos.connect(recibir)

	## Traduce un paquete del detector al idioma común (también lo usan las pruebas).
	func recibir(datos: Dictionary) -> void:
		if not activa:
			activa = true
			conectada.emit()
		defensa = datos.get("defensa", false)
		esquiva = datos.get("esquiva", "CENTRO")
		var tipo: String = datos.get("ataque", "NINGUNO")
		if tipo != "NINGUNO" and tipo != _ultimo_ataque:
			ataque.emit(tipo)
		_ultimo_ataque = tipo

	func cerrar() -> void:
		if _servicio != null and _servicio.datos_recibidos.is_connected(recibir):
			_servicio.datos_recibidos.disconnect(recibir)
		escuchando = false


## Teclado: Shift = defender, A / D = esquivar, P = recto,
## L = gancho izquierdo, Ñ = gancho derecho, O = uppercut, Espacio = patada.
## Cada golpe se lanza UNA vez por pulsación: mantener la tecla no repite el golpe.
class Teclado extends Fuente:
	## Tiempo mínimo entre un golpe y el siguiente (lo que tarda el puño en volver).
	const ESPERA_ENTRE_GOLPES: float = 0.2
	## Código de tecla de la Ñ.
	const TECLA_ENIE: int = 0x00D1

	var _espera: float = 0.0
	var _antes: Dictionary = {}

	## true solo en el frame en que la tecla pasa de suelta a apretada.
	## También se mira la tecla física (misma posición en teclados de otro idioma).
	func _recien_apretada(tecla: Key, fisica: Key = KEY_NONE) -> bool:
		var ahora: bool = Input.is_key_pressed(tecla) \
				or (fisica != KEY_NONE and Input.is_physical_key_pressed(fisica))
		var antes: bool = _antes.get(tecla, false)
		_antes[tecla] = ahora
		return ahora and not antes

	func actualizar(delta: float) -> void:
		_espera = maxf(0.0, _espera - delta)

		# Estas dos se mantienen mientras la tecla está apretada (y se sueltan solas).
		defensa = Input.is_key_pressed(KEY_SHIFT)
		if Input.is_key_pressed(KEY_A):
			esquiva = "IZQUIERDA"
		elif Input.is_key_pressed(KEY_D):
			esquiva = "DERECHA"
		else:
			esquiva = "CENTRO"

		# Se leen siempre todas (para llevar la cuenta de "recién apretada").
		var recto: bool = _recien_apretada(KEY_P)
		var hook_izq: bool = _recien_apretada(KEY_L)
		# La Ñ: Godot 4 no tiene constante para ella, su código es el de la letra (0xD1).
		# En teclados de otro idioma se usa la tecla de la misma posición (;).
		var hook_der: bool = _recien_apretada(TECLA_ENIE as Key, KEY_SEMICOLON)
		var uppercut: bool = _recien_apretada(KEY_O)
		var patada: bool = Input.is_action_just_pressed("ui_select")
		if _espera > 0.0:
			return
		if patada:
			ataque.emit("PATADA_DER")
		elif recto:
			ataque.emit("RECTO_DER")
		elif hook_izq:
			ataque.emit("HOOK_IZQ")
		elif hook_der:
			ataque.emit("HOOK_DER")
		elif uppercut:
			ataque.emit("UPPERCUT_DER")
		else:
			return
		_espera = ESPERA_ENTRE_GOLPES
