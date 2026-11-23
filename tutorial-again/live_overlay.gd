extends Control
## Panel del directo (título, viewers y chat). En Juego.tscn mide 340 x 420 y
## está en (780, 65).
##
## Observer: este panel NO es llamado por el combate. Se suscribe al EventBus
## y dibuja lo que se publica (mensajes, views y eventos de la pelea).
##
## Dinámico:
##   - cada mensaje entra con un fundido y el chat baja solo
##   - cada usuario tiene su color
##   - el chat REACCIONA a la pelea (golpes, esquivas, K.O...) con 1 a 3 mensajes
##   - las views suben contando, con hitos ("¡500 viewers!") y donaciones
##   - el punto EN VIVO parpadea

const MAX_MENSAJES: int = 40
const MAX_REACCIONES_PENDIENTES: int = 6
const INTERVALO_HITO: int = 500
## Estos "usuarios" son del sistema y se dibujan distinto.
const USUARIOS_SISTEMA: Array[String] = ["Sistema", "NeTube_Bot", "Bot_Tutorial"]

const USUARIOS: Array[String] = [
	"xX_BoxerPro_Xx", "NeTubeFan99", "CamaraFighter", "ElCritico_YT", "Kicker_BJJ",
	"PunchOutKing", "GatoGamer", "BarranquillaStream", "Sofi_Plays", "ElProfeVR", "LaChoclo", "TioMemo",
]
const COLORES: Array[String] = [
	"#ff7b7b", "#ffb347", "#ffe66d", "#8be28b", "#6fe3d6", "#7fb7ff", "#c59bff", "#ff8fd1",
]
const DONACIONES: Array[int] = [2, 5, 5, 10, 20]

## Qué dice el chat ante cada evento de la pelea.
const REACCIONES: Dictionary = {
	"golpe_conecta": ["¡¡PEGÓ!! 💥", "¡Qué golpe! 🥊", "¡Dale otra!", "ESO ES CLIP 🔥", "jajaja le dolió", "¡Sigue, sigue!"],
	"bloqueo_rival": ["uy, te bloqueó 🛡️", "pega por otro lado", "muy lento 😬", "¡Cambia el golpe!"],
	"burla": ["¡Se está burlando! Pégale 😤", "jajaja qué cara 😜", "¡¡AHORA!! ¡Está distraído!"],
	"noqueado": ["¡ESTÁ MAREADO, REMÁTALO! 💫", "¡¡AHORA AHORA!!", "💫💫💫", "¡Vulnerable!"],
	"ko_enemigo": ["¡¡¡K.O.!!! 🏆", "LEYENDA 🔥🔥🔥", "¡¡¡NO LO PUEDO CREER!!!", "clip del año", "¡AL PISO! 💀"],
	"rival_golpea": ["¡AUCH! 😵", "eso dolió hasta aquí", "¡Cúbrete, bro!", "uyyy 🩸", "la batería bajando 🔋😬"],
	"bloqueaste": ["¡Buena guardia! 🛡️", "ni se inmutó", "🛡️🛡️🛡️", "¡Qué defensa!"],
	"esquivaste": ["¡¡QUÉ REFLEJOS!! 💨", "esquivó sin mirar 😮", "Matrix 🕶️", "jajaja falló el golpe"],
	"guardia_rota": ["¡NOOO LA GUARDIA! ⚠️", "se le rompió la defensa 😱", "¡ahora está vendido!", "¡cuidado!"],
	"guardia_recuperada": ["volvió la guardia 🛡️", "¡rápido que viene otro!"],
	"derrota": ["F en el chat 🪦", "nooo se cayó 😭", "¡Revancha! ¡Revancha!", "casi casi"],
}

@onready var stream_title_label: Label = $Panel/Margin/VBox/TitleRow/StreamTitleLabel
@onready var live_badge: Label = $Panel/Margin/VBox/TitleRow/LiveBadge
@onready var viewers_label: Label = $Panel/Margin/VBox/ViewersLabel
@onready var chat_scroll: ScrollContainer = $Panel/Margin/VBox/ChatScroll
@onready var chat_lista: VBoxContainer = $Panel/Margin/VBox/ChatScroll/ChatLista

var _views_meta: int = 0
var _views_mostradas: float = 0.0
var _siguiente_hito: int = INTERVALO_HITO
var _ultima_bienvenida: int = 0
var _pendientes: int = 0
var _timer_donacion: float = 22.0
## Filas visibles del chat en orden de llegada (TAD Cola, FIFO).
var _filas: Cola = Cola.new()


func _ready() -> void:
	stream_title_label.text = ChannelData.video_title
	_pintar_views()

	EventBus.chat_message.connect(_on_chat_message)
	EventBus.views_changed.connect(_on_views_changed)
	EventBus.evento_combate.connect(_on_evento_combate)

	# El punto "EN VIVO" parpadea mientras dura el directo.
	var parpadeo: Tween = create_tween().set_loops()
	parpadeo.tween_property(live_badge, "modulate:a", 0.35, 0.7)
	parpadeo.tween_property(live_badge, "modulate:a", 1.0, 0.7)


