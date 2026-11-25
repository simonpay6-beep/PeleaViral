extends Node
## Música y efectos de sonido (autoload "Audio").
##
## PATRÓN: Singleton + Observer. Escucha EventBus.evento_combate y suena solo;
## fightSystem.gd no tiene que saber nada de audio.
##
## CÓMO AGREGAR SONIDOS: solo copia el archivo con el nombre correcto en
##   res://assets/audio/sfx/<nombre>.ogg   (o .wav / .mp3)
##   res://assets/audio/musica/<nombre>.ogg (o .mp3)
## Si un archivo no existe, simplemente no suena (no da error).
## La lista de nombres está en docs/AUDIO.md.

const CARPETA_SFX: String = "res://assets/audio/sfx/"
const CARPETA_MUSICA: String = "res://assets/audio/musica/"
const EXTENSIONES: Array[String] = ["ogg", "wav", "mp3"]

## Volumen en decibeles (0 = normal, -6 = la mitad aprox., -80 = silencio).
const VOLUMEN_MUSICA_DB: float = -8.0
## Volumen propio de algunas canciones (en dB). Las demás usan VOLUMEN_MUSICA_DB.
const VOLUMEN_POR_MUSICA: Dictionary = {"pelea": -0.8, "pelea_jefe": -0.8}  # -2 dB + 15 %
const VOLUMEN_SFX_DB: float = 0.0
const DURACION_FUNDIDO: float = 0.8
const CANALES_SFX: int = 8

## Qué música suena en cada escena. "" = silencio. Si una escena no está en la
## lista, se mantiene la música que ya estaba sonando.
const MUSICA_POR_ESCENA: Dictionary = {
	"res://inicio.tscn": "menu",
	"res://phone_intro.tscn": "intro",
	"res://netube_platform.tscn": "intro",
	"res://channel_dashboard.tscn": "intro",
	"res://juego.tscn": "pelea",
	"res://video_results.tscn": "canal",
	"res://final_periodico.tscn": "final",
	"res://final_hospital.tscn": "final",
}

## evento_combate (de EventBus) -> efecto de sonido.
const SFX_POR_EVENTO: Dictionary = {
	"golpe_conecta": "golpe",
	"bloqueo_rival": "bloqueo",
	"bloqueaste": "bloqueo",
	"esquivaste": "esquiva",
	"rival_golpea": "recibir_golpe",
	"guardia_rota": "guardia_rota",
	"guardia_recuperada": "guardia_recuperada",
	"noqueado": "noqueado",
	"ko_enemigo": "ko",
	"burla": "burla",
	"furia": "furia",
}

var _musica_a: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _musica_actual: String = ""
var _canales: Array[AudioStreamPlayer] = []
var _siguiente_canal: int = 0
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # que siga sonando aunque se pause
	get_tree().set_auto_accept_quit(false) # cerrar la ventana pasa por quit_game()
	_crear_bus("Musica")
	_crear_bus("SFX")

	_musica_a = _nuevo_player("Musica")
	_musica_b = _nuevo_player("Musica")
	for i in CANALES_SFX:
		_canales.append(_nuevo_player("SFX"))

	EventBus.evento_combate.connect(_on_evento_combate)
	# Sonido de clic en todos los botones del juego, sin tocar cada escena.
	get_tree().node_added.connect(_on_node_added)
	# Música de la primera escena (la que arranca el juego).
	_musica_de_escena_actual.call_deferred()


## Detiene la música y los efectos y suelta los archivos de audio. Se llama
## antes de cerrar el juego para que Godot no avise de recursos sin liberar.
func detener_todo() -> void:
	for p in get_children():
		if p is AudioStreamPlayer:
			p.stop()
			p.stream = null
	_musica_actual = ""
	_cache.clear()


## La X de la ventana pasa por SceneRouter.quit_game(), igual que el botón Salir.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SceneRouter.quit_game()


# ---------------------------------------------------------------- API pública

