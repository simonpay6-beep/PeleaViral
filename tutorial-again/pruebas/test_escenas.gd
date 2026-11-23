extends SceneTree
## Prueba de integración: abre las escenas modificadas y simula al jugador.
## Ejecutar:  godot --headless -s res://pruebas/test_escenas.gd

var _fallas: int = 0


func check(cond: bool, nombre: String) -> void:
	print(("  OK   " if cond else "  FALLA ") + nombre)
	if not cond:
		_fallas += 1


func esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	print("== phone_intro: historia con lista doble")
	var intro: Node = load("res://phone_intro.tscn").instantiate()
	root.add_child(intro)
	await esperar(2)
	intro._start_story_intro()
	check(intro.story_text.text.begins_with("Este eres tú") and not intro.back_button.visible, "página 1 sin botón Anterior")
	intro._on_continue_story_pressed()
	check(intro.story_text.text.begins_with("El algoritmo") and intro.back_button.visible, "Siguiente -> página 2")
	intro._on_back_story_pressed()
	check(intro.story_text.text.begins_with("Este eres tú"), "Anterior -> página 1")
	intro._on_back_story_pressed()
	check(intro.story_text.text.begins_with("Este eres tú"), "Anterior en la página 1 no rompe nada")
	intro._on_continue_story_pressed()
	intro._on_continue_story_pressed()
	check(intro.continue_button.text == "Abrir NeTube", "última página")
	intro.queue_free()
	await esperar(2)

	print("== live_overlay: chat con cola")
	var overlay: Node = load("res://live_overlay.tscn").instantiate()
	root.add_child(overlay)
	await esperar(2)
	for i in 60:
		root.get_node("EventBus").chat_message.emit("Sistema", "mensaje %d" % i)
	await esperar(3)
	check(overlay._filas.tamano() == overlay.MAX_MENSAJES, "la cola se queda en %d mensajes" % overlay.MAX_MENSAJES)
	check(overlay.chat_lista.get_child_count() == overlay.MAX_MENSAJES, "en pantalla también %d" % overlay.MAX_MENSAJES)
	var primero: RichTextLabel = overlay.chat_lista.get_child(0)
	check("mensaje 20" in primero.text, "salieron los más antiguos (FIFO)")
	overlay.queue_free()
	await esperar(2)

	print("== juego: comentarios en ronda y récord en archivo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HistorialPeleas.RUTA))
	var juego: Node = load("res://juego.tscn").instantiate()
	root.add_child(juego)
	await esperar(5)
	var vistos: Array = []
	for i in juego.turno_espectadores.tamano():
		vistos.append(juego.turno_espectadores.siguiente())
	var sin_repetir: bool = true
	for u in vistos:
		if vistos.count(u) != 1:
			sin_repetir = false
	check(sin_repetir, "una ronda completa pasa por cada espectador una vez")
	juego.generar_comentario_ambiental()
	juego.views_en_vivo = 900
	juego.finalizar_combate(true)
	await esperar(2)
	check("NUEVO RÉCORD" in juego.texto_cinematica.text, "primer combate = nuevo récord")
	check(HistorialPeleas.new().mejor_views(juego.nivel_actual) >= 900, "récord guardado en archivo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HistorialPeleas.RUTA))
	juego.queue_free()
	await esperar(2)

	print("\n" + ("TODO OK" if _fallas == 0 else "%d FALLAS" % _fallas))
	quit(1 if _fallas > 0 else 0)
