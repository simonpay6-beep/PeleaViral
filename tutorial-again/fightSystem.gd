extends Control

# --- RUTAS DE ESCENAS Y CONFIGURACIÓN DEL FINAL ---
const ESCENA_ADMIN_CANAL: String = "res://channel_dashboard.tscn"
const ESCENA_INICIO_JUEGO: String = "res://phone_intro.tscn"
# Si es true, el juego se CIERRA al terminar el Nivel 3. Si es false, se REINICIA desde phone_intro.tscn:
const CERRAR_JUEGO_AL_FINAL: bool = true

# --- REFERENCIAS A LOS NODOS DE JUEGO.TSCN ---
@onready var fondo: CanvasItem = $Fondo
@onready var sprite_enemigo: AnimatedSprite2D = $EnemigoSprite
@onready var ui_combate: Control = $UI_Combate
@onready var lbl_titulo_nivel: Label = $UI_Combate/TituloNivel
@onready var barra_vida_enemigo: ProgressBar = $UI_Combate/VidaEnemigo
@onready var lbl_dialogo_enemigo: Label = $UI_Combate/DialogoEnemigo
@onready var lbl_estado_enemigo: Label = $UI_Combate/EstadoEnemigoTexto
@onready var barra_vida_jugador: ProgressBar = $UI_Combate/VidaJugador
@onready var lbl_estado_jugador: Label = $UI_Combate/EstadoJugadorTexto
@onready var pantalla_cinematica: ColorRect = $PantallaCinematica
@onready var texto_cinematica: Label = $PantallaCinematica/TextoCinematica

# --- FASES Y LOS 10 ESTADOS DEL ENEMIGO ---
enum Fase { TUTORIAL_ARBOL, HISTORIA_INTRO, PELEA, ANIMACION_RESULTADO, CINEMATICA_FINAL }
enum EstadoEnemigo {
	IDLE,          # 1. En guardia
	GOLPE,         # 2. Golpe rápido
	GOLPE_FUERTE,  # 3. Golpe fuerte
	PATADA,        # 4. Patada
	BLOQUEO,       # 5. Bloqueo
	RISA,          # 6. Risa
	BURLA,         # 7. Burla (vulnerable)
	HERIDO,        # 8. Herido
	NOQUEADO,      # 9. Noqueado de pie
	EN_EL_PISO     # 10. En el piso (K.O.)
}

var fase_actual: Fase = Fase.TUTORIAL_ARBOL
var estado_enemigo: EstadoEnemigo = EstadoEnemigo.IDLE
var nivel_actual: int = 1
var golpes_jefe_conectados: int = 0

# --- MÉTRICAS DEL STREAM Y CHAT EN VIVO ---
var views_en_vivo: int = 0
var mult_views: int = 1
var factor_velocidad_dificultad: float = 1.0
var nodo_chat_texto: RichTextLabel = null
var lineas_chat: Array[String] = []
var timer_chat_random: float = 2.0

var usuarios_chat: Array[String] = [
	"xX_BoxerPro_Xx", "NeTubeFan99", "CamaraFighter", "ElCritico_YT", 
	"Kicker_BJJ", "PunchOutKing", "GatoGamer", "BarranquillaStream"
]

# --- CONEXIÓN UDP (WEBCAM MEDIAPIPE) ---
var udp := PacketPeerUDP.new()
var camara_conectada: bool = false

# --- ESTADÍSTICAS DEL JUGADOR ---
var vida_max_jugador: float = 100.0
var vida_jugador: float = 100.0
var defendiendo: bool = false
var esquiva_actual: String = "CENTRO"

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
var timer_dialogo_jefe: float = 3.0

# --- PROGRESO DEL TUTORIAL (EL ÁRBOL) ---
var paso_tutorial: int = 0
var contador_tutorial: int = 0

# --- DIÁLOGOS EN VIVO DEL JEFE IMPOSIBLE (NIVEL 3) ---
var dialogos_nivel_3: Array[String] = [
	"Por más que levantes las manos, no puedes bloquear tu propio ego.",
	"¿Todo esto por unas cuantas visitas en NeTube? Mírate.",
	"Tengo VIDA INFINITA porque la obsesión por la fama nunca se acaba.",
	"Cada golpe que recibes sube tus views... ¿valió la pena?",
	"Ni tu cámara ni tus puños pueden derrotar al Algoritmo.",
	"Acepta la derrota. El directo está a punto de terminar."
]

