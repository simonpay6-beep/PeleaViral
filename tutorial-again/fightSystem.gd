extends Control
## Controlador de Juego.tscn (1152 x 648): tutorial del árbol, historia, pelea
## y cinemática final.
##
## Este script ORQUESTA. Lo repetitivo está repartido en patrones:
##   - Estados del enemigo ... combat/estados_enemigo.gd  (State)
##   - Reglas de cada nivel .. combat/niveles.gd          (Strategy + Factory)
##   - Cámara / teclado ...... combat/entradas.gd         (Adapter)
##   - Chat y views .......... event_bus.gd               (Observer)
##   - Cambio de escena ...... scene_router.gd            (Singleton + Facade)
##   - Puños del jugador ..... manos_jugador.gd           (animación por código)

# --- CONFIGURACIÓN DEL FINAL ---
# El final del Nivel 3 está en final_hospital.tscn (allí se elige si el juego se cierra o vuelve al menú).

# --- DIFICULTAD (ChannelData.selected_difficulty): velocidad del enemigo y multiplicador de views ---
const DIFICULTADES: Dictionary = {
	"Fácil": {"velocidad": 1.35, "views": 1},
	"Normal": {"velocidad": 1.0, "views": 1},
	"Hardcore": {"velocidad": 0.70, "views": 2},
}

# --- TEXTOS DE LA CINEMÁTICA FINAL (NIVEL 3) ---
const TEXTO_CAIDA: String = "GOLPE 10/10 — HAS CAÍDO EN LA LONA\n\n[TRANSMISIÓN EN DIRECTO INTERRUMPIDA]"

# --- REFERENCIAS A LOS NODOS DE JUEGO.TSCN ---
@onready var fondo: CanvasItem = $Fondo
@onready var imagen_fondo: TextureRect = $Fondo/ImagenFondo
@onready var sprite_enemigo: AnimatedSprite2D = $EnemigoSprite
@onready var moscas: AnimatedSprite2D = $EnemigoSprite/Moscas
@onready var manos: ManosJugador = $ManosJugador
@onready var ui_combate: Control = $UI_Combate
@onready var lbl_titulo_nivel: Label = $UI_Combate/TituloNivel
@onready var barra_vida_enemigo: ProgressBar = $UI_Combate/VidaEnemigo
@onready var lbl_dialogo_enemigo: Label = $UI_Combate/DialogoEnemigo
@onready var lbl_estado_enemigo: Label = $UI_Combate/EstadoEnemigoTexto
@onready var barra_vida_jugador: ProgressBar = $UI_Combate/VidaJugador
@onready var lbl_estado_jugador: Label = $UI_Combate/EstadoJugadorTexto
@onready var bateria: TextureRect = $UI_Combate/BateriaJugador
@onready var flash_dano: ColorRect = $UI_Combate/FlashDano
@onready var panel_controles: ControlesPanel = $UI_Combate/PanelControles
@onready var pantalla_cinematica: ColorRect = $PantallaCinematica
@onready var texto_cinematica: Label = $PantallaCinematica/TextoCinematica

# --- FASES DEL JUEGO ---
enum Fase { TUTORIAL_ARBOL, HISTORIA_INTRO, PELEA, KO_RIVAL, ANIMACION_RESULTADO, CINEMATICA_FINAL }

## Al derrotar al rival suenan "ko_romper" (lego) y luego "ko_desmayo"; las
## estadísticas aparecen esta cantidad de segundos después de los sonidos.
const PAUSA_ANTES_DE_ESTADISTICAS: float = 1.2

var fase_actual: Fase = Fase.TUTORIAL_ARBOL
var nivel_actual: int = 1
var golpes_jefe_conectados: int = 0

# Strategy (reglas del nivel) y State (estado actual del enemigo)
var estrategia: Niveles.Estrategia = Niveles.crear(1)
var estado_enemigo: EstadosEnemigo.Estado = EstadosEnemigo.crear(EstadosEnemigo.Id.IDLE)

# --- MÉTRICAS DEL STREAM Y CHAT EN VIVO ---
# Observer: cada vez que cambian, el panel del directo se entera solo.
var views_en_vivo: int = 0:
	set(valor):
		views_en_vivo = valor
		EventBus.views_changed.emit(valor)
var mult_views: int = 1
var factor_velocidad_dificultad: float = 1.0
var timer_chat_random: float = 2.0

## Turno de los espectadores que comentan (TAD ListaCircular): cada comentario
## ambiental lo escribe el siguiente usuario de la ronda, sin repetir seguido.
var turno_espectadores: ListaCircular = ListaCircular.desde([
	"xX_BoxerPro_Xx", "NeTubeFan99", "CamaraFighter", "ElCritico_YT",
	"Kicker_BJJ", "PunchOutKing", "GatoGamer", "BarranquillaStream"
])
## Récords de cada nivel guardados en archivo (TAD HistorialPeleas).
var historial: HistorialPeleas = HistorialPeleas.new()

# --- ENTRADAS DEL JUGADOR (Adapter): cámara Python por UDP y teclado ---
var camara: Entradas.Camara = Entradas.Camara.new()
var teclado: Entradas.Teclado = Entradas.Teclado.new()

# Defensa y esquiva salen de la fuente elegida antes del live (cámara o teclado).
# Si se eligió cámara y se desconecta, el teclado sigue funcionando de respaldo.
# La guardia rota anula la defensa.
var defendiendo: bool:
	get:
		var fuente: Entradas.Fuente = camara if usando_camara() else teclado
		return fuente.defensa and not guardia_rota
## Sin estamina (agotado) el cuerpo no responde: no se puede esquivar.
var esquiva_actual: String:
	get:
		if agotado:
			return "CENTRO"
		return camara.esquiva if usando_camara() else teclado.esquiva

# --- ESTADÍSTICAS DEL JUGADOR ---
var vida_max_jugador: float = 100.0
var vida_jugador: float = 100.0

# Ruptura de guardia (Delay de 3s si te golpean mucho cubriéndote)
var guardia_rota: bool = false
var golpes_en_guardia: int = 0
var max_golpes_guardia: int = 4
var tiempo_delay_guardia: float = 3.0
var timer_ruptura: float = 0.0

# --- ESTAMINA DEL JUGADOR ---
## Esquivar cansa: cada esquiva exitosa gasta estamina y quedarse inclinado también.
## Sin estamina quedas AGOTADO: no puedes esquivar ni golpear hasta recuperar un poco.
## Además la esquiva solo vale si te mueves DESPUÉS del aviso del rival (reflejos):
## quedarse inclinado de antemano ya no sirve.
const ESTAMINA_MAX: float = 100.0
const COSTO_ESQUIVA: float = 17.9            # dos veces 25 % más lento (al inicio era 28)
const DESGASTE_INCLINADO: float = 6.4           # por segundo mientras estás inclinado (al inicio 10)
const RECUPERACION_ESTAMINA: float = 24.0       # por segundo en el centro
const RECUPERACION_DEFENDIENDO: float = 12.0    # por segundo en el centro con la guardia arriba
const ESTAMINA_PARA_RECUPERARSE: float = 35.0   # al estar agotado, se vuelve a mover con esto
const COSTO_GOLPE_ESTAMINA: Dictionary = {"RECTO": 2.6, "HOOK": 3.8, "UPPERCUT": 4.5, "PATADA": 6.4}
## Margen para quien se mueve un poquito antes del aviso (segundos).
const MARGEN_ESQUIVA_ANTICIPADA: float = 0.15
const COLOR_ESTAMINA_ALTA: Color = Color(0.35, 0.85, 0.35)
const COLOR_ESTAMINA_MEDIA: Color = Color(0.98, 0.80, 0.15)
const COLOR_ESTAMINA_BAJA: Color = Color(0.95, 0.30, 0.20)
var estamina: float = ESTAMINA_MAX
var agotado: bool = false
var _reloj: float = 0.0                 # segundos desde que empezó la escena
var _t_inicio_esquiva: float = -99.0    # cuándo empezó la esquiva actual
var _t_inicio_aviso: float = 0.0        # cuándo el rival avisó su último ataque
var _barra_estamina: ProgressBar
var _estilo_estamina: StyleBoxFlat
var _lbl_estamina: Label
var _tween_agotado: Tween

