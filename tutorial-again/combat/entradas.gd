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


## Cámara de Python (mediapipe) enviando JSON por UDP al puerto 4242:
## {"defensa": bool, "esquiva": "IZQUIERDA"|"CENTRO"|"DERECHA", "ataque": "NINGUNO"|...}
class Camara extends Fuente:
	signal conectada

	const PUERTO: int = 4242

	var udp: PacketPeerUDP = PacketPeerUDP.new()
	## Último golpe recibido: mientras el gesto se mantiene NO se repite (un golpe por gesto).
	var _ultimo_ataque: String = "NINGUNO"
	## ¿Se pudo abrir el puerto?
	var escuchando: bool = false
	## ¿Ya llegó al menos un paquete de la cámara?
	var activa: bool = false

	func iniciar() -> void:
		escuchando = udp.bind(PUERTO) == OK

	func actualizar(_delta: float) -> void:
		if not escuchando:
			return
		while udp.get_available_packet_count() > 0:
			var paquete: PackedByteArray = udp.get_packet()
			var json: JSON = JSON.new()
			if json.parse(paquete.get_string_from_utf8()) != OK:
				continue
			if not (json.data is Dictionary):
				continue
			var datos: Dictionary = json.data
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
		udp.close()
		escuchando = false


## Teclado de respaldo: Shift = defender, A / D = esquivar,
## J = recto, K = hook, L = uppercut, Espacio = patada.
## Cada golpe se lanza UNA vez por pulsación: mantener la tecla no repite el golpe.
class Teclado extends Fuente:
	## Tiempo mínimo entre un golpe y el siguiente (lo que tarda el puño en volver).
	const ESPERA_ENTRE_GOLPES: float = 0.2

	var _espera: float = 0.0
	var _antes: Dictionary = {}

	## true solo en el frame en que la tecla pasa de suelta a apretada.
	func _recien_apretada(tecla: Key) -> bool:
		var ahora: bool = Input.is_key_pressed(tecla)
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

		# Se leen siempre las cuatro (para llevar la cuenta de "recién apretada").
		var recto: bool = _recien_apretada(KEY_J)
		var hook: bool = _recien_apretada(KEY_K)
		var uppercut: bool = _recien_apretada(KEY_L)
		var patada: bool = Input.is_action_just_pressed("ui_select")
		if _espera > 0.0:
			return
		if patada:
			ataque.emit("PATADA_DER")
		elif recto:
			ataque.emit("RECTO_DER")
		elif hook:
			ataque.emit("HOOK_IZQ")
		elif uppercut:
			ataque.emit("UPPERCUT_DER")
		else:
			return
		_espera = ESPERA_ENTRE_GOLPES