func _ready() -> void:
	nivel_actual = clampi(ChannelData.current_video_index, 1, 3)
	configurar_parametros_channel_data()
	configurar_live_overlay_chat()

	var err = udp.bind(4242)
	if err == OK:
		agregar_mensaje_chat("Sistema", "📡 Puerto 4242 listo. Esperando cámara de Python...")

	if nivel_actual == 1:
		iniciar_tutorial_arbol()
	else:
		iniciar_historia_nivel()

func configurar_live_overlay_chat() -> void:
	var instancia_overlay: Node = null
	if ui_combate.has_node("LiveOverlay"):
		instancia_overlay = ui_combate.get_node("LiveOverlay")
	elif has_node("LiveOverlay"):
		instancia_overlay = get_node("LiveOverlay")
	elif ResourceLoader.exists("res://live_overlay.tscn"):
		var escena_overlay = load("res://live_overlay.tscn")
		if escena_overlay:
			instancia_overlay = escena_overlay.instantiate()
			instancia_overlay.name = "LiveOverlay"
			ui_combate.add_child(instancia_overlay)

	if instancia_overlay:
		for hijo in instancia_overlay.find_children("*", "RichTextLabel", true, false):
			nodo_chat_texto = hijo
			break

	if not nodo_chat_texto:
		var panel_chat = ColorRect.new()
		panel_chat.color = Color(0.05, 0.05, 0.08, 0.85)
		panel_chat.position = Vector2(780, 70)
		panel_chat.size = Vector2(340, 420)
		ui_combate.add_child(panel_chat)

		var titulo_chat = Label.new()
		titulo_chat.text = "💬 Chat del directo - NeTube"
		titulo_chat.position = Vector2(12, 8)
		titulo_chat.modulate = Color(1, 0.3, 0.3)
		panel_chat.add_child(titulo_chat)

		nodo_chat_texto = RichTextLabel.new()
		nodo_chat_texto.bbcode_enabled = true
		nodo_chat_texto.position = Vector2(12, 38)
		nodo_chat_texto.size = Vector2(316, 370)
		nodo_chat_texto.scroll_following = true
		panel_chat.add_child(nodo_chat_texto)

func agregar_mensaje_chat(usuario: String, mensaje: String) -> void:
	if not nodo_chat_texto: return
	var linea: String = "[b]" + usuario + ":[/b] " + mensaje
	lineas_chat.append(linea)
	if lineas_chat.size() > 18:
		lineas_chat.pop_front()
	nodo_chat_texto.text = "\n".join(lineas_chat)

func configurar_parametros_channel_data() -> void:
	match ChannelData.selected_difficulty:
		"Fácil":
			factor_velocidad_dificultad = 1.35
			mult_views = 1
		"Hardcore":
			factor_velocidad_dificultad = 0.70
			mult_views = 2
		_:
			factor_velocidad_dificultad = 1.0
			mult_views = 1

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
		defendiendo = false
		if timer_ruptura <= 0.0:
			guardia_rota = false
			golpes_en_guardia = 0
			agregar_mensaje_chat("Sistema", "🛡️ ¡Recuperaste la guardia!")
			actualizar_hud()

	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var json = JSON.new()
		if json.parse(packet.get_string_from_utf8()) == OK:
			if not camara_conectada:
				camara_conectada = true
				agregar_mensaje_chat("Sistema", "✅ ¡Cámara Python detectada en vivo!")
			procesar_datos_camara(json.data)

	procesar_teclado_respaldo()

	if fase_actual == Fase.PELEA:
		actualizar_ia_enemigo(delta)
		timer_chat_random -= delta
		if timer_chat_random <= 0.0:
			timer_chat_random = randf_range(2.0, 3.5)
			generar_comentario_ambiental()
	elif fase_actual == Fase.TUTORIAL_ARBOL:
		if timer_estado_enemigo > 0.0:
			timer_estado_enemigo -= delta
			if timer_estado_enemigo <= 0.0 and estado_enemigo != EstadoEnemigo.EN_EL_PISO:
				cambiar_estado_enemigo(EstadoEnemigo.IDLE)