# --- ESTADÍSTICAS DEL ENEMIGO ---
var nombre_enemigo: String = "Árbol de Entrenamiento"
var prefijo_anim: String = "arbol_"
var vida_max_enemigo: float = 100.0
var vida_enemigo: float = 100.0
var golpes_recibidos_seguidos: int = 0
var timer_ia_enemigo: float = 2.0
var timer_estado_enemigo: float = 0.0

# --- COOLDOWN DE LOS GOLPES DEL JUGADOR ---
## Segundos de recarga de cada golpe: no se puede volver a golpear hasta que pase.
## Mientras recarga, los puños se ven más opacos.
const COOLDOWN_GOLPE: Dictionary = {"RECTO": 0.35, "HOOK": 0.5, "UPPERCUT": 0.6, "PATADA": 0.75}
var timer_cooldown: float = 0.0

# --- BARRA DE VIDA DEL RIVAL ---
const COLOR_BARRA_NORMAL: Color = Color(0.89, 0.13, 0.11)
const COLOR_BARRA_FURIA: Color = Color(1.0, 0.55, 0.0)
var _estilo_barra: StyleBoxFlat
var _lbl_barra: Label

# --- ASPECTO DEL ENEMIGO Y DE LA BATERÍA (vida del jugador) ---
const ESCALA_SPRITE: float = 0.34
## Estilo Punch-Out: tras recibir un golpe el rival se recupera y NO contraataca de inmediato.
## Tras recibir un golpe el rival solo se retrasa un poco: su reloj de ataque sigue corriendo.
const REPOSO_TRAS_GOLPE: float = 0.4
## Golpes seguidos que aguanta antes de contraatacar (en modo furia, menos).
const GOLPES_PARA_CONTRAATAQUE: int = 3
const GOLPES_PARA_CONTRAATAQUE_FURIA: int = 2
## Solo se le puede interrumpir un ataque cada estos segundos (en furia nunca).
const ESPERA_ENTRE_INTERRUPCIONES: float = 4.0
var _preparando_ataque: bool = false
var _ataque_con_armadura: bool = false
var _tiempo_desde_interrupcion: float = 99.0
## true = la patada viene por un lado y solo se evita esquivando hacia el lado contrario.
## false = cualquier esquiva (izquierda o derecha) la evita. La defensa nunca sirve contra patadas.
const PATADA_REQUIERE_LADO: bool = true
const FRASES_GUARDIA: Array[String] = [
	"Rival: '¡No podrás cubrirte para siempre!'",
	"Rival: '¡Baja esas manos!'",
	"Rival: '¡Te voy a encontrar un hueco!'",
]

var _pos_sprite: Vector2 = Vector2.ZERO
var _tinte_enemigo: Color = Color.WHITE
var _tween_sprite: Tween
## Sube cada vez que el enemigo cambia de estado: sirve para cancelar un ataque interrumpido.
var _token_estado: int = 0
## Lado (de la pantalla) hacia el que viene la patada actual: "IZQUIERDA" o "DERECHA".
var _lado_patada: String = "IZQUIERDA"

# Imágenes de la batería: 100-80%, 80-60%, 60-40%, 40-20%, 20-0% y vacía.
var tex_bateria: Array = [
	preload("res://assets/ui/bateria_1.png"),
	preload("res://assets/ui/bateria_2.png"),
	preload("res://assets/ui/bateria_3.png"),
	preload("res://assets/ui/bateria_4.png"),
	preload("res://assets/ui/bateria_5.png"),
	preload("res://assets/ui/bateria_vacia.png"),
]
var _indice_bateria: int = -1
var _tween_bateria: Tween
var _defensa_previa: bool = false
var _esquiva_previa: String = "CENTRO"

# --- PROGRESO DEL TUTORIAL (EL ÁRBOL) ---
var paso_tutorial: int = 0
var contador_tutorial: int = 0


func _ready() -> void:
	nivel_actual = clampi(ChannelData.current_video_index, 1, 3)
	turno_espectadores.rotar(randi() % turno_espectadores.tamano()) # la ronda empieza en un usuario al azar
	configurar_parametros_channel_data()

	# El jugador NO ve sus estadísticas internas: la vida es la batería y la del rival no se muestra.
	_preparar_barra_rival()
	_preparar_barra_estamina()
	barra_vida_jugador.visible = false
	lbl_estado_jugador.visible = false
	lbl_estado_enemigo.visible = false # no se muestra el nombre del estado / animación del rival
	flash_dano.color.a = 0.0
	moscas.visible = false
	_pos_sprite = sprite_enemigo.position

	# Adapter: las dos fuentes hablan el mismo idioma.
	# Cada golpe solo cuenta si viene de la fuente que se está usando.
	camara.ataque.connect(func(tipo: String) -> void:
		if usando_camara():
			ejecutar_ataque_jugador(tipo))
	teclado.ataque.connect(func(tipo: String) -> void:
		if not usando_camara():
			ejecutar_ataque_jugador(tipo))
	camara.conectada.connect(_on_camara_conectada)
	camara.iniciar()
	if ChannelData.modo_control == "camara":
		_montar_panel_camara()
		if not CamaraEnVivo.conectada():
			agregar_mensaje_chat("Sistema", "Esperando la cámara... Abre camara/iniciar_camara.bat (mientras tanto, usa el teclado).")

	if nivel_actual == 1:
		iniciar_tutorial_arbol()
	else:
		iniciar_historia_nivel()


## true si se eligió pelear con cámara y la cámara está mandando datos.
func usando_camara() -> bool:
	return ChannelData.modo_control == "camara" and CamaraEnVivo.conectada()


## El chat se hace más bajo y debajo aparece el recuadro de la cámara.
func _montar_panel_camara() -> void:
	var overlay: Control = $UI_Combate/LiveOverlay
	overlay.offset_top = 10.0
	overlay.offset_bottom = 258.0
	var panel: PanelCamara = PanelCamara.new()
	panel.position = Vector2(overlay.offset_left, 266.0)
	overlay.get_parent().add_child(panel)
	overlay.get_parent().move_child(panel, overlay.get_index() + 1)


func _on_camara_conectada() -> void:
	if ChannelData.modo_control == "camara":
		agregar_mensaje_chat("Sistema", "¡Cámara detectada! Ya puedes pelear con tu cuerpo.")


# Observer: el chat lo dibuja live_overlay.gd, aquí solo se publica.
func agregar_mensaje_chat(usuario: String, mensaje: String) -> void:
	EventBus.chat_message.emit(usuario, mensaje)


func configurar_parametros_channel_data() -> void:
	var dificultad: Dictionary = DIFICULTADES.get(ChannelData.selected_difficulty, DIFICULTADES["Normal"])
	factor_velocidad_dificultad = dificultad["velocidad"]
	mult_views = dificultad["views"]

	match ChannelData.selected_filter:
		"Sepia Retro":
			fondo.modulate = Color(1.0, 0.88, 0.70)
		"Blanco y Negro":
			fondo.modulate = Color(0.75, 0.75, 0.75)
		"Cyber Glitch":
			fondo.modulate = Color(0.65, 0.95, 1.0)
		_:
			fondo.modulate = Color.WHITE


