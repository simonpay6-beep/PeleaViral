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
# Si es true, el juego se CIERRA al terminar el Nivel 3. Si es false, se REINICIA desde phone_intro.tscn:
const CERRAR_JUEGO_AL_FINAL: bool = true

# --- DIFICULTAD (ChannelData.selected_difficulty): velocidad del enemigo y multiplicador de views ---
const DIFICULTADES: Dictionary = {
	"Fácil": {"velocidad": 1.35, "views": 1},
	"Normal": {"velocidad": 1.0, "views": 1},
	"Hardcore": {"velocidad": 0.70, "views": 2},
}

# --- TEXTOS DE LA CINEMÁTICA FINAL (NIVEL 3) ---
const TEXTO_CAIDA: String = "💀 GOLPE 10/10 — HAS CAÍDO EN LA LONA\n\n🔴 [TRANSMISIÓN EN DIRECTO INTERRUMPIDA]"
const TEXTO_ENSENANZA_1: String = "📖 LA ENSEÑANZA\n\nEmpezaste golpeando un árbol por deporte,\npero la obsesión por las visitas, los likes y la aprobación\nte arrastró a pelear en la calle por espectáculo."
const TEXTO_ENSENANZA_2: String = "Cuando peleas solo para alimentar las vistas de otros,\nsiempre aparecerá un rival imposible que no puedes derrotar.\n\nLa verdadera victoria no está en ganar peleas por fama en internet,\nsino en saber cuándo apagar la cámara."
const TEXTO_FIN: String = "FIN DEL JUEGO\n\nGracias por jugar.\nCerrando NeTube..."

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
enum Fase { TUTORIAL_ARBOL, HISTORIA_INTRO, PELEA, ANIMACION_RESULTADO, CINEMATICA_FINAL }

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

# Defensa y esquiva salen de combinar cámara + teclado. La guardia rota anula la defensa.
var defendiendo: bool:
	get:
		return (camara.defensa or teclado.defensa) and not guardia_rota
var esquiva_actual: String:
	get:
		return teclado.esquiva if teclado.esquiva != "CENTRO" else camara.esquiva

# --- ESTADÍSTICAS DEL JUGADOR ---
var vida_max_jugador: float = 100.0
var vida_jugador: float = 100.0

# Ruptura de guardia (Delay de 3s si te golpean mucho cubriéndote)
var guardia_rota: bool = false
var golpes_en_guardia: int = 0
var max_golpes_guardia: int = 4
var tiempo_delay_guardia: float = 3.0
var timer_ruptura: float = 0.0

# --- ESTADÍSTICAS DEL ENEMIGO ---
var nombre_enemigo: String = "Árbol de Entrenamiento"
var prefijo_anim: String = "arbol_"
var vida_max_enemigo: float = 100.0
var vida_enemigo: float = 100.0
var golpes_recibidos_seguidos: int = 0
var timer_ia_enemigo: float = 2.0
var timer_estado_enemigo: float = 0.0