func generar_comentario_ambiental() -> void:
	var user = usuarios_chat.pick_random()
	if nivel_actual == 3:
		var msgs_n3 = [
			"¡¡NO LE BAJA NADA LA VIDA!! 😱",
			"¡Para el directo bro, te va a matar!",
			"¡Ni cubriéndote puedes parar sus golpes!",
			"¡100,000 espectadores viendo cómo cae! 🔥"
		]
		agregar_mensaje_chat(user, msgs_n3.pick_random())
	else:
		var msgs = [
			"¡Dale con el Uppercut!",
			"Buena guardia frente a la cámara 🥊",
			"¡Esquiva, esquiva!",
			"Llegando al directo, ¿quién va ganando?"
		]
		agregar_mensaje_chat(user, msgs.pick_random())

# ==========================================================
# 1. ENTRADA DE CÁMARA PYTHON Y TECLADO
# ==========================================================
func procesar_datos_camara(data: Dictionary) -> void:
	if fase_actual != Fase.TUTORIAL_ARBOL and fase_actual != Fase.PELEA:
		return

	if not guardia_rota:
		defendiendo = data.get("defensa", false)
	else:
		defendiendo = false

	esquiva_actual = data.get("esquiva", "CENTRO")

	var ataque = data.get("ataque", "NINGUNO")
	if ataque != "NINGUNO":
		ejecutar_ataque_jugador(ataque)

	actualizar_hud()

func procesar_teclado_respaldo() -> void:
	if fase_actual == Fase.HISTORIA_INTRO or fase_actual == Fase.ANIMACION_RESULTADO:
		if Input.is_action_just_pressed("ui_accept"):
			avanzar_cinematica()
		return

	if not guardia_rota and Input.is_key_pressed(KEY_SHIFT):
		defendiendo = true

	if Input.is_key_pressed(KEY_A): esquiva_actual = "IZQUIERDA"
	elif Input.is_key_pressed(KEY_D): esquiva_actual = "DERECHA"

	if Input.is_key_pressed(KEY_J) and Engine.get_process_frames() % 15 == 0:
		ejecutar_ataque_jugador("RECTO_DER")
	elif Input.is_key_pressed(KEY_K) and Engine.get_process_frames() % 15 == 0:
		ejecutar_ataque_jugador("HOOK_IZQ")
	elif Input.is_key_pressed(KEY_L) and Engine.get_process_frames() % 15 == 0:
		ejecutar_ataque_jugador("UPPERCUT_DER")
	elif Input.is_action_just_pressed("ui_select"):
		ejecutar_ataque_jugador("PATADA_DER")

# ==========================================================
# 2. TUTORIAL CONTRA EL ÁRBOL (SOLO EN VIDEO #1)
# ==========================================================
func iniciar_tutorial_arbol() -> void:
	fase_actual = Fase.TUTORIAL_ARBOL
	pantalla_cinematica.visible = false
	nombre_enemigo = "🌳 Árbol de Entrenamiento"
	prefijo_anim = "arbol_"
	vida_max_enemigo = 100.0
	vida_enemigo = 100.0
	paso_tutorial = 1
	contador_tutorial = 0
	cambiar_estado_enemigo(EstadoEnemigo.IDLE)
	agregar_mensaje_chat("Bot_Tutorial", "Bienvenido. Derriba el árbol con tu cámara para iniciar el directo.")
	lbl_dialogo_enemigo.text = "PASO 1/4: Lanza 2 GOLPES RECTOS a la cámara (o tecla J) contra el árbol."
	actualizar_hud()

func evaluar_progreso_tutorial(tipo_ataque: String) -> void:
	cambiar_estado_enemigo(EstadoEnemigo.HERIDO)
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
				vida_enemigo = 0
				cambiar_estado_enemigo(EstadoEnemigo.EN_EL_PISO)
				agregar_mensaje_chat("Bot_Tutorial", "🌲 ¡Árbol talado! Entrando en vivo...")
				lbl_dialogo_enemigo.text = "🌲 ¡ÁRBOL EN EL PISO! Calentamiento listo. Iniciando historia del Nivel 1..."
				actualizar_hud()
				await get_tree().create_timer(2.5).timeout
				iniciar_historia_nivel()
			else:
				lbl_dialogo_enemigo.text = "⚠️ ¡Estabas descubierto! Mantén una mano arriba de la barbilla tapando la nariz MIENTRAS golpeas."

	actualizar_hud()