func _process(delta: float) -> void:
	# Si estamos en la cinemática final del Nivel 3, bloqueamos cualquier otra lógica
	if fase_actual == Fase.CINEMATICA_FINAL:
		return

	_tiempo_desde_interrupcion += delta
	_reloj += delta
	if timer_cooldown > 0.0:
		timer_cooldown -= delta
		if timer_cooldown <= 0.0:
			manos.modulate.a = 1.0 # golpe listo otra vez

	if guardia_rota:
		timer_ruptura -= delta
		if timer_ruptura <= 0.0:
			guardia_rota = false
			golpes_en_guardia = 0
			manos.guardia_rota(false)
			manos.set_desgaste(0.0)
			EventBus.evento_combate.emit("guardia_recuperada")
			actualizar_hud()

	# Las fuentes de entrada emiten `ataque` por señal (ver _ready).
	camara.actualizar(delta)
	teclado.actualizar(delta)
	_refrescar_entradas()
	if fase_actual == Fase.PELEA:
		_actualizar_estamina(delta)

	match fase_actual:
		Fase.HISTORIA_INTRO, Fase.ANIMACION_RESULTADO:
			if Input.is_action_just_pressed("ui_accept"):
				avanzar_cinematica()
		Fase.TUTORIAL_ARBOL:
			if timer_estado_enemigo > 0.0:
				timer_estado_enemigo -= delta
				if timer_estado_enemigo <= 0.0 and estado_enemigo.vuelve_a_idle:
					cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
		Fase.PELEA:
			actualizar_ia_enemigo(delta)
			timer_chat_random -= delta
			if timer_chat_random <= 0.0:
				timer_chat_random = randf_range(2.0, 3.5)
				generar_comentario_ambiental()


## Cuando cambia la defensa o la esquiva (cámara o teclado), los puños reaccionan.
func _refrescar_entradas() -> void:
	var defensa_ahora: bool = defendiendo
	if defensa_ahora != _defensa_previa:
		_defensa_previa = defensa_ahora
		manos.poner_guardia(defensa_ahora)

	var esquiva_ahora: String = esquiva_actual
	if esquiva_ahora != _esquiva_previa:
		_esquiva_previa = esquiva_ahora
		if esquiva_ahora != "CENTRO":
			_t_inicio_esquiva = _reloj # empieza una esquiva nueva
		manos.esquivar(esquiva_ahora)
		_parallax_fondo(esquiva_ahora)


func _parallax_fondo(lado: String) -> void:
	# La imagen mide 60 px más ancha que la pantalla (offset -30 / +30): su X base es -30.
	var dx: float = -30.0
	if lado == "IZQUIERDA":
		dx += 18.0
	elif lado == "DERECHA":
		dx -= 18.0
	create_tween().tween_property(imagen_fondo, "position:x", dx, 0.14).set_trans(Tween.TRANS_SINE)


## Ayuda de controles: H la abre/cierra en el tutorial, ENTER la cierra.
func _unhandled_input(event: InputEvent) -> void:
	var tecla: InputEventKey = event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.keycode == KEY_H and fase_actual == Fase.TUTORIAL_ARBOL:
		panel_controles.visible = not panel_controles.visible
	elif (tecla.keycode == KEY_ENTER or tecla.keycode == KEY_KP_ENTER) and panel_controles.visible:
		panel_controles.visible = false


# Señal `cerrado` del panel de controles (conectada en juego.tscn).
func _on_controles_cerrado() -> void:
	panel_controles.visible = false


func generar_comentario_ambiental() -> void:
	var user: String = str(turno_espectadores.siguiente())
	var mensaje: String = estrategia.comentarios_ambiente().pick_random()
	agregar_mensaje_chat(user, mensaje)


# ==========================================================
# 1. TUTORIAL CONTRA EL ÁRBOL (SOLO EN VIDEO #1)
# ==========================================================
func iniciar_tutorial_arbol() -> void:
	fase_actual = Fase.TUTORIAL_ARBOL
	pantalla_cinematica.visible = false
	aplicar_estrategia(Niveles.crear_tutorial())
	paso_tutorial = 1
	contador_tutorial = 0
	cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	agregar_mensaje_chat("Bot_Tutorial", "Bienvenido. Derriba el árbol con tu cámara para iniciar el directo.")
	lbl_dialogo_enemigo.text = "PASO 1/4: Lanza 2 GOLPES RECTOS a la cámara (o tecla P) contra el árbol."
	panel_controles.visible = true # explica los controles antes de empezar
	actualizar_hud()


func evaluar_progreso_tutorial(tipo_ataque: String) -> void:
	cambiar_estado_enemigo(EstadosEnemigo.Id.HERIDO)
	timer_estado_enemigo = 0.4

	match paso_tutorial:
		1:
			if tipo_ataque.begins_with("RECTO"):
				contador_tutorial += 1
				vida_enemigo -= 15
				agregar_mensaje_chat("Bot_Tutorial", "Recto detectado (" + str(contador_tutorial) + "/2)")
				lbl_dialogo_enemigo.text = "¡Buen Recto! (" + str(contador_tutorial) + "/2)"
				if contador_tutorial >= 2:
					paso_tutorial = 2
					contador_tutorial = 0
					lbl_dialogo_enemigo.text = "PASO 2/4: Lanza 2 HOOKS o UPPERCUTS (ganchos laterales o ascendentes / teclas L, Ñ u O)."
		2:
			if tipo_ataque.begins_with("HOOK") or tipo_ataque.begins_with("UPPERCUT"):
				contador_tutorial += 1
				vida_enemigo -= 15
				agregar_mensaje_chat("Bot_Tutorial", "Gancho detectado (" + str(contador_tutorial) + "/2)")
				lbl_dialogo_enemigo.text = "¡Gran gancho! (" + str(contador_tutorial) + "/2)"
				if contador_tutorial >= 2:
					paso_tutorial = 3
					contador_tutorial = 0
					lbl_dialogo_enemigo.text = "PASO 3/4: Levanta la rodilla o el pie para dar 1 PATADA al árbol (o Espacio)."
		3:
			if tipo_ataque.begins_with("PATADA"):
				vida_enemigo -= 20
				paso_tutorial = 4
				agregar_mensaje_chat("Bot_Tutorial", "¡Buena patada! Ahora prueba defensa + ataque.")
				lbl_dialogo_enemigo.text = "PASO 4/4: Cubre tu nariz ARRIBA DE LA BARBILLA con una mano (o Shift) y golpea con la otra a la vez."
		4:
			if defendiendo:
				paso_tutorial = 5 # evita que golpes extra repitan la historia mientras esperamos
				vida_enemigo = 0
				cambiar_estado_enemigo(EstadosEnemigo.Id.EN_EL_PISO)
				agregar_mensaje_chat("Bot_Tutorial", "¡Árbol talado! Entrando en vivo...")
				lbl_dialogo_enemigo.text = "¡ÁRBOL EN EL PISO! Calentamiento listo. Iniciando historia del Nivel 1..."
				actualizar_hud()
				await get_tree().create_timer(2.5).timeout
				iniciar_historia_nivel()
			else:
				lbl_dialogo_enemigo.text = "¡Estabas descubierto! Mantén una mano arriba de la barbilla tapando la nariz MIENTRAS golpeas."

	actualizar_hud()


# ==========================================================
# 2. HISTORIA Y PELEA
# ==========================================================
func iniciar_historia_nivel() -> void:
	fase_actual = Fase.HISTORIA_INTRO
	pantalla_cinematica.visible = true

	var nivel: Niveles.Estrategia = Niveles.crear(nivel_actual)
	_poner_fondo(nivel.fondo_textura)
	pantalla_cinematica.color = nivel.color_historia
	texto_cinematica.text = nivel.texto_historia(ChannelData.video_title)

	await get_tree().create_timer(4.0).timeout
	if fase_actual == Fase.HISTORIA_INTRO:
		iniciar_pelea_nivel()