func _process(delta: float) -> void:
	# Las views suben contando en vez de saltar de golpe.
	if not is_equal_approx(_views_mostradas, float(_views_meta)):
		var paso: float = maxf(40.0, absf(float(_views_meta) - _views_mostradas) * 4.0) * delta
		_views_mostradas = move_toward(_views_mostradas, float(_views_meta), paso)
		_pintar_views()

	# De vez en cuando alguien dona (solo si el directo ya tiene público).
	if _views_meta > 0:
		_timer_donacion -= delta
		if _timer_donacion <= 0.0:
			_timer_donacion = randf_range(18.0, 32.0)
			_agregar_donacion()


func _pintar_views() -> void:
	viewers_label.text = "👁️ %d viewers" % int(_views_mostradas)


# ------------------------------------------------------------ SUSCRIPCIONES ----

func _on_chat_message(usuario: String, mensaje: String) -> void:
	_agregar(usuario, mensaje)


func _on_views_changed(views: int) -> void:
	if views <= 0:
		_views_meta = 0
		_views_mostradas = 0.0
		_siguiente_hito = INTERVALO_HITO
		_ultima_bienvenida = 0
		_pintar_views()
		return
	_views_meta = views

	# Hitos: "¡500 viewers!", "¡1000 viewers!"...
	while views >= _siguiente_hito:
		_agregar_fila("[center][color=#ffd54a][b]🔥 ¡%d viewers en el directo! 🔥[/b][/color][/center]" % _siguiente_hito)
		_siguiente_hito += INTERVALO_HITO

	# Llega gente nueva a medida que suben las views.
	if views - _ultima_bienvenida >= 200:
		_ultima_bienvenida = views
		_agregar_fila("[color=#8a8fa3]👋 %s se unió al directo[/color]" % USUARIOS.pick_random())


func _on_evento_combate(tipo: String) -> void:
	var pool: Array = REACCIONES.get(tipo, [])
	if pool.is_empty() or _pendientes >= MAX_REACCIONES_PENDIENTES:
		return
	var cantidad: int = randi_range(1, 3)
	for i in cantidad:
		_pendientes += 1
		await get_tree().create_timer(randf_range(0.15, 0.6) * float(i + 1)).timeout
		_pendientes -= 1
		if not is_inside_tree():
			return
		_agregar(USUARIOS.pick_random(), str(pool.pick_random()))


# ---------------------------------------------------------------- MENSAJES ----

func _agregar(usuario: String, mensaje: String) -> void:
	if usuario in USUARIOS_SISTEMA:
		_agregar_fila("[color=#8a8fa3][i]%s: %s[/i][/color]" % [usuario, mensaje])
		return
	var color: String = COLORES[absi(usuario.hash()) % COLORES.size()]
	_agregar_fila("[b][color=%s]%s[/color][/b]  %s" % [color, usuario, mensaje])


func _agregar_donacion() -> void:
	var monto: int = DONACIONES.pick_random()
	var frase: String = ["¡Pelea, pelea!", "¡Para el café del campeón!", "¡Sigue así!", "¡Cuidado con la guardia!"].pick_random()
	_agregar_fila("[bgcolor=#5a3b00][color=#ffd54a]💸 [b]%s[/b] donó $%d: %s[/color][/bgcolor]" % [USUARIOS.pick_random(), monto, frase], true)


## Crea una fila de chat con fundido de entrada y baja el scroll.
func _agregar_fila(bbcode: String, destacada: bool = false) -> void:
	var fila: RichTextLabel = RichTextLabel.new()
	fila.bbcode_enabled = true
	fila.fit_content = true
	fila.scroll_active = false
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.text = bbcode
	fila.modulate.a = 0.0
	chat_lista.add_child(fila)

	var entrada: Tween = create_tween()
	entrada.tween_property(fila, "modulate:a", 1.0, 0.25)
	if destacada:
		fila.pivot_offset = Vector2(40.0, 10.0)
		fila.scale = Vector2(1.08, 1.08)
		entrada.parallel().tween_property(fila, "scale", Vector2.ONE, 0.3)

	# Cola FIFO: el mensaje nuevo entra por el final y, si sobran, sale el más antiguo.
	_filas.encolar(fila)
	while _filas.tamano() > MAX_MENSAJES:
		var viejo: Node = _filas.desencolar()
		if is_instance_valid(viejo):
			chat_lista.remove_child(viejo)
			viejo.queue_free()

	await get_tree().process_frame
	if is_instance_valid(fila) and fila.is_inside_tree():
		chat_scroll.ensure_control_visible(fila)