# ==========================================================
# 3. HISTORIA Y PELEA
# ==========================================================
func iniciar_historia_nivel() -> void:
	fase_actual = Fase.HISTORIA_INTRO
	pantalla_cinematica.visible = true

	match nivel_actual:
		1:
			pantalla_cinematica.color = Color(0.08, 0.12, 0.22, 0.96)
			texto_cinematica.text = "🎬 HISTORIA NIVEL 1: " + ChannelData.video_title + "\n\nEl directo comienza tras derribar el árbol.\nTu primer rival callejero entra al encuadre buscando tumbarte el stream.\n\n[Presiona ENTER o espera 4 segundos]"
		2:
			pantalla_cinematica.color = Color(0.18, 0.08, 0.25, 0.96)
			texto_cinematica.text = "🎬 HISTORIA NIVEL 2: " + ChannelData.video_title + "\n\nTus suscriptores subieron y ahora te reta un peleador pesado.\nBloquea tus ataques, se burla y patea con fuerza.\n\n[Presiona ENTER o espera 4 segundos]"
		3:
			pantalla_cinematica.color = Color(0.25, 0.02, 0.02, 0.96)
			texto_cinematica.text = "🎬 HISTORIA NIVEL 3: " + ChannelData.video_title + "\n\n⚠️ EL COMBATE FINAL ⚠️\nLa fama te trajo hasta aquí, pero este rival es IMPOSIBLE.\nTiene VIDA INFINITA y caerás en exactamente 10 ATAQUES.\n\n[Presiona ENTER o espera 4 segundos]"

	await get_tree().create_timer(4.0).timeout
	if fase_actual == Fase.HISTORIA_INTRO:
		iniciar_pelea_nivel()

func avanzar_cinematica() -> void:
	if fase_actual == Fase.HISTORIA_INTRO:
		iniciar_pelea_nivel()
	elif fase_actual == Fase.ANIMACION_RESULTADO:
		volver_a_administrar_canal()

func iniciar_pelea_nivel() -> void:
	fase_actual = Fase.PELEA
	pantalla_cinematica.visible = false
	vida_jugador = vida_max_jugador
	guardia_rota = false
	golpes_en_guardia = 0
	golpes_jefe_conectados = 0

	match nivel_actual:
		1:
			nombre_enemigo = "🥊 Rival #1: Buscapleitos Callejero"
			prefijo_anim = "n1_"
			vida_max_enemigo = 100.0
			vida_enemigo = 100.0
			lbl_dialogo_enemigo.text = "Rival #1: '¡Hoy te quedas sin canal en NeTube!'"
		2:
			nombre_enemigo = "🦵 Rival #2: Campeón Pesado"
			prefijo_anim = "n2_"
			vida_max_enemigo = 180.0
			vida_enemigo = 180.0
			lbl_dialogo_enemigo.text = "Rival #2: 'Tus golpes del primer video no servirán conmigo.'"
		3:
			nombre_enemigo = "👁️ NIVEL 3: EL ALGORITMO (INVENCIBLE)"
			prefijo_anim = "n3_"
			vida_max_enemigo = 999999.0
			vida_enemigo = 999999.0
			lbl_dialogo_enemigo.text = "Jefe Final: 'Soy invencible. En 10 ataques aprenderás la lección.'"

	agregar_mensaje_chat("NeTube_Bot", "🔴 ¡Transmisión en directo iniciada contra " + nombre_enemigo + "!")
	cambiar_estado_enemigo(EstadoEnemigo.IDLE)
	actualizar_hud()