func avanzar_cinematica() -> void:
	if fase_actual == Fase.HISTORIA_INTRO:
		iniciar_pelea_nivel()
	elif fase_actual == Fase.ANIMACION_RESULTADO:
		volver_a_administrar_canal()


# Señal gui_input de PantallaCinematica (conectada en juego.tscn): clic izquierdo = ENTER.
func _on_pantalla_cinematica_gui_input(event: InputEvent) -> void:
	var clic: InputEventMouseButton = event as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		avanzar_cinematica()


func iniciar_pelea_nivel() -> void:
	fase_actual = Fase.PELEA
	pantalla_cinematica.visible = false
	vida_jugador = vida_max_jugador
	guardia_rota = false
	golpes_en_guardia = 0
	golpes_jefe_conectados = 0
	manos.guardia_rota(false)
	manos.set_desgaste(0.0)
	_reiniciar_estamina()

	aplicar_estrategia(Niveles.crear(nivel_actual))
	lbl_dialogo_enemigo.text = estrategia.dialogo_inicio
	# El nivel 3 usa "pelea_jefe" si existe; si no, la misma música de pelea.
	var es_jefe: bool = nivel_actual == 3 and Audio.existe_musica("pelea_jefe")
	Audio.musica("pelea_jefe" if es_jefe else "pelea")
	Audio.sfx("campana", false)

	agregar_mensaje_chat("NeTube_Bot", "¡Transmisión en directo iniciada contra " + nombre_enemigo + "!")
	agregar_mensaje_chat("NeTube_Bot", "Esquivar cansa: muévete JUSTO cuando el rival avise y vigila tu estamina.")
	cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	actualizar_hud()


## Carga en el enemigo los datos de la estrategia (nombre, animaciones y vida).
func aplicar_estrategia(nueva: Niveles.Estrategia) -> void:
	estrategia = nueva
	nombre_enemigo = estrategia.nombre_enemigo
	prefijo_anim = estrategia.prefijo_anim
	vida_max_enemigo = estrategia.vida_max
	vida_enemigo = estrategia.vida_max
	_tinte_enemigo = estrategia.tinte
	sprite_enemigo.modulate = _tinte_enemigo
	_actualizar_barra_rival()
	_poner_fondo(estrategia.fondo_textura)


## Imagen de fondo de la pelea (el filtro de color del canal se aplica encima).
func _poner_fondo(ruta: String) -> void:
	var textura: Texture2D = load(ruta) as Texture2D
	if textura == null:
		return
	imagen_fondo.texture = textura
	# forest.png es una imagen pequeña de puntos: ampliada sin suavizar conserva su estilo.
	if ruta == "res://forest.png":
		imagen_fondo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		imagen_fondo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func ejecutar_ataque_jugador(tipo_ataque: String) -> void:
	if panel_controles.visible:
		return

	# Los puños se mueven siempre que hay combate (golpees o no al rival).
	if fase_actual == Fase.TUTORIAL_ARBOL or fase_actual == Fase.PELEA:
		if timer_cooldown > 0.0:
			return # el golpe anterior todavía se está recargando
		if fase_actual == Fase.PELEA:
			var costo: float = _costo_golpe(tipo_ataque)
			if agotado or estamina < costo:
				_avisar_sin_estamina()
				return # sin aire no hay golpe
			_gastar_estamina(costo)
		timer_cooldown = _cooldown_de(tipo_ataque)
		manos.modulate.a = 0.55
		manos.golpear(tipo_ataque)
		Audio.sfx("patada_aire" if tipo_ataque.begins_with("PATADA") else "puno_aire")

	if fase_actual == Fase.TUTORIAL_ARBOL:
		evaluar_progreso_tutorial(tipo_ataque)
		return

	if fase_actual != Fase.PELEA or not estado_enemigo.acepta_ataques:
		return

	views_en_vivo += 45 * mult_views

	if estado_enemigo.bloquea_ataques:
		lbl_dialogo_enemigo.text = "¡El rival se cubre!"
		EventBus.evento_combate.emit("bloqueo_rival")
		_efecto_estado(estado_enemigo.id)
		actualizar_hud()
		return

	var dano: float = 8.0
	if tipo_ataque.begins_with("HOOK"):
		dano = 12.0
	elif tipo_ataque.begins_with("UPPERCUT"):
		dano = 16.0
	elif tipo_ataque.begins_with("PATADA"):
		dano = 14.0

	# Burla / Noqueado: el enemigo está vulnerable (más daño y más views).
	dano *= estado_enemigo.multiplicador_dano
	views_en_vivo += estado_enemigo.bonus_views * mult_views

	if estrategia.es_jefe_invencible():
		# En Nivel 3 es 100% inmortal
		vida_enemigo = vida_max_enemigo
		# Si está preparando un golpe NO se interrumpe: el jefe siempre conecta.
		if estado_enemigo.puede_actuar:
			cambiar_estado_enemigo(EstadosEnemigo.Id.RISA)
			timer_estado_enemigo = 0.5
		lbl_dialogo_enemigo.text = "Jefe: '¿Eso es todo? Daño: 0. Mi vida es INFINITA.'"
		EventBus.evento_combate.emit("golpe_conecta")
	else:
		vida_enemigo = maxf(0.0, vida_enemigo - dano)
		_reaccion_al_golpe()

		# Con poca vida el rival entra en MODO FURIA (una sola vez por pelea).
		if vida_enemigo > 0.0 and estrategia.puede_enfurecerse() and not estrategia.en_furia \
				and vida_enemigo <= vida_max_enemigo * estrategia.UMBRAL_FURIA:
			_activar_furia()

		if vida_enemigo <= 0.0:
			cambiar_estado_enemigo(EstadosEnemigo.Id.EN_EL_PISO)
			EventBus.evento_combate.emit("ko_enemigo")
			finalizar_combate(true)

	actualizar_hud()


func actualizar_ia_enemigo(delta: float) -> void:
	# El jefe del Nivel 3 suelta frases; los demás niveles devuelven "".
	var frase: String = estrategia.pensar(delta)
	if frase != "":
		lbl_dialogo_enemigo.text = frase

	if timer_estado_enemigo > 0.0:
		timer_estado_enemigo -= delta
		if timer_estado_enemigo <= 0.0 and estado_enemigo.vuelve_a_idle:
			cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)

	timer_ia_enemigo -= delta
	if timer_ia_enemigo <= 0.0 and estado_enemigo.puede_actuar:
		timer_ia_enemigo = estrategia.intervalo_ia(factor_velocidad_dificultad)
		if estrategia.en_furia:
			timer_ia_enemigo *= estrategia.MULT_VELOCIDAD_FURIA
		ejecutar_accion_enemigo()


func ejecutar_accion_enemigo() -> void:
	# Cada nivel decide qué hace el enemigo (el Nivel 3 NUNCA bloquea ni se burla: solo ataca).
	var accion: Dictionary = estrategia.elegir_accion_furia() if estrategia.en_furia \
			else estrategia.elegir_accion(randi() % 100)
	var estado_id: int = accion["estado"]
	var tiempo: float = accion["tiempo"]
	var ataque: String = accion["ataque"]

	if accion["reiniciar_combo"]:
		golpes_recibidos_seguidos = 0
	if accion["dialogo"] != "":
		lbl_dialogo_enemigo.text = accion["dialogo"]

	if ataque == "":
		# Bloqueo o burla: no hace daño, solo cambia de estado un rato.
		cambiar_estado_enemigo(estado_id)
		timer_estado_enemigo = tiempo
		if estado_id == EstadosEnemigo.Id.BURLA:
			EventBus.evento_combate.emit("burla")
		return

	var peso: int = accion["peso"]
	await _atacar(estado_id, peso, tiempo)


