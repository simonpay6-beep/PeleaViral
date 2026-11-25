extends Node
## Puente con el detector de movimientos en Python (carpeta camara/).
##
## PATRÓN: Singleton (autoload "CamaraEnVivo") + Observer (señales).
## Escucha dos puertos UDP desde que arranca el juego, así el panel del canal
## ya sabe si la cámara está conectada antes de empezar la pelea:
##   - 4242: JSON con lo detectado {"defensa", "esquiva", "ataque", "movimiento"}
##   - 4243: una imagen JPEG pequeña de la cámara, para mostrarla en la pelea.
## Entradas.Camara (Adapter) traduce esos datos a golpes, defensa y esquiva.

signal datos_recibidos(datos: Dictionary)
signal cuadro_recibido(textura: Texture2D)

const PUERTO_DATOS: int = 4242
const PUERTO_VIDEO: int = 4243
## Si pasa más que esto sin recibir nada, la cámara se da por desconectada.
const SEGUNDOS_SIN_SENAL: float = 1.5
## Carpeta del detector: junto al .exe en el juego exportado, o dentro del proyecto en el editor.
const CARPETA_DETECTOR: String = "camara"

var udp_datos: PacketPeerUDP = PacketPeerUDP.new()
var udp_video: PacketPeerUDP = PacketPeerUDP.new()
## ¿Se pudo abrir el puerto de datos?
var escuchando: bool = false
## Última imagen de la cámara (null hasta que llegue la primera).
var textura: ImageTexture
## Texto de lo que el detector está viendo ("DEFENSA", "ESQUIVA IZQ", "RECTO DER"...).
var movimiento: String = ""

var _reloj: float = 0.0
var _ultima_senal: float = -99.0


func _ready() -> void:
	escuchando = udp_datos.bind(PUERTO_DATOS) == OK
	udp_video.bind(PUERTO_VIDEO)


func _exit_tree() -> void:
	udp_datos.close()
	udp_video.close()


## true si el detector mandó algo hace poco.
func conectada() -> bool:
	return _reloj - _ultima_senal < SEGUNDOS_SIN_SENAL


func _process(delta: float) -> void:
	_reloj += delta
	while udp_datos.get_available_packet_count() > 0:
		var json: JSON = JSON.new()
		if json.parse(udp_datos.get_packet().get_string_from_utf8()) != OK or not (json.data is Dictionary):
			continue
		recibir_datos(json.data)

	# Solo importa la imagen más nueva: las anteriores se descartan.
	var ultimo: PackedByteArray = PackedByteArray()
	while udp_video.get_available_packet_count() > 0:
		ultimo = udp_video.get_packet()
	if not ultimo.is_empty():
		recibir_cuadro(ultimo)


func recibir_datos(datos: Dictionary) -> void:
	_ultima_senal = _reloj
	movimiento = str(datos.get("movimiento", ""))
	datos_recibidos.emit(datos)


func recibir_cuadro(jpeg: PackedByteArray) -> void:
	var imagen: Image = Image.new()
	if imagen.load_jpg_from_buffer(jpeg) != OK:
		return
	_ultima_senal = _reloj
	if textura == null or textura.get_size() != Vector2(imagen.get_size()):
		textura = ImageTexture.create_from_image(imagen)
	else:
		textura.update(imagen)
	cuadro_recibido.emit(textura)


## Ruta del lanzador del detector (iniciar_camara.bat en Windows).
func ruta_detector() -> String:
	var base: String
	if OS.has_feature("editor"):
		base = ProjectSettings.globalize_path("res://").path_join(CARPETA_DETECTOR)
	else:
		base = OS.get_executable_path().get_base_dir().path_join(CARPETA_DETECTOR)
	if OS.get_name() == "Windows":
		return base.path_join("iniciar_camara.bat")
	return base.path_join("detector_peleaviral.py")


## Abre el detector de cámara en una ventana aparte. Devuelve false si no se encontró.
func abrir_detector() -> bool:
	var ruta: String = ruta_detector()
	if not FileAccess.file_exists(ruta):
		return false
	var pid: int
	if OS.get_name() == "Windows":
		pid = OS.create_process("cmd.exe", ["/c", "start", "", ruta])
	else:
		pid = OS.create_process("python3", [ruta])
	return pid > 0