func ejecutar_ataque_jugador(tipo_ataque: String) -> void:
	if fase_actual == Fase.TUTORIAL_ARBOL:
		evaluar_progreso_tutorial(tipo_ataque)
		return

	if fase_actual != Fase.PELEA or estado_enemigo == EstadoEnemigo.EN_EL_PISO:
		return

	views_en_vivo += 45 * mult_views

	if estado_enemigo == EstadoEnemigo.BLOQUEO:
		lbl_dialogo_enemigo.text = "🛡️ ¡El enemigo bloqueó tu " + tipo_ataque + "!"
		agregar_mensaje_chat(usuarios_chat.pick_random(), "¡Uy, te bloqueó ese " + tipo_ataque + "!")
		actualizar_hud()
		return

	var dano: float = 8.0
	if tipo_ataque.begins_with("HOOK"): dano = 12.0
	elif tipo_ataque.begins_with("UPPERCUT"): dano = 16.0
	elif tipo_ataque.begins_with("PATADA"): dano = 14.0

	if estado_enemigo == EstadoEnemigo.BURLA or estado_enemigo == EstadoEnemigo.NOQUEADO:
		dano *= 1.8
		views_en_vivo += 80 * mult_views

	# En Nivel 3 es 100% inmortal
	if nivel_actual == 3:
		vida_enemigo = 999999.0
		cambiar_estado_enemigo(EstadoEnemigo.RISA)
		timer_estado_enemigo = 0.5
		lbl_dialogo_enemigo.text = "Jefe: '¿Un " + tipo_ataque + "? Daño: 0. Mi vida es INFINITA.'"
	else:
		vida_enemigo = max(0.0, vida_enemigo - dano)
		golpes_recibidos_seguidos += 1

		if golpes_recibidos_seguidos >= 4:
			cambiar_estado_enemigo(EstadoEnemigo.NOQUEADO)
			timer_estado_enemigo = 1.8
			golpes_recibidos_seguidos = 0
			lbl_dialogo_enemigo.text = "💫 ¡Rival NOQUEADO DE PIE! ¡Remátalo!"
			agregar_mensaje_chat(usuarios_chat.pick_random(), "¡ESTÁ MAREADO, REMÁTALO YA! 💫")
		else:
			cambiar_estado_enemigo(EstadoEnemigo.HERIDO)
			timer_estado_enemigo = 0.45

		if vida_enemigo <= 0.0:
			cambiar_estado_enemigo(EstadoEnemigo.EN_EL_PISO)
			finalizar_combate(true)

	actualizar_hud()

func actualizar_ia_enemigo(delta: float) -> void:
	if nivel_actual == 3:
		timer_dialogo_jefe -= delta
		if timer_dialogo_jefe <= 0.0:
			timer_dialogo_jefe = 3.2
			lbl_dialogo_enemigo.text = "👁️ Jefe Final: \"" + dialogos_nivel_3.pick_random() + "\""

	if timer_estado_enemigo > 0.0:
		timer_estado_enemigo -= delta
		if timer_estado_enemigo <= 0.0 and estado_enemigo != EstadoEnemigo.EN_EL_PISO:
			cambiar_estado_enemigo(EstadoEnemigo.IDLE)

	timer_ia_enemigo -= delta
	if timer_ia_enemigo <= 0.0 and estado_enemigo == EstadoEnemigo.IDLE:
		if nivel_actual == 3:
			# En Nivel 3 ataca sin descanso hasta completar los 10 ataques
			timer_ia_enemigo = 1.05
		else:
			var base_time: float = 2.0 if nivel_actual == 1 else 1.35
			timer_ia_enemigo = base_time * factor_velocidad_dificultad
		ejecutar_accion_enemigo()

func ejecutar_accion_enemigo() -> void:
	var dado = randi() % 100

	# En el Nivel 3 el jefe NUNCA pierde turnos bloqueando ni burlándose: solo ataca para que pierdas sí o sí
	if nivel_actual == 3:
		if dado < 40:
			cambiar_estado_enemigo(EstadoEnemigo.GOLPE)
			timer_estado_enemigo = 0.55
			aplicar_ataque_al_jugador("GOLPE INEVITABLE", 1)
		elif dado < 75:
			cambiar_estado_enemigo(EstadoEnemigo.GOLPE_FUERTE)
			timer_estado_enemigo = 0.65
			aplicar_ataque_al_jugador("IMPACTO BRUTAL", 2)
		else:
			cambiar_estado_enemigo(EstadoEnemigo.PATADA)
			timer_estado_enemigo = 0.6
			aplicar_ataque_al_jugador("PATADA DESTRUCTORA", 1)
		return

	# Niveles 1 y 2 normales
	if dado < 35:
		cambiar_estado_enemigo(EstadoEnemigo.GOLPE)
		timer_estado_enemigo = 0.6
		aplicar_ataque_al_jugador("GOLPE", 1)
	elif dado < 60:
		cambiar_estado_enemigo(EstadoEnemigo.GOLPE_FUERTE)
		timer_estado_enemigo = 0.75
		aplicar_ataque_al_jugador("GOLPE FUERTE", 2)
	elif dado < 80:
		cambiar_estado_enemigo(EstadoEnemigo.PATADA)
		timer_estado_enemigo = 0.7
		aplicar_ataque_al_jugador("PATADA", 1)
	elif dado < 90:
		cambiar_estado_enemigo(EstadoEnemigo.BLOQUEO)
		timer_estado_enemigo = 1.2
		golpes_recibidos_seguidos = 0
	else:
		cambiar_estado_enemigo(EstadoEnemigo.BURLA)
		timer_estado_enemigo = 1.3
		lbl_dialogo_enemigo.text = "😜 ¡El rival hace una BURLA! ¡Golpéalo ahora!"