## Un ataque del enemigo en tres tiempos:
##   1) PREPARA  (levanta el guante o la pierna): es el aviso para defenderte o esquivar
##   2) RESUELVE (mira si defiendes, esquivas o te pega)
##   3) MUESTRA el resultado: golpe que impacta, golpe bloqueado o golpe que falla
## Si lo golpeas durante el paso 1 el ataque se cancela.
func _atacar(estado_id: int, peso: int, preparacion: float, con_armadura: bool = false) -> void:
	var base: String = EstadosEnemigo.crear(estado_id).sufijo_anim # "golpe", "golpe_fuerte" o "patada"
	var es_patada: bool = estado_id == EstadosEnemigo.Id.PATADA
	if es_patada:
		_lado_patada = ["IZQUIERDA", "DERECHA"].pick_random()
	cambiar_estado_enemigo(estado_id, base + "_preparar")
	Audio.sfx("aviso_ataque", false)
	_t_inicio_aviso = _reloj # desde aquí cuenta la ventana para esquivar
	var token: int = _token_estado
	timer_estado_enemigo = preparacion + 1.0 # no vuelve a IDLE mientras prepara
	_preparando_ataque = true
	_ataque_con_armadura = con_armadura
	await get_tree().create_timer(preparacion).timeout
	if token == _token_estado:
		_preparando_ataque = false
		_ataque_con_armadura = false

	if fase_actual != Fase.PELEA or token != _token_estado:
		return # interrumpido (le pegaste) o terminó la pelea

	var resultado: String = aplicar_ataque_al_jugador(peso, es_patada)
	if fase_actual != Fase.PELEA or token != _token_estado:
		return # el propio golpe cambió el estado (guardia rota, K.O...)

	match resultado:
		"bloqueo":
			reproducir_animacion(base + "_bloqueo")
		"esquiva":
			reproducir_animacion(base + "_fallo")
		_:
			reproducir_animacion(base)
	timer_estado_enemigo = 0.6


## Devuelve "impacto", "bloqueo" o "esquiva" (para que el enemigo muestre la animación correcta).
func aplicar_ataque_al_jugador(peso_escudo: int, es_patada: bool = false) -> String:
	# En el Nivel 3 debes perder SÍ O SÍ: los 10 ataques atraviesan cualquier esquiva o defensa
	if estrategia.es_jefe_invencible():
		golpes_jefe_conectados += 1
		vida_jugador = maxf(0.0, vida_jugador - 10.0) # 10 ataques exactos = 0 de vida
		views_en_vivo += 300 * mult_views
		_efecto_dano()
		EventBus.evento_combate.emit("rival_golpea")
		if defendiendo:
			lbl_dialogo_enemigo.text = "¡El Jefe atraviesa tu guardia! Ataque " + str(golpes_jefe_conectados) + "/10"
		else:
			lbl_dialogo_enemigo.text = "¡Impacto directo del Jefe! Ataque " + str(golpes_jefe_conectados) + "/10"
		actualizar_hud()

		if vida_jugador <= 0.0 or golpes_jefe_conectados >= 10:
			cambiar_estado_enemigo(EstadosEnemigo.Id.RISA)
			ejecutar_cinematica_final_nivel_3()
		return "impacto"

	# Lógica normal para Nivel 1 y Nivel 2
	# La patada viene por un lado: hay que esquivar hacia el contrario (o hacia cualquiera si no se exige lado).
	var lado_seguro: String = "DERECHA" if _lado_patada == "IZQUIERDA" else "IZQUIERDA"
	var esquivo_bien: bool = esquiva_actual != "CENTRO"
	if es_patada and PATADA_REQUIERE_LADO:
		esquivo_bien = esquiva_actual == lado_seguro
	# Solo vale si te moviste después del aviso: quedarse inclinado de antemano no sirve.
	var anticipada: bool = esquivo_bien and not esquiva_a_tiempo()
	if anticipada:
		esquivo_bien = false

	if esquivo_bien:
		_gastar_estamina(COSTO_ESQUIVA)
		views_en_vivo += 120 * mult_views
		lbl_dialogo_enemigo.text = "Rival: '¡Quédate quieto!'"
		EventBus.evento_combate.emit("esquivaste")
		actualizar_hud()
		return "esquiva"

	if defendiendo and not es_patada: # la defensa no sirve contra patadas
		golpes_en_guardia += peso_escudo
		views_en_vivo += 35 * mult_views
		lbl_dialogo_enemigo.text = FRASES_GUARDIA.pick_random()
		manos.bloquear_impacto()
		manos.set_desgaste(float(golpes_en_guardia) / float(max_golpes_guardia))
		EventBus.evento_combate.emit("bloqueaste")
		if golpes_en_guardia >= max_golpes_guardia:
			guardia_rota = true
			timer_ruptura = tiempo_delay_guardia
			manos.guardia_rota(true)
			cambiar_estado_enemigo(EstadosEnemigo.Id.RISA)
			timer_estado_enemigo = 1.2
			lbl_dialogo_enemigo.text = "Rival: '¡Tu guardia se rompió!'"
			EventBus.evento_combate.emit("guardia_rota")
		actualizar_hud()
		return "bloqueo"

	var dano_recibido: float = estrategia.dano_a_jugador(peso_escudo)
	if estrategia.en_furia:
		dano_recibido *= estrategia.MULT_DANO_FURIA
	vida_jugador = maxf(0.0, vida_jugador - dano_recibido)
	if anticipada:
		lbl_dialogo_enemigo.text = "¡Te moviste antes de tiempo! Esquiva JUSTO cuando el rival avise."
		EventBus.evento_combate.emit("esquiva_temprana")
	elif agotado:
		lbl_dialogo_enemigo.text = "¡Estás agotado! Sin estamina no puedes esquivar."
	elif es_patada:
		lbl_dialogo_enemigo.text = "¡Patada directa! Contra las patadas hay que esquivar, no defender."
	_efecto_dano()
	EventBus.evento_combate.emit("rival_golpea")
	actualizar_hud()

	if vida_jugador <= 0.0:
		cambiar_estado_enemigo(EstadosEnemigo.Id.RISA)
		finalizar_combate(false)
	return "impacto"