## Reproduce un efecto. `variar_tono` hace que golpes repetidos no suenen idénticos.
func sfx(nombre: String, variar_tono: bool = true, volumen_db: float = 0.0) -> void:
	var stream: AudioStream = _cargar(CARPETA_SFX, nombre)
	if stream == null:
		return
	var p: AudioStreamPlayer = _canales[_siguiente_canal]
	_siguiente_canal = (_siguiente_canal + 1) % _canales.size()
	p.stream = stream
	p.volume_db = VOLUMEN_SFX_DB + volumen_db
	p.pitch_scale = randf_range(0.92, 1.08) if variar_tono else 1.0
	p.play()


## Duración en segundos de un efecto (0 si el archivo no existe).
func duracion(nombre: String) -> float:
	var stream: AudioStream = _cargar(CARPETA_SFX, nombre)
	return stream.get_length() if stream != null else 0.0


## Cambia la música con un fundido. musica("") la apaga.
func musica(nombre: String) -> void:
	if nombre == _musica_actual:
		return
	_musica_actual = nombre
	_volumen_bus_musica(0.0) # una canción nueva siempre suena a volumen normal
	var sale: AudioStreamPlayer = _musica_a if _musica_a.playing else _musica_b
	var entra: AudioStreamPlayer = _musica_b if sale == _musica_a else _musica_a

	if sale.playing:
		var t: Tween = create_tween()
		t.tween_property(sale, "volume_db", -80.0, DURACION_FUNDIDO)
		t.tween_callback(sale.stop)

	var stream: AudioStream = _cargar(CARPETA_MUSICA, nombre) if nombre != "" else null
	if stream == null:
		return
	_activar_bucle(stream)
	entra.stream = stream
	entra.volume_db = -80.0
	entra.play()
	create_tween().tween_property(entra, "volume_db", VOLUMEN_POR_MUSICA.get(nombre, VOLUMEN_MUSICA_DB), DURACION_FUNDIDO)


## Baja el volumen de la música (sin cortarla) para que se escuchen bien los
## efectos, por ejemplo los sonidos del K.O. Vuelve a la normalidad con la
## siguiente canción.
func bajar_musica(db: float = -18.0, duracion: float = 0.4) -> void:
	var bus: int = AudioServer.get_bus_index("Musica")
	create_tween().tween_method(_volumen_bus_musica, AudioServer.get_bus_volume_db(bus), db, duracion)


## ¿Existe un archivo de música con este nombre?
func existe_musica(nombre: String) -> bool:
	return _cargar(CARPETA_MUSICA, nombre) != null


func _volumen_bus_musica(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musica"), db)


## La llama SceneRouter.go() antes de cambiar de escena.
func musica_para_escena(ruta: String) -> void:
	if MUSICA_POR_ESCENA.has(ruta):
		musica(MUSICA_POR_ESCENA[ruta])


# ---------------------------------------------------------------- interno

func _on_evento_combate(tipo: String) -> void:
	if SFX_POR_EVENTO.has(tipo):
		sfx(SFX_POR_EVENTO[tipo])


func _on_node_added(nodo: Node) -> void:
	if nodo is BaseButton:
		nodo.pressed.connect(sfx.bind("clic", false))


func _musica_de_escena_actual() -> void:
	var escena: Node = get_tree().current_scene
	if escena != null:
		musica_para_escena(escena.scene_file_path)


func _cargar(carpeta: String, nombre: String) -> AudioStream:
	var clave: String = carpeta + nombre
	if _cache.has(clave):
		return _cache[clave]
	var stream: AudioStream = null
	for ext in EXTENSIONES:
		var ruta: String = clave + "." + ext
		if ResourceLoader.exists(ruta):
			stream = load(ruta)
			break
	_cache[clave] = stream # también guarda null para no buscar otra vez
	return stream


func _activar_bucle(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if stream.loop_end <= 0:
			stream.loop_end = int(stream.get_length() * stream.mix_rate)


func _nuevo_player(bus: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _crear_bus(nombre: String) -> void:
	if AudioServer.get_bus_index(nombre) != -1:
		return
	AudioServer.add_bus()
	var i: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nombre)
	AudioServer.set_bus_send(i, "Master")