func aplicar_ataque_al_jugador(nombre_ataque: String, peso_escudo: int) -> void:
	# En el Nivel 3 debes perder SÍ O SÍ: los 10 ataques atraviesan cualquier esquiva o defensa
	if nivel_actual == 3:
		golpes_jefe_conectados += 1
		vida_jugador = max(0.0, vida_jugador - 10.0) # 10 ataques exactos = 0 de vida
		views_en_vivo += 300 * mult_views
		if defendiendo:
			lbl_dialogo_enemigo.text = "💥 ¡El Jefe atraviesa tu guardia! Ataque " + str(golpes_jefe_conectados) + "/10"
		else:
			lbl_dialogo_enemigo.text = "🩸 ¡Impacto directo del Jefe! Ataque " + str(golpes_jefe_conectados) + "/10"
		actualizar_hud()

		if vida_jugador <= 0.0 or golpes_jefe_conectados >= 10:
			cambiar_estado_enemigo(EstadoEnemigo.RISA)
			ejecutar_cinematica_final_nivel_3()
		return

	# Lógica normal para Nivel 1 y Nivel 2
	if esquiva_actual != "CENTRO":
		views_en_vivo += 120 * mult_views
		lbl_dialogo_enemigo.text = "💨 ¡Esquivaste el " + nombre_ataque + "! (+Views en el directo)"
		agregar_mensaje_chat(usuarios_chat.pick_random(), "¡¡QUÉ REFLEJOS PARA ESQUIVAR!! 💨")
		actualizar_hud()
		return

	if defendiendo and not guardia_rota:
		golpes_en_guardia += peso_escudo
		views_en_vivo += 35 * mult_views
		lbl_dialogo_enemigo.text = "🛡️ Bloqueaste " + nombre_ataque + " (" + str(golpes_en_guardia) + "/" + str(max_golpes_guardia) + ")"
		if golpes_en_guardia >= max_golpes_guardia:
			guardia_rota = true
			defendiendo = false
			timer_ruptura = tiempo_delay_guardia
			cambiar_estado_enemigo(EstadoEnemigo.RISA)
			timer_estado_enemigo = 1.2
			lbl_dialogo_enemigo.text = "⚠️ ¡GUARDIA ROTA! Delay de 3 segundos sin poder cubrirte."
			agregar_mensaje_chat(usuarios_chat.pick_random(), "¡NOOO TE ROMPIÓ LA GUARDIA! ⚠️")
		actualizar_hud()
		return

	var dano_recibido: float = 12.0 if peso_escudo == 1 else 18.0
	if nivel_actual == 2:
		dano_recibido = 15.0 if peso_escudo == 1 else 22.0

	vida_jugador = max(0.0, vida_jugador - dano_recibido)
	actualizar_hud()

	if vida_jugador <= 0.0:
		cambiar_estado_enemigo(EstadoEnemigo.RISA)
		finalizar_combate(false)