## Te pegaron: sacudida de puños, destello rojo y la batería "late".
func _efecto_dano() -> void:
	manos.recibir_golpe()
	flash_dano.color.a = 0.4
	create_tween().tween_property(flash_dano, "color:a", 0.0, 0.35)
	bateria.pivot_offset = bateria.size / 2.0
	bateria.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(bateria, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


## Patrón State: crea el objeto del nuevo estado y aplica su aspecto.
## `anim_forzada` permite mostrar otra animación (por ejemplo "golpe_preparar").
func cambiar_estado_enemigo(nuevo_id: int, anim_forzada: String = "") -> void:
	estado_enemigo = EstadosEnemigo.crear(nuevo_id)
	_token_estado += 1
	_preparando_ataque = false
	_ataque_con_armadura = false

	lbl_estado_enemigo.text = nombre_enemigo + "\n" + estado_enemigo.descripcion
	lbl_estado_enemigo.modulate = estado_enemigo.color

	reproducir_animacion(anim_forzada if anim_forzada != "" else estado_enemigo.sufijo_anim)
	# La patada se ve hacia el lado por el que viene (el sprite se voltea).
	sprite_enemigo.flip_h = nuevo_id == EstadosEnemigo.Id.PATADA and _lado_patada == "DERECHA"
	_efecto_estado(nuevo_id)

	# En el piso aparecen las moscas sobre el cuerpo.
	moscas.visible = nuevo_id == EstadosEnemigo.Id.EN_EL_PISO and prefijo_anim != "arbol_"
	if moscas.visible and moscas.sprite_frames != null and moscas.sprite_frames.has_animation("moscas"):
		moscas.play("moscas")


## Busca "<prefijo_nivel>_<sufijo>" (n1_golpe...) y si no existe usa "<sufijo>" (golpe).
func reproducir_animacion(sufijo: String) -> void:
	if sprite_enemigo.sprite_frames == null:
		return
	var completa: String = prefijo_anim + sufijo
	if sprite_enemigo.sprite_frames.has_animation(completa):
		sprite_enemigo.play(completa)
	elif sprite_enemigo.sprite_frames.has_animation(sufijo):
		sprite_enemigo.play(sufijo)


## Movimientos extra del sprite según el estado (el sprite NO se tiñe: así se ve tal como lo dibujaste).
func _efecto_estado(estado_id: int) -> void:
	if _tween_sprite != null and _tween_sprite.is_valid():
		_tween_sprite.kill()
	sprite_enemigo.position = _pos_sprite
	sprite_enemigo.rotation = 0.0
	sprite_enemigo.scale = Vector2.ONE * ESCALA_SPRITE
	sprite_enemigo.modulate = _tinte_enemigo

	match estado_id:
		EstadosEnemigo.Id.HERIDO:
			# Destello rojo y empujón hacia atrás.
			sprite_enemigo.modulate = Color(1.0, 0.45, 0.45)
			sprite_enemigo.position = _pos_sprite + Vector2(randf_range(-16.0, 16.0), -10.0)
			_tween_sprite = create_tween().set_parallel(true)
			_tween_sprite.tween_property(sprite_enemigo, "modulate", _tinte_enemigo, 0.3)
			_tween_sprite.tween_property(sprite_enemigo, "position", _pos_sprite, 0.22)
		EstadosEnemigo.Id.EN_EL_PISO:
			if prefijo_anim == "arbol_":
				# El árbol del tutorial se cae de lado ("¡Árbol talado!").
				_tween_sprite = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				_tween_sprite.tween_property(sprite_enemigo, "rotation", deg_to_rad(84.0), 0.7)
				_tween_sprite.tween_property(sprite_enemigo, "position", _pos_sprite + Vector2(130.0, 215.0), 0.7)
		EstadosEnemigo.Id.NOQUEADO:
			# Mareado: se balancea de lado a lado.
			_tween_sprite = create_tween().set_loops()
			_tween_sprite.tween_property(sprite_enemigo, "rotation", 0.09, 0.35).set_trans(Tween.TRANS_SINE)
			_tween_sprite.tween_property(sprite_enemigo, "rotation", -0.09, 0.35).set_trans(Tween.TRANS_SINE)
		EstadosEnemigo.Id.RISA:
			# Se sacude riendo.
			_tween_sprite = create_tween().set_loops()
			_tween_sprite.tween_property(sprite_enemigo, "position:y", _pos_sprite.y - 9.0, 0.1)
			_tween_sprite.tween_property(sprite_enemigo, "position:y", _pos_sprite.y, 0.1)
		EstadosEnemigo.Id.BURLA:
			_tween_sprite = create_tween().set_loops()
			_tween_sprite.tween_property(sprite_enemigo, "rotation", 0.06, 0.45).set_trans(Tween.TRANS_SINE)
			_tween_sprite.tween_property(sprite_enemigo, "rotation", -0.06, 0.45).set_trans(Tween.TRANS_SINE)
		EstadosEnemigo.Id.BLOQUEO:
			# Se encoge un poco al cubrirse y recibir el golpe.
			sprite_enemigo.scale = Vector2(1.05, 0.95) * ESCALA_SPRITE
			_tween_sprite = create_tween()
			_tween_sprite.tween_property(sprite_enemigo, "scale", Vector2.ONE * ESCALA_SPRITE, 0.15)
		EstadosEnemigo.Id.PATADA:
			# Se desplaza hacia el lado de la patada mientras la prepara.
			var dir: float = -1.0 if _lado_patada == "IZQUIERDA" else 1.0
			_tween_sprite = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
			_tween_sprite.tween_property(sprite_enemigo, "scale", Vector2.ONE * ESCALA_SPRITE * 1.07, 0.45)
			_tween_sprite.tween_property(sprite_enemigo, "position:x", _pos_sprite.x + 45.0 * dir, 0.45)
		EstadosEnemigo.Id.GOLPE, EstadosEnemigo.Id.GOLPE_FUERTE:
			# Al preparar el ataque se acerca (más grande): así se nota que viene un golpe.
			_tween_sprite = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
			_tween_sprite.tween_property(sprite_enemigo, "scale", Vector2.ONE * ESCALA_SPRITE * 1.07, 0.45)
			_tween_sprite.tween_property(sprite_enemigo, "position:y", _pos_sprite.y + 10.0, 0.45)


# ----------------------------------------------------------- BATERÍA ----

## La vida del jugador es la batería: 5 niveles de carga y una imagen vacía.
func _actualizar_bateria() -> void:
	var porcentaje: float = vida_jugador / vida_max_jugador * 100.0
	var indice: int = 0
	if porcentaje <= 0.0:
		indice = 5
	elif porcentaje <= 20.0:
		indice = 4
	elif porcentaje <= 40.0:
		indice = 3
	elif porcentaje <= 60.0:
		indice = 2
	elif porcentaje <= 80.0:
		indice = 1
	if indice == _indice_bateria:
		return
	_indice_bateria = indice

	var textura: Texture2D = tex_bateria[indice]
	bateria.texture = textura

	if _tween_bateria != null and _tween_bateria.is_valid():
		_tween_bateria.kill()
	bateria.modulate = Color.WHITE
	if indice == 4:
		# Poca carga: parpadea como aviso.
		_tween_bateria = create_tween().set_loops()
		_tween_bateria.tween_property(bateria, "modulate:a", 0.35, 0.35)
		_tween_bateria.tween_property(bateria, "modulate:a", 1.0, 0.35)


# ==========================================================
# FIN DE PELEA (NIVELES 1 Y 2)
# ==========================================================
func finalizar_combate(ganaste: bool) -> void:
	if ganaste:
		Audio.bajar_musica() # la música sigue, pero bajita, para oír el K.O.
	else:
		Audio.musica("")
	if ganaste:
		# El rival queda en el piso mientras suenan los efectos del K.O.
		fase_actual = Fase.KO_RIVAL
		await _secuencia_ko()

	fase_actual = Fase.ANIMACION_RESULTADO
	pantalla_cinematica.visible = true
	Audio.sfx("victoria" if ganaste else "derrota", false)
	if ganaste:
		views_en_vivo += 500 * mult_views
		var nuevos_subs: int = int(views_en_vivo * 0.25)
		guardar_progreso_en_channel_data(views_en_vivo, nuevos_subs, true)

		pantalla_cinematica.color = Color(0.05, 0.35, 0.15, 0.96)
		texto_cinematica.text = "¡VICTORIA EN EL VIDEO #" + str(nivel_actual) + "!\n\nDejaste a " + nombre_enemigo + " EN EL PISO.\n+" + str(views_en_vivo) + " Visitas | +" + str(nuevos_subs) + " Suscriptores\n\n[Regresando al panel del canal para el Video #" + str(ChannelData.current_video_index) + "...]"
	else:
		EventBus.evento_combate.emit("derrota")
		var views_consuelo: int = max(50, int(views_en_vivo * 0.3))
		guardar_progreso_en_channel_data(views_consuelo, 5, false)

		pantalla_cinematica.color = Color(0.35, 0.05, 0.05, 0.96)
		texto_cinematica.text = "CAÍSTE EN LA LONA (VIDEO #" + str(nivel_actual) + ")\n\nEl rival se ríe en cámara. Ganas +" + str(views_consuelo) + " visitas.\nRegresando al canal para intentarlo de nuevo..."

	# Récord del nivel, leído y guardado en archivo (TAD HistorialPeleas).
	var record_anterior: int = historial.mejor_views(nivel_actual)
	historial.registrar(nivel_actual, ganaste, views_en_vivo)
	if views_en_vivo > record_anterior:
		texto_cinematica.text += "\n\n¡NUEVO RÉCORD DEL NIVEL: " + str(views_en_vivo) + " views!"
	else:
		texto_cinematica.text += "\n\nRécord del nivel: " + str(record_anterior) + " views"

	await get_tree().create_timer(4.5).timeout
	if fase_actual == Fase.ANIMACION_RESULTADO:
		volver_a_administrar_canal()


# ==========================================================
# CINEMÁTICA FINAL DE LA ENSEÑANZA Y CIERRE DEL JUEGO (NIVEL 3)
# ==========================================================
func ejecutar_cinematica_final_nivel_3() -> void:
	fase_actual = Fase.CINEMATICA_FINAL
	Audio.musica("final")
	camara.cerrar() # Cerramos la conexión con la cámara

	pantalla_cinematica.visible = true
	pantalla_cinematica.color = Color(0.5, 0.0, 0.0, 0.0)
	texto_cinematica.modulate.a = 0.0

	# ACTO 1: Caída en el golpe #10 y corte de transmisión
	texto_cinematica.text = TEXTO_CAIDA
	var tween1: Tween = create_tween()
	tween1.tween_property(pantalla_cinematica, "color", Color(0.15, 0.02, 0.02, 1.0), 1.2)
	tween1.parallel().tween_property(texto_cinematica, "modulate:a", 1.0, 1.0)
	await tween1.finished
	await get_tree().create_timer(3.2).timeout

	# ACTO 2: despiertas en el hospital y la ninfa da la reflexión final.
	await get_tree().create_timer(0.5).timeout
	SceneRouter.go(SceneRouter.FINAL_HOSPITAL)


func guardar_progreso_en_channel_data(views_ganadas: int, subs_ganados: int, avanzar_nivel: bool) -> void:
	ChannelData.total_views += views_ganadas
	ChannelData.total_subscribers += subs_ganados
	if avanzar_nivel and ChannelData.current_video_index < 3:
		ChannelData.current_video_index += 1


func volver_a_administrar_canal() -> void:
	camara.cerrar()
	SceneRouter.go(SceneRouter.ADMIN_CANAL)


func actualizar_hud() -> void:
	# El jugador solo ve el título del directo y su batería; lo demás es interno.
	lbl_titulo_nivel.text = "EN VIVO: " + ChannelData.video_title + " | Views: " + str(views_en_vivo)
	barra_vida_enemigo.max_value = vida_max_enemigo
	barra_vida_enemigo.value = vida_enemigo
	barra_vida_jugador.max_value = vida_max_jugador
	barra_vida_jugador.value = vida_jugador
	_actualizar_bateria()


# ==========================================================
# COOLDOWN, BARRA DE VIDA DEL RIVAL Y MODO FURIA
# ==========================================================
func _cooldown_de(tipo_ataque: String) -> float:
	for golpe in COOLDOWN_GOLPE:
		if tipo_ataque.begins_with(golpe):
			return COOLDOWN_GOLPE[golpe]
	return 0.4


## Muestra la barra de vida del rival con el estilo del juego y su nombre encima.
func _preparar_barra_rival() -> void:
	barra_vida_enemigo.visible = true
	barra_vida_enemigo.show_percentage = false
	barra_vida_enemigo.pivot_offset = barra_vida_enemigo.size / 2.0
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = Color(0.08, 0.05, 0.05, 0.9)
	fondo_barra.border_color = Color.WHITE
	fondo_barra.set_border_width_all(3)
	fondo_barra.set_corner_radius_all(10)
	barra_vida_enemigo.add_theme_stylebox_override("background", fondo_barra)
	_estilo_barra = StyleBoxFlat.new()
	_estilo_barra.bg_color = COLOR_BARRA_NORMAL
	_estilo_barra.set_corner_radius_all(8)
	_estilo_barra.set_expand_margin_all(-3)
	barra_vida_enemigo.add_theme_stylebox_override("fill", _estilo_barra)
	_lbl_barra = Label.new()
	_lbl_barra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl_barra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_barra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_barra.add_theme_font_size_override("font_size", 17)
	_lbl_barra.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_barra.add_theme_constant_override("outline_size", 5)
	_lbl_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_vida_enemigo.add_child(_lbl_barra)
	_actualizar_barra_rival()


func _actualizar_barra_rival() -> void:
	if _estilo_barra == null:
		return
	_estilo_barra.bg_color = COLOR_BARRA_FURIA if estrategia.en_furia else COLOR_BARRA_NORMAL
	if estrategia.es_jefe_invencible():
		_lbl_barra.text = nombre_enemigo + "  ·  ∞ VIDA INFINITA"
	elif estrategia.en_furia:
		_lbl_barra.text = "MODO FURIA  ·  " + nombre_enemigo
	else:
		_lbl_barra.text = nombre_enemigo


## El rival se enoja: se tiñe de rojo, la barra cambia de color y el chat reacciona.
func _activar_furia() -> void:
	estrategia.en_furia = true
	# El sprite es celeste: se sobreexpone el rojo para que se vea rojizo y no gris.
	_tinte_enemigo = Color(2.4, 0.55, 0.45)
	sprite_enemigo.modulate = _tinte_enemigo
	_actualizar_barra_rival()
	lbl_dialogo_enemigo.text = "¡MODO FURIA! El rival ataca más rápido y pega más fuerte"
	agregar_mensaje_chat("NeTube_Bot", "¡El rival entró en MODO FURIA!")
	EventBus.evento_combate.emit("furia")
	timer_ia_enemigo = minf(timer_ia_enemigo, 0.8)
	flash_dano.color.a = 0.3
	create_tween().tween_property(flash_dano, "color:a", 0.0, 0.5)
	var latido: Tween = create_tween().set_loops(3)
	latido.tween_property(barra_vida_enemigo, "scale", Vector2(1.03, 1.15), 0.12)
	latido.tween_property(barra_vida_enemigo, "scale", Vector2.ONE, 0.12)


## K.O. del rival: primero el sonido de lego rompiéndose, después el desmayo
## de caricatura y una pausa corta antes de mostrar las estadísticas.
func _secuencia_ko() -> void:
	lbl_dialogo_enemigo.text = "¡K.O.! " + nombre_enemigo + " cae a la lona"
	Audio.sfx("ko_romper", false)
	await get_tree().create_timer(maxf(Audio.duracion("ko_romper"), 0.8)).timeout
	Audio.sfx("ko_desmayo", false)
	await get_tree().create_timer(maxf(Audio.duracion("ko_desmayo"), 1.5)).timeout
	await get_tree().create_timer(PAUSA_ANTES_DE_ESTADISTICAS).timeout


# ==========================================================
# REACCIÓN DEL RIVAL A LOS GOLPES: aguante, interrupción y contraataque
# ==========================================================
## Decide cómo responde el rival a un golpe que le hizo daño:
##   - Burlándose o mareado: está vulnerable, solo recibe el golpe.
##   - Preparando un ataque: lo aguanta y sigue atacando, salvo que el jugador
##     lo interrumpa en el momento justo (una vez cada pocos segundos).
##   - Tras varios golpes seguidos: contraataca con un ataque imparable.
func _reaccion_al_golpe() -> void:
	var id: int = estado_enemigo.id
	if id == EstadosEnemigo.Id.BURLA or id == EstadosEnemigo.Id.NOQUEADO:
		_destello_golpe()
		EventBus.evento_combate.emit("golpe_conecta")
		return

	golpes_recibidos_seguidos += 1

	if _preparando_ataque:
		var puede_interrumpirse: bool = not _ataque_con_armadura and not estrategia.en_furia \
				and _tiempo_desde_interrupcion >= ESPERA_ENTRE_INTERRUPCIONES
		if puede_interrumpirse:
			# Golpe en el momento justo: corta el ataque y queda mareado.
			_tiempo_desde_interrupcion = 0.0
			golpes_recibidos_seguidos = 0
			cambiar_estado_enemigo(EstadosEnemigo.Id.NOQUEADO)
			timer_estado_enemigo = 1.2
			lbl_dialogo_enemigo.text = "¡Le cortaste el ataque! Queda mareado: ¡remátalo!"
			EventBus.evento_combate.emit("noqueado")
		else:
			# Aguanta el golpe y sigue con su ataque.
			_destello_golpe()
			lbl_dialogo_enemigo.text = "¡Aguanta el golpe y sigue atacando! Defiéndete o esquiva."
			EventBus.evento_combate.emit("golpe_conecta")
		return

	var limite: int = GOLPES_PARA_CONTRAATAQUE_FURIA if estrategia.en_furia else GOLPES_PARA_CONTRAATAQUE
	if golpes_recibidos_seguidos >= limite and vida_enemigo > 0.0:
		golpes_recibidos_seguidos = 0
		_contraatacar()
		return

	cambiar_estado_enemigo(EstadosEnemigo.Id.HERIDO)
	timer_estado_enemigo = 0.3
	timer_ia_enemigo = maxf(timer_ia_enemigo, REPOSO_TRAS_GOLPE)
	EventBus.evento_combate.emit("golpe_conecta")


## Ataque rápido e imparable después de recibir varios golpes seguidos.
func _contraatacar() -> void:
	lbl_dialogo_enemigo.text = "¡CONTRAATAQUE! ¡Cúbrete o esquiva!"
	EventBus.evento_combate.emit("contraataque")
	var fuerte: bool = randi() % 2 == 0
	var estado_id: int = EstadosEnemigo.Id.GOLPE_FUERTE if fuerte else EstadosEnemigo.Id.GOLPE
	await _atacar(estado_id, 2 if fuerte else 1, 0.45, true)


## Destello rojo del rival cuando recibe un golpe sin cambiar de estado.
func _destello_golpe() -> void:
	sprite_enemigo.modulate = Color(2.4, 0.4, 0.4)
	create_tween().tween_property(sprite_enemigo, "modulate", _tinte_enemigo, 0.2)


# ==========================================================
# ESTAMINA
# ==========================================================
## true si la esquiva actual empezó después del aviso del rival (con un pequeño margen).
func esquiva_a_tiempo() -> bool:
	return _t_inicio_esquiva >= _t_inicio_aviso - MARGEN_ESQUIVA_ANTICIPADA


func _costo_golpe(tipo_ataque: String) -> float:
	for golpe in COSTO_GOLPE_ESTAMINA:
		if tipo_ataque.begins_with(golpe):
			return COSTO_GOLPE_ESTAMINA[golpe]
	return 5.0


## Cada cuadro: inclinado gasta, en el centro recupera (menos si te cubres).
func _actualizar_estamina(delta: float) -> void:
	if esquiva_actual != "CENTRO":
		_gastar_estamina(DESGASTE_INCLINADO * delta)
	else:
		var ritmo: float = RECUPERACION_DEFENDIENDO if defendiendo else RECUPERACION_ESTAMINA
		estamina = minf(ESTAMINA_MAX, estamina + ritmo * delta)
		if agotado and estamina >= ESTAMINA_PARA_RECUPERARSE:
			_recuperarse()
	_actualizar_barra_estamina()


func _gastar_estamina(cantidad: float) -> void:
	estamina = maxf(0.0, estamina - cantidad)
	if estamina <= 0.0 and not agotado:
		_agotarse()
	_actualizar_barra_estamina()


## Te quedaste sin aire: el cuerpo vuelve al centro y la barra parpadea.
func _agotarse() -> void:
	agotado = true
	lbl_dialogo_enemigo.text = "¡AGOTADO! Quédate quieto un momento para recuperar el aire."
	EventBus.evento_combate.emit("agotado")
	if _tween_agotado != null and _tween_agotado.is_valid():
		_tween_agotado.kill()
	_tween_agotado = create_tween().set_loops()
	_tween_agotado.tween_property(_barra_estamina, "modulate:a", 0.35, 0.25)
	_tween_agotado.tween_property(_barra_estamina, "modulate:a", 1.0, 0.25)


func _recuperarse() -> void:
	agotado = false
	if _tween_agotado != null and _tween_agotado.is_valid():
		_tween_agotado.kill()
	_barra_estamina.modulate.a = 1.0
	_t_inicio_esquiva = -99.0 # si seguías inclinado, debes volver a moverte para esquivar
	EventBus.evento_combate.emit("estamina_recuperada")


func _reiniciar_estamina() -> void:
	estamina = ESTAMINA_MAX
	if agotado:
		_recuperarse()
	_t_inicio_esquiva = -99.0
	_barra_estamina.visible = true
	_actualizar_barra_estamina()


func _avisar_sin_estamina() -> void:
	_barra_estamina.pivot_offset = _barra_estamina.size / 2.0
	_barra_estamina.scale = Vector2(1.12, 1.25)
	create_tween().tween_property(_barra_estamina, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


## Barra de estamina junto a la batería, con el mismo estilo que la barra del rival.
func _preparar_barra_estamina() -> void:
	_barra_estamina = ProgressBar.new()
	_barra_estamina.name = "BarraEstamina"
	_barra_estamina.show_percentage = false
	_barra_estamina.max_value = ESTAMINA_MAX
	_barra_estamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_estamina.position = Vector2(bateria.position.x + 8.0, bateria.position.y - 36.0)
	_barra_estamina.size = Vector2(176.0, 32.0)
	var fondo_barra := StyleBoxFlat.new()
	fondo_barra.bg_color = Color(0.08, 0.05, 0.05, 0.9)
	fondo_barra.border_color = Color.WHITE
	fondo_barra.set_border_width_all(3)
	fondo_barra.set_corner_radius_all(9)
	_barra_estamina.add_theme_stylebox_override("background", fondo_barra)
	_estilo_estamina = StyleBoxFlat.new()
	_estilo_estamina.bg_color = COLOR_ESTAMINA_ALTA
	_estilo_estamina.set_corner_radius_all(7)
	_estilo_estamina.set_expand_margin_all(-3)
	_barra_estamina.add_theme_stylebox_override("fill", _estilo_estamina)
	_lbl_estamina = Label.new()
	_lbl_estamina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl_estamina.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estamina.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_estamina.add_theme_font_size_override("font_size", 16)
	_lbl_estamina.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_estamina.add_theme_constant_override("outline_size", 5)
	_lbl_estamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_estamina.add_child(_lbl_estamina)
	bateria.get_parent().add_child(_barra_estamina)
	_barra_estamina.visible = false # se muestra al empezar la pelea (en el tutorial no se usa)
	_actualizar_barra_estamina()


func _actualizar_barra_estamina() -> void:
	if _barra_estamina == null:
		return
	_barra_estamina.value = estamina
	if agotado:
		_estilo_estamina.bg_color = COLOR_ESTAMINA_BAJA
		_lbl_estamina.text = "¡AGOTADO!"
		_lbl_estamina.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		return
	_lbl_estamina.remove_theme_color_override("font_color")
	var r: float = estamina / ESTAMINA_MAX
	_estilo_estamina.bg_color = COLOR_ESTAMINA_ALTA if r > 0.5 else (COLOR_ESTAMINA_MEDIA if r > 0.25 else COLOR_ESTAMINA_BAJA)
	_lbl_estamina.text = "ESTAMINA"
