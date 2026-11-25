extends SceneTree
## Pruebas del combate: cooldown, dificultad, barra de vida y modo furia.

var _fallas: int = 0


func check(cond: bool, nombre: String) -> void:
	print(("  OK   " if cond else "  FALLA ") + nombre)
	if not cond:
		_fallas += 1


func esperar(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_correr.call_deferred()


func abrir_pelea(nivel: int) -> Node:
	root.get_node("ChannelData").current_video_index = nivel
	var juego: Node = load("res://juego.tscn").instantiate()
	root.add_child(juego)
	await esperar(5)
	juego._on_controles_cerrado() # en el video 1 la ayuda se abre al empezar
	juego.iniciar_pelea_nivel()
	juego.timer_ia_enemigo = 999.0 # el rival no ataca durante la prueba
	await esperar(2)
	return juego


func _correr() -> void:
	print("== Dificultad")
	var n1: Niveles.Estrategia = Niveles.crear(1)
	var n2: Niveles.Estrategia = Niveles.crear(2)
	var n3: Niveles.Estrategia = Niveles.crear(3)
	check(n1.vida_max == 170.0 and n1.intervalo_ia(1.0) == 1.35 and n1.dano_a_jugador(2) == 24.0, "nivel 1 más difícil")
	check(n2.vida_max == 280.0 and n2.intervalo_ia(1.0) == 0.95 and n2.dano_a_jugador(2) == 30.0, "nivel 2 más difícil")
	check(n3.intervalo_ia(1.0) == 1.05 and not n3.puede_enfurecerse(), "nivel 3 sin cambios y sin furia")
	check(not Niveles.crear_tutorial().puede_enfurecerse(), "el árbol no entra en furia")

	print("== Cooldown y barra de vida (nivel 1)")
	var juego: Node = await abrir_pelea(1)
	check(juego.barra_vida_enemigo.visible, "la barra de vida del rival se ve")
	check(juego.barra_vida_enemigo.max_value == 170.0, "la barra usa la vida del rival")
	var vida0: float = juego.vida_enemigo
	juego.ejecutar_ataque_jugador("RECTO_DER")
	var vida1: float = juego.vida_enemigo
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(vida1 < vida0, "el primer golpe hace daño")
	check(juego.vida_enemigo == vida1, "un segundo golpe inmediato se bloquea por el cooldown")
	check(juego.manos.modulate.a < 1.0, "los puños se ven opacos mientras recargan")
	await create_timer(0.45).timeout
	check(juego.manos.modulate.a == 1.0, "tras la recarga los puños vuelven a la normalidad")
	juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego.vida_enemigo < vida1, "tras la recarga se puede golpear otra vez")

	print("== El rival también ataca (sin bucle de golpes)")
	juego.timer_cooldown = 0.0
	juego.golpes_recibidos_seguidos = 0
	juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	juego.timer_ia_enemigo = 0.0
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego.timer_ia_enemigo <= juego.REPOSO_TRAS_GOLPE, "un golpe solo retrasa al rival 0,4 s")
	juego.timer_ia_enemigo = 999.0
	for i in 2:
		juego.timer_cooldown = 0.0
		juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
		juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego._preparando_ataque and juego._ataque_con_armadura, "al tercer golpe seguido contraataca")
	var estado_contra: int = juego.estado_enemigo.id
	juego.timer_cooldown = 0.0
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego._preparando_ataque and juego.estado_enemigo.id == estado_contra, "el contraataque no se puede interrumpir")
	await create_timer(0.8).timeout
	juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	juego.vida_jugador = juego.vida_max_jugador
	juego._tiempo_desde_interrupcion = 99.0
	juego._atacar(EstadosEnemigo.Id.GOLPE, 1, 1.5)
	juego.timer_cooldown = 0.0
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego.estado_enemigo.id == EstadosEnemigo.Id.NOQUEADO, "golpe en el momento justo: lo interrumpe y queda mareado")
	await create_timer(1.4).timeout
	juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	juego._atacar(EstadosEnemigo.Id.GOLPE, 1, 1.5)
	juego.timer_cooldown = 0.0
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego._preparando_ataque, "otra interrupción tan pronto no se puede: aguanta y sigue atacando")
	await create_timer(1.8).timeout
	check(juego.vida_jugador < juego.vida_max_jugador, "el ataque que aguantó llega al jugador")
	juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	juego.golpes_recibidos_seguidos = 0

	print("== Modo furia")
	check(not juego.estrategia.en_furia, "sin furia con vida alta")
	juego.vida_enemigo = juego.vida_max_enemigo * 0.52
	juego.timer_cooldown = 0.0
	juego.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	juego.ejecutar_ataque_jugador("RECTO_DER")
	check(juego.estrategia.en_furia, "entra en furia al bajar del 50 %")
	check(juego._lbl_barra.text.begins_with("MODO FURIA"), "la barra anuncia el modo furia")
	check(juego._estilo_barra.bg_color == juego.COLOR_BARRA_FURIA, "la barra cambia de color")
	var acciones: Array = []
	for i in 30:
		acciones.append(juego.estrategia.elegir_accion_furia())
	var todas_atacan: bool = acciones.all(func(a: Dictionary) -> bool: return a["ataque"] != "")
	var tiempos: Array = acciones.map(func(a: Dictionary) -> float: return a["tiempo"])
	check(todas_atacan, "en furia siempre ataca (sin bloqueos ni burlas)")
	check(tiempos.min() >= 0.35 and tiempos.max() <= 0.6 and tiempos.min() != tiempos.max(), "avisos más cortos y al azar")
	var vida_j: float = juego.vida_jugador
	juego.aplicar_ataque_al_jugador(1)
	check(is_equal_approx(vida_j - juego.vida_jugador, 16.0 * 1.4), "en furia hace +40 % de daño")
	juego.queue_free()
	await esperar(3)

	print("== Estamina y esquiva a tiempo (peleando con cámara)")
	var camara_srv: Node = root.get_node("CamaraEnVivo")
	root.get_node("ChannelData").modo_control = "camara"
	var ej: Node = await abrir_pelea(1)
	check(ej._barra_estamina.visible and ej.estamina == ej.ESTAMINA_MAX, "la barra de estamina se ve llena al empezar")
	# 1) Inclinarse ANTES del aviso ya no sirve.
	camara_srv.recibir_datos({"esquiva": "IZQUIERDA"})
	await esperar(2)
	await create_timer(0.4).timeout
	ej._t_inicio_aviso = ej._reloj   # el rival avisa ahora; el jugador ya estaba inclinado
	var vida_a: float = ej.vida_jugador
	check(ej.aplicar_ataque_al_jugador(1) == "impacto" and ej.vida_jugador < vida_a, "inclinado de antemano: el golpe conecta")
	check(ej.estamina < ej.ESTAMINA_MAX, "quedarse inclinado gasta estamina")
	# 2) Moverse DESPUÉS del aviso sí esquiva y gasta estamina.
	camara_srv.recibir_datos({"esquiva": "CENTRO"})
	await esperar(2)
	ej.estamina = ej.ESTAMINA_MAX
	ej._t_inicio_aviso = ej._reloj
	camara_srv.recibir_datos({"esquiva": "DERECHA"})
	await esperar(2)
	var est_antes: float = ej.estamina
	check(ej.aplicar_ataque_al_jugador(1) == "esquiva", "moverse justo después del aviso: esquiva")
	check(est_antes - ej.estamina >= ej.COSTO_ESQUIVA - 0.01, "cada esquiva gasta estamina")
	# 3) Sin estamina: agotado, no esquiva ni golpea.
	for i in 6:
		ej._t_inicio_esquiva = ej._reloj
		ej._t_inicio_aviso = ej._reloj
		ej.aplicar_ataque_al_jugador(1)
	check(ej.agotado and ej.estamina == 0.0, "tras varias esquivas seguidas queda agotado")
	check(ej.esquiva_actual == "CENTRO", "agotado: el cuerpo vuelve al centro")
	check(ej._lbl_estamina.text.contains("AGOTADO"), "la barra muestra ¡AGOTADO!")
	ej._t_inicio_aviso = ej._reloj
	check(ej.aplicar_ataque_al_jugador(1) == "impacto", "agotado: el golpe del rival conecta")
	var vida_r: float = ej.vida_enemigo
	ej.timer_cooldown = 0.0
	ej.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	ej.ejecutar_ataque_jugador("RECTO_DER")
	check(ej.vida_enemigo == vida_r, "agotado: no puede golpear")
	# 4) Recuperación en el centro.
	camara_srv.recibir_datos({"esquiva": "CENTRO"})
	await create_timer(1.7).timeout
	check(not ej.agotado and ej.estamina >= ej.ESTAMINA_PARA_RECUPERARSE, "en el centro recupera el aire")
	var est_g: float = ej.estamina
	ej.timer_cooldown = 0.0
	ej.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	ej.ejecutar_ataque_jugador("UPPERCUT_DER")
	check(ej.vida_enemigo < vida_r and ej.estamina < est_g, "golpear también gasta un poco de estamina")
	check(ej.get_node_or_null("UI_Combate/PanelCamara") != null, "peleando con cámara se ve el recuadro de la cámara")
	ej.queue_free()
	await esperar(3)

	print("== Elegir cámara o teclado")
	root.get_node("ChannelData").modo_control = "teclado"
	var jt: Node = await abrir_pelea(1)
	check(jt.get_node_or_null("UI_Combate/PanelCamara") == null, "con teclado no aparece el recuadro de la cámara")
	check(jt.get_node("UI_Combate/LiveOverlay").offset_bottom == 425.0, "con teclado el chat queda de su tamaño")
	var vida_t: float = jt.vida_enemigo
	jt.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	camara_srv.recibir_datos({"ataque": "RECTO_DER"})
	camara_srv.recibir_datos({"ataque": "NINGUNO"})
	check(jt.vida_enemigo == vida_t, "con teclado se ignoran los golpes de la cámara")
	jt.queue_free()
	await esperar(3)
	root.get_node("ChannelData").modo_control = "camara"
	var jc: Node = await abrir_pelea(1)
	check(jc.get_node("UI_Combate/LiveOverlay").offset_bottom == 258.0, "con cámara el chat se acorta")
	var panel: Control = jc.get_node("UI_Combate/PanelCamara")
	check(panel.position == Vector2(780, 266) and panel.size == Vector2(360, 234), "el recuadro va debajo del chat, del mismo ancho")
	var aro: Control = panel.avatar.get_parent()
	check(is_equal_approx(aro.position.x + aro.size.x / 2.0, panel.size.x / 2.0) and aro.position.y > panel.size.y - aro.size.y, "el personaje va abajo, justo en el centro")
	var vida_c: float = jc.vida_enemigo
	jc.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	camara_srv.recibir_datos({"ataque": "HOOK_DER", "movimiento": "GANCHO DER"})
	check(jc.vida_enemigo < vida_c, "con cámara los golpes de la cámara sí cuentan")
	camara_srv.recibir_datos({"ataque": "NINGUNO", "defensa": true, "movimiento": "DEFENSA"})
	check(jc.defendiendo, "la defensa de la cámara llega al juego")
	await esperar(2)
	check(panel.lbl_movimiento.text == "DEFENSA" and panel.lbl_estado.text == "Cámara conectada", "el recuadro muestra lo que detecta")
	var img: Image = Image.create(64, 48, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.6, 0.9))
	camara_srv.recibir_cuadro(img.save_jpg_to_buffer())
	await esperar(2)
	check(panel.video.texture != null and panel.video.texture.get_size() == Vector2(64, 48), "la imagen de la cámara se ve en el recuadro")
	await create_timer(1.7).timeout
	check(not jc.usando_camara() and panel.lbl_estado.text == "Sin señal", "si la cámara se corta avisa y vuelve el teclado")
	jc.queue_free()
	await esperar(3)
	root.get_node("ChannelData").modo_control = "teclado"

	print("== Ventana para elegir cómo pelear")
	var tablero: Node = load("res://channel_dashboard.tscn").instantiate()
	root.add_child(tablero)
	await esperar(5)
	tablero.start_live_button.pressed.emit()
	await esperar(2)
	var selector: Node = tablero.get_node_or_null("SelectorControl")
	check(selector != null and not tablero.intro_overlay.visible, "al iniciar el live primero pregunta cómo pelear")
	selector.tarjeta_camara.pressed.emit()
	check(selector.modo == "camara" and selector.tarjeta_camara.button_pressed and not selector.tarjeta_teclado.button_pressed, "se puede elegir la cámara")
	check(selector.boton_detector.visible and selector.lbl_estado_camara.text == "Cámara no detectada", "sin detector avisa y ofrece abrirlo")
	selector.boton_volver.pressed.emit()
	await esperar(2)
	check(tablero.get_node_or_null("SelectorControl") == null and not tablero.start_live_button.disabled, "Volver cierra la ventana")
	tablero.start_live_button.pressed.emit()
	await esperar(2)
	selector = tablero.get_node("SelectorControl")
	selector.tarjeta_teclado.pressed.emit()
	selector.boton_iniciar.pressed.emit()
	await esperar(2)
	check(root.get_node("ChannelData").modo_control == "teclado" and tablero.intro_overlay.visible, "elegir teclado e iniciar: empieza el live")
	tablero.queue_free()
	await esperar(3)

	print("== Teclas nuevas")
	var tec: Entradas.Teclado = Entradas.Teclado.new()
	var golpes: Array[String] = []
	tec.ataque.connect(func(t: String) -> void: golpes.append(t))
	for tecla in [KEY_P, KEY_L, Entradas.Teclado.TECLA_ENIE, KEY_O, KEY_SEMICOLON]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = tecla
		ev.physical_keycode = tecla
		ev.pressed = true
		Input.parse_input_event(ev)
		await esperar(1) # el evento se procesa en el siguiente frame
		tec.actualizar(0.0)
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		await esperar(1)
		tec.actualizar(0.3)
	check(golpes == ["RECTO_DER", "HOOK_IZQ", "HOOK_DER", "UPPERCUT_DER", "HOOK_DER"], "P recto, L gancho izq, Ñ gancho der, O uppercut (y ; = Ñ)")

	print("== Música de pelea")
	var bus_musica: int = AudioServer.get_bus_index("Musica")
	var audio_p: Node = root.get_node("Audio")
	var musical: Node = await abrir_pelea(2)
	check(audio_p._musica_actual == "pelea" and audio_p.existe_musica("pelea"), "suena la música de pelea")
	check(AudioServer.get_bus_volume_db(bus_musica) == 0.0, "a volumen normal durante la pelea")
	await create_timer(1.0).timeout
	var rep_pelea: AudioStreamPlayer = audio_p._musica_a if audio_p._musica_a.playing else audio_p._musica_b
	check(is_equal_approx(rep_pelea.volume_db, -0.8), "la música de pelea suena más fuerte (-0,8 dB)")
	musical.vida_enemigo = 1.0
	musical.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	musical.ejecutar_ataque_jugador("RECTO_DER")
	await create_timer(0.6).timeout
	check(audio_p._musica_actual == "pelea", "al vencer la música no se corta")
	check(AudioServer.get_bus_volume_db(bus_musica) <= -17.0, "al vencer la música baja de volumen")
	musical.fase_actual = musical.Fase.CINEMATICA_FINAL
	musical.queue_free()
	await esperar(3)
	audio_p.musica("intro")
	check(AudioServer.get_bus_volume_db(bus_musica) == 0.0, "la siguiente canción vuelve al volumen normal")
	var jefe_m: Node = await abrir_pelea(3)
	check(audio_p._musica_actual == "pelea", "el nivel 3 también tiene música (usa la de pelea)")
	jefe_m.fase_actual = jefe_m.Fase.CINEMATICA_FINAL
	jefe_m.queue_free()
	await esperar(3)

	print("== K.O. con sonidos y estadísticas con demora")
	var audio: Node = root.get_node("Audio")
	check(audio.duracion("ko_romper") > 1.0 and audio.duracion("ko_desmayo") > 3.0, "los dos sonidos del K.O. existen")
	var pelea: Node = await abrir_pelea(1)
	pelea.vida_enemigo = 5.0
	pelea.cambiar_estado_enemigo(EstadosEnemigo.Id.IDLE)
	pelea.ejecutar_ataque_jugador("UPPERCUT_DER")
	await esperar(2)
	check(pelea.fase_actual == pelea.Fase.KO_RIVAL, "al derrotarlo empieza la secuencia del K.O.")
	check(not pelea.pantalla_cinematica.visible, "las estadísticas no aparecen de inmediato")
	await create_timer(1.6).timeout
	check(not pelea.pantalla_cinematica.visible, "siguen ocultas mientras suena el desmayo")
	await create_timer(5.0).timeout
	check(pelea.pantalla_cinematica.visible and "VICTORIA" in pelea.texto_cinematica.text, "después de los sonidos aparecen las estadísticas")
	pelea.fase_actual = pelea.Fase.CINEMATICA_FINAL # evita que cambie de escena durante la prueba
	pelea.queue_free()
	await esperar(3)

	print("== Simulación: jugador que golpea sin parar (IA real, 15 s)")
	var sim: Node = await abrir_pelea(1)
	sim.timer_ia_enemigo = 1.0
	sim.vida_enemigo = 9999.0  # que la pelea no termine durante la simulación
	sim.vida_max_enemigo = 9999.0
	Engine.time_scale = 3.0
	var ataques_rival: int = 0
	var preparaba: bool = false
	var t: float = 0.0
	while t < 15.0 and sim.fase_actual == sim.Fase.PELEA:
		if sim.timer_cooldown <= 0.0:
			sim.ejecutar_ataque_jugador("RECTO_DER")
		if sim._preparando_ataque and not preparaba:
			ataques_rival += 1
		preparaba = sim._preparando_ataque
		await process_frame
		t += (1.0 / 60.0) * Engine.time_scale
	Engine.time_scale = 1.0
	print("  (el rival lanzó %d ataques; vida del jugador: %.0f de %.0f)" % [ataques_rival, sim.vida_jugador, sim.vida_max_jugador])
	check(ataques_rival >= 3, "aunque el jugador golpee sin parar, el rival ataca varias veces")
	check(sim.vida_jugador < sim.vida_max_jugador, "golpear a lo loco tiene castigo: el jugador recibe daño")
	sim.fase_actual = sim.Fase.CINEMATICA_FINAL
	sim.queue_free()
	await esperar(3)

	print("== Nivel 3")
	var jefe: Node = await abrir_pelea(3)
	check(jefe._lbl_barra.text.ends_with("∞ VIDA INFINITA"), "el jefe muestra vida infinita")
	jefe.vida_enemigo = 1.0
	jefe.ejecutar_ataque_jugador("RECTO_DER")
	check(not jefe.estrategia.en_furia, "el jefe nunca entra en furia")
	jefe.queue_free()
	await esperar(3)

	print("\n" + ("TODO OK" if _fallas == 0 else "%d FALLAS" % _fallas))
	root.get_node("Audio").detener_todo()
	await create_timer(0.3).timeout
	quit(1 if _fallas > 0 else 0)