# --- ASPECTO DEL ENEMIGO Y DE LA BATERÍA (vida del jugador) ---
const ESCALA_SPRITE: float = 0.34
## Estilo Punch-Out: tras recibir un golpe el rival se recupera y NO contraataca de inmediato.
const REPOSO_TRAS_GOLPE: float = 1.2
## true = la patada viene por un lado y solo se evita esquivando hacia el lado contrario.
## false = cualquier esquiva (izquierda o derecha) la evita. La defensa nunca sirve contra patadas.
const PATADA_REQUIERE_LADO: bool = true
const FRASES_GUARDIA: Array[String] = [
	"😤 Rival: '¡No podrás cubrirte para siempre!'",
	"😠 Rival: '¡Baja esas manos!'",
	"🥊 Rival: '¡Te voy a encontrar un hueco!'",
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
	barra_vida_enemigo.visible = false
	barra_vida_jugador.visible = false
	lbl_estado_jugador.visible = false
	lbl_estado_enemigo.visible = false # no se muestra el nombre del estado / animación del rival
	flash_dano.color.a = 0.0
	moscas.visible = false
	_pos_sprite = sprite_enemigo.position

	# Adapter: las dos fuentes hablan el mismo idioma.
	camara.ataque.connect(ejecutar_ataque_jugador)
	teclado.ataque.connect(ejecutar_ataque_jugador)
	camara.conectada.connect(_on_camara_conectada)
	camara.iniciar()
	if camara.escuchando:
		agregar_mensaje_chat("Sistema", "📡 Puerto %d listo. Esperando cámara de Python..." % Entradas.Camara.PUERTO)

	if nivel_actual == 1:
		iniciar_tutorial_arbol()
	else:
		iniciar_historia_nivel()


func _on_camara_conectada() -> void:
	agregar_mensaje_chat("Sistema", "✅ ¡Cámara Python detectada en vivo!")


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
	lbl_dialogo_enemigo.text = "PASO 1/4: Lanza 2 GOLPES RECTOS a la cámara (o tecla J) contra el árbol."
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
					lbl_dialogo_enemigo.text = "PASO 2/4: Lanza 2 HOOKS o UPPERCUTS (ganchos laterales o ascendentes / teclas K o L)."
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
				agregar_mensaje_chat("Bot_Tutorial", "🌲 ¡Árbol talado! Entrando en vivo...")
				lbl_dialogo_enemigo.text = "🌲 ¡ÁRBOL EN EL PISO! Calentamiento listo. Iniciando historia del Nivel 1..."
				actualizar_hud()
				await get_tree().create_timer(2.5).timeout
				iniciar_historia_nivel()
			else:
				lbl_dialogo_enemigo.text = "⚠️ ¡Estabas descubierto! Mantén una mano arriba de la barbilla tapando la nariz MIENTRAS golpeas."

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

	aplicar_estrategia(Niveles.crear(nivel_actual))
	lbl_dialogo_enemigo.text = estrategia.dialogo_inicio
	Audio.musica("pelea_jefe" if nivel_actual == 3 else "pelea")
	Audio.sfx("campana", false)

	agregar_mensaje_chat("NeTube_Bot", "🔴 ¡Transmisión en directo iniciada contra " + nombre_enemigo + "!")
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
		manos.golpear(tipo_ataque)
		Audio.sfx("patada_aire" if tipo_ataque.begins_with("PATADA") else "puno_aire")

	if fase_actual == Fase.TUTORIAL_ARBOL:
		evaluar_progreso_tutorial(tipo_ataque)
		return

	if fase_actual != Fase.PELEA or not estado_enemigo.acepta_ataques:
		return

	views_en_vivo += 45 * mult_views

	if estado_enemigo.bloquea_ataques:
		lbl_dialogo_enemigo.text = "🛡️ ¡El rival se cubre!"
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
		golpes_recibidos_seguidos += 1

		if golpes_recibidos_seguidos >= 4:
			cambiar_estado_enemigo(EstadosEnemigo.Id.NOQUEADO)
			timer_estado_enemigo = 1.8
			golpes_recibidos_seguidos = 0
			lbl_dialogo_enemigo.text = "💫 ¡Rival NOQUEADO DE PIE! ¡Remátalo!"
			EventBus.evento_combate.emit("noqueado")
		else:
			# Si estaba preparando un ataque, el golpe lo interrumpe (cambia el token de estado).
			cambiar_estado_enemigo(EstadosEnemigo.Id.HERIDO)
			timer_estado_enemigo = 0.45
			EventBus.evento_combate.emit("golpe_conecta")
		timer_ia_enemigo = maxf(timer_ia_enemigo, REPOSO_TRAS_GOLPE)

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
		ejecutar_accion_enemigo()


func ejecutar_accion_enemigo() -> void:
	# Cada nivel decide qué hace el enemigo (el Nivel 3 NUNCA bloquea ni se burla: solo ataca).
	var accion: Dictionary = estrategia.elegir_accion(randi() % 100)
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
func _atacar(estado_id: int, peso: int, preparacion: float) -> void:
	var base: String = EstadosEnemigo.crear(estado_id).sufijo_anim # "golpe", "golpe_fuerte" o "patada"
	var es_patada: bool = estado_id == EstadosEnemigo.Id.PATADA
	if es_patada:
		_lado_patada = ["IZQUIERDA", "DERECHA"].pick_random()
	cambiar_estado_enemigo(estado_id, base + "_preparar")
	Audio.sfx("aviso_ataque", false)
	var token: int = _token_estado
	timer_estado_enemigo = preparacion + 1.0 # no vuelve a IDLE mientras prepara
	await get_tree().create_timer(preparacion).timeout

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
			lbl_dialogo_enemigo.text = "💥 ¡El Jefe atraviesa tu guardia! Ataque " + str(golpes_jefe_conectados) + "/10"
		else:
			lbl_dialogo_enemigo.text = "🩸 ¡Impacto directo del Jefe! Ataque " + str(golpes_jefe_conectados) + "/10"
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

	if esquivo_bien:
		views_en_vivo += 120 * mult_views
		lbl_dialogo_enemigo.text = "😤 Rival: '¡Quédate quieto!'"
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
			lbl_dialogo_enemigo.text = "😂 Rival: '¡Tu guardia se rompió!'"
			EventBus.evento_combate.emit("guardia_rota")
		actualizar_hud()
		return "bloqueo"

	vida_jugador = maxf(0.0, vida_jugador - estrategia.dano_a_jugador(peso_escudo))
	if es_patada:
		lbl_dialogo_enemigo.text = "🦶 ¡Patada directa! Contra las patadas hay que esquivar, no defender."
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

	lbl_estado_enemigo.text = nombre_enemigo + "\n" + estado_enemigo.descripcion
	lbl_estado_enemigo.modulate = estado_enemigo.color

	reproducir_animacion(anim_forzada if anim_forzada != "" else estado_enemigo.sufijo_anim)
	# La patada se ve hacia el lado por el que viene (el sprite se voltea).
	sprite_enemigo.flip_h = nuevo_id == EstadosEnemigo.Id.PATADA and _lado_patada == "DERECHA"
	_efecto_estado(nuevo_id)

	# En el piso aparecen las moscas sobre el cuerpo.
	moscas.visible = nuevo_id == EstadosEnemigo.Id.EN_EL_PISO
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
	fase_actual = Fase.ANIMACION_RESULTADO
	pantalla_cinematica.visible = true

	Audio.musica("")
	Audio.sfx("victoria" if ganaste else "derrota", false)
	if ganaste:
		views_en_vivo += 500 * mult_views
		var nuevos_subs: int = int(views_en_vivo * 0.25)
		guardar_progreso_en_channel_data(views_en_vivo, nuevos_subs, true)

		pantalla_cinematica.color = Color(0.05, 0.35, 0.15, 0.96)
		texto_cinematica.text = "🏆 ¡VICTORIA EN EL VIDEO #" + str(nivel_actual) + "!\n\nDejaste a " + nombre_enemigo + " EN EL PISO.\n+" + str(views_en_vivo) + " Visitas | +" + str(nuevos_subs) + " Suscriptores\n\n[Regresando al panel del canal para el Video #" + str(ChannelData.current_video_index) + "...]"
	else:
		EventBus.evento_combate.emit("derrota")
		var views_consuelo: int = max(50, int(views_en_vivo * 0.3))
		guardar_progreso_en_channel_data(views_consuelo, 5, false)

		pantalla_cinematica.color = Color(0.35, 0.05, 0.05, 0.96)
		texto_cinematica.text = "❌ CAÍSTE EN LA LONA (VIDEO #" + str(nivel_actual) + ")\n\nEl rival se ríe en cámara. Ganas +" + str(views_consuelo) + " visitas.\nRegresando al canal para intentarlo de nuevo..."

	# Récord del nivel, leído y guardado en archivo (TAD HistorialPeleas).
	var record_anterior: int = historial.mejor_views(nivel_actual)
	historial.registrar(nivel_actual, ganaste, views_en_vivo)
	if views_en_vivo > record_anterior:
		texto_cinematica.text += "\n\n🏅 ¡NUEVO RÉCORD DEL NIVEL: " + str(views_en_vivo) + " views!"
	else:
		texto_cinematica.text += "\n\n🏅 Récord del nivel: " + str(record_anterior) + " views"

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

	# ACTO 2: La Enseñanza (primera parte)
	await _desvanecer_texto()
	pantalla_cinematica.color = Color(0.03, 0.03, 0.05, 1.0)
	await _aparecer_texto(TEXTO_ENSENANZA_1, 1.2, 5.0)

	# ACTO 3: La Enseñanza (reflexión final)
	await _desvanecer_texto()
	await _aparecer_texto(TEXTO_ENSENANZA_2, 1.2, 5.5)

	# ACTO 4: Reinicio de datos y Cierre del juego
	await _desvanecer_texto()
	ChannelData.reset_campaign() # Reiniciar ChannelData por completo
	await _aparecer_texto(TEXTO_FIN, 1.0, 3.0)

	if CERRAR_JUEGO_AL_FINAL:
		SceneRouter.quit_game() # Cierra el juego por completo
	else:
		SceneRouter.go(SceneRouter.INICIO_JUEGO) # O lo reinicia desde phone_intro.tscn


func _desvanecer_texto() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(texto_cinematica, "modulate:a", 0.0, 0.6)
	await tween.finished


func _aparecer_texto(texto: String, duracion: float, espera: float) -> void:
	texto_cinematica.text = texto
	var tween: Tween = create_tween()
	tween.tween_property(texto_cinematica, "modulate:a", 1.0, duracion)
	await tween.finished
	await get_tree().create_timer(espera).timeout


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
	lbl_titulo_nivel.text = "🔴 EN VIVO: " + ChannelData.video_title + " | 👀 Views: " + str(views_en_vivo)
	barra_vida_enemigo.max_value = vida_max_enemigo
	barra_vida_enemigo.value = vida_enemigo
	barra_vida_jugador.max_value = vida_max_jugador
	barra_vida_jugador.value = vida_jugador
	_actualizar_bateria()