func cambiar_estado_enemigo(nuevo_estado: EstadoEnemigo) -> void:
	estado_enemigo = nuevo_estado
	var sufijo_anim: String = "idle"
	var descripcion: String = ""
	var color_estado: Color = Color.WHITE

	match estado_enemigo:
		EstadoEnemigo.IDLE:
			sufijo_anim = "idle"
			descripcion = "[1/10] EN GUARDIA (IDLE)"
			color_estado = Color(0.8, 0.9, 1.0)
		EstadoEnemigo.GOLPE:
			sufijo_anim = "golpe"
			descripcion = "[2/10] 🥊 GOLPE"
			color_estado = Color(1.0, 0.6, 0.2)
		EstadoEnemigo.GOLPE_FUERTE:
			sufijo_anim = "golpe_fuerte"
			descripcion = "[3/10] 💥 GOLPE FUERTE"
			color_estado = Color(1.0, 0.2, 0.2)
		EstadoEnemigo.PATADA:
			sufijo_anim = "patada"
			descripcion = "[4/10] 🦵 PATADA"
			color_estado = Color(1.0, 0.5, 0.0)
		EstadoEnemigo.BLOQUEO:
			sufijo_anim = "bloqueo"
			descripcion = "[5/10] 🛡️ BLOQUEO"
			color_estado = Color(0.3, 0.8, 1.0)
		EstadoEnemigo.RISA:
			sufijo_anim = "risa"
			descripcion = "[6/10] 😂 RISA"
			color_estado = Color(0.9, 0.4, 1.0)
		EstadoEnemigo.BURLA:
			sufijo_anim = "burla"
			descripcion = "[7/10] 😜 BURLA"
			color_estado = Color(1.0, 1.0, 0.3)
		EstadoEnemigo.HERIDO:
			sufijo_anim = "herido"
			descripcion = "[8/10] 🩸 HERIDO"
			color_estado = Color(1.0, 0.4, 0.4)
		EstadoEnemigo.NOQUEADO:
			sufijo_anim = "noqueado"
			descripcion = "[9/10] 💫 NOQUEADO DE PIE"
			color_estado = Color(1.0, 1.0, 0.5)
		EstadoEnemigo.EN_EL_PISO:
			sufijo_anim = "en_el_piso"
			descripcion = "[10/10] 💀 EN EL PISO (K.O.)"
			color_estado = Color(0.5, 0.5, 0.5)

	lbl_estado_enemigo.text = nombre_enemigo + "\n" + descripcion
	lbl_estado_enemigo.modulate = color_estado
	sprite_enemigo.modulate = color_estado

	if sprite_enemigo.sprite_frames:
		var anim_completa = prefijo_anim + sufijo_anim
		if sprite_enemigo.sprite_frames.has_animation(anim_completa):
			sprite_enemigo.play(anim_completa)
		elif sprite_enemigo.sprite_frames.has_animation(sufijo_anim):
			sprite_enemigo.play(sufijo_anim)

# ==========================================================
# FIN DE PELEA (NIVELES 1 Y 2)
# ==========================================================
func finalizar_combate(ganaste: bool) -> void:
	fase_actual = Fase.ANIMACION_RESULTADO
	pantalla_cinematica.visible = true

	if ganaste:
		views_en_vivo += 500 * mult_views
		var nuevos_subs: int = int(views_en_vivo * 0.25)
		guardar_progreso_en_channel_data(views_en_vivo, nuevos_subs, true)

		pantalla_cinematica.color = Color(0.05, 0.35, 0.15, 0.96)
		texto_cinematica.text = "🏆 ¡VICTORIA EN EL VIDEO #" + str(nivel_actual) + "!\n\nDejaste a " + nombre_enemigo + " EN EL PISO.\n+" + str(views_en_vivo) + " Visitas | +" + str(nuevos_subs) + " Suscriptores\n\n[Regresando al panel del canal para el Video #" + str(ChannelData.current_video_index) + "...]"
	else:
		var views_consuelo: int = max(50, int(views_en_vivo * 0.3))
		guardar_progreso_en_channel_data(views_consuelo, 5, false)

		pantalla_cinematica.color = Color(0.35, 0.05, 0.05, 0.96)
		texto_cinematica.text = "❌ CAÍSTE EN LA LONA (VIDEO #" + str(nivel_actual) + ")\n\nEl rival se ríe en cámara. Ganas +" + str(views_consuelo) + " visitas.\nRegresando al canal para intentarlo de nuevo..."

	await get_tree().create_timer(4.5).timeout
	if fase_actual == Fase.ANIMACION_RESULTADO:
		volver_a_administrar_canal()

# ==========================================================
# CINEMÁTICA FINAL DE LA ENSEÑANZA Y CIERRE DEL JUEGO (NIVEL 3)
# ==========================================================
func ejecutar_cinematica_final_nivel_3() -> void:
	fase_actual = Fase.CINEMATICA_FINAL
	udp.close() # Cerramos la conexión con la cámara

	pantalla_cinematica.visible = true
	pantalla_cinematica.color = Color(0.5, 0.0, 0.0, 0.0)
	texto_cinematica.modulate.a = 0.0

	# ACTO 1: Caída en el golpe #10 y corte de transmisión
	texto_cinematica.text = "💀 GOLPE 10/10 — HAS CAÍDO EN LA LONA\n\n🔴 [TRANSMISIÓN EN DIRECTO INTERRUMPIDA]"
	var tween1 = create_tween()
	tween1.tween_property(pantalla_cinematica, "color", Color(0.15, 0.02, 0.02, 1.0), 1.2)
	tween1.parallel().tween_property(texto_cinematica, "modulate:a", 1.0, 1.0)
	await tween1.finished
	await get_tree().create_timer(3.2).timeout

	# ACTO 2: La Enseñanza (primera parte)
	var tween2 = create_tween()
	tween2.tween_property(texto_cinematica, "modulate:a", 0.0, 0.6)
	await tween2.finished

	pantalla_cinematica.color = Color(0.03, 0.03, 0.05, 1.0)
	texto_cinematica.text = "📖 LA ENSEÑANZA\n\nEmpezaste golpeando un árbol por deporte,\npero la obsesión por las visitas, los likes y la aprobación\nte arrastró a pelear en la calle por espectáculo."
	var tween3 = create_tween()
	tween3.tween_property(texto_cinematica, "modulate:a", 1.0, 1.2)
	await tween3.finished
	await get_tree().create_timer(5.0).timeout

	# ACTO 3: La Enseñanza (reflexión final)
	var tween4 = create_tween()
	tween4.tween_property(texto_cinematica, "modulate:a", 0.0, 0.6)
	await tween4.finished

	texto_cinematica.text = "Cuando peleas solo para alimentar las vistas de otros,\nsiempre aparecerá un rival imposible que no puedes derrotar.\n\nLa verdadera victoria no está en ganar peleas por fama en internet,\nsino en saber cuándo apagar la cámara."
	var tween5 = create_tween()
	tween5.tween_property(texto_cinematica, "modulate:a", 1.0, 1.2)
	await tween5.finished
	await get_tree().create_timer(5.5).timeout

	# ACTO 4: Reinicio de datos y Cierre del juego
	var tween6 = create_tween()
	tween6.tween_property(texto_cinematica, "modulate:a", 0.0, 0.6)
	await tween6.finished

	# Reiniciar ChannelData por completo
	ChannelData.current_video_index = 1
	ChannelData.total_views = 0
	ChannelData.total_subscribers = 0

	texto_cinematica.text = "FIN DEL JUEGO\n\nGracias por jugar.\nCerrando NeTube..."
	var tween7 = create_tween()
	tween7.tween_property(texto_cinematica, "modulate:a", 1.0, 1.0)
	await tween7.finished
	await get_tree().create_timer(3.0).timeout

	if CERRAR_JUEGO_AL_FINAL:
		get_tree().quit() # Cierra el juego por completo
	else:
		get_tree().change_scene_to_file(ESCENA_INICIO_JUEGO) # O lo reinicia desde phone_intro.tscn

func guardar_progreso_en_channel_data(views_ganadas: int, subs_ganados: int, avanzar_nivel: bool) -> void:
	ChannelData.total_views += views_ganadas
	ChannelData.total_subscribers += subs_ganados
	if avanzar_nivel and ChannelData.current_video_index < 3:
		ChannelData.current_video_index += 1

func volver_a_administrar_canal() -> void:
	udp.close()
	if ResourceLoader.exists(ESCENA_ADMIN_CANAL):
		get_tree().change_scene_to_file(ESCENA_ADMIN_CANAL)

func actualizar_hud() -> void:
	var estado_cam = "📷 Cam: ON" if camara_conectada else "⌨️ Modo Teclado"
	lbl_titulo_nivel.text = "🔴 EN VIVO: " + ChannelData.video_title + " | 👀 Views: " + str(views_en_vivo) + " | " + estado_cam
	barra_vida_enemigo.max_value = vida_max_enemigo
	barra_vida_enemigo.value = vida_enemigo
	barra_vida_jugador.max_value = vida_max_jugador
	barra_vida_jugador.value = vida_jugador

	if nivel_actual == 3:
		lbl_estado_jugador.text = "⚠️ RIVAL INVENCIBLE | Golpes recibidos: " + str(golpes_jefe_conectados) + "/10 (Tu defensa no puede detenerlo)"
	elif guardia_rota:
		lbl_estado_jugador.text = "⚠️ ¡GUARDIA ROTA! Delay sin defensa: " + str(snapped(timer_ruptura, 0.1)) + "s"
	elif defendiendo:
		lbl_estado_jugador.text = "🛡️ DEFENSA ACTIVA (Arriba de barbilla / Tapando nariz) | Escudo: " + str(max_golpes_guardia - golpes_en_guardia) + "/" + str(max_golpes_guardia)
	else:
		lbl_estado_jugador.text = "🥊 DESCUBIERTO | Esquiva: " + esquiva_actual + " | Dificultad: " + ChannelData.selected_difficulty
