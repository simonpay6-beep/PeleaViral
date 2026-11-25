extends SceneTree
## Pruebas de la elección de la intro y de los dos finales (periódico y hospital).

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


func a_la_ultima_pagina(intro: Node) -> void:
	intro._start_story_intro()
	while intro.historia.hay_siguiente():
		intro._on_continue_story_pressed()


func _correr() -> void:
	var router: Node = root.get_node("SceneRouter")

	print("== Elección: seguir con mi plan")
	router.go("res://phone_intro.tscn")
	await esperar(5)
	a_la_ultima_pagina(current_scene)
	current_scene._on_continue_story_pressed()
	await create_timer(0.8).timeout
	check(current_scene.scene_file_path == "res://netube_platform.tscn", "el juego sigue normal en NeTube")

	print("== Elección: hacerle caso a la ninfa")
	router.go("res://phone_intro.tscn")
	await esperar(5)
	a_la_ultima_pagina(current_scene)
	current_scene._on_hacer_caso_pressed()
	await create_timer(0.8).timeout
	var per: Node = current_scene
	check(per.scene_file_path == "res://final_periodico.tscn", "pasa al final del periódico")
	check("HOSPITAL" in per.get_node("Periodico/VBox/Titular").text, "el titular habla del hospital")
	check(not per.panel_dialogo.visible, "primero se ve solo el periódico")
	await create_timer(6.0).timeout
	check(per.panel_dialogo.visible and per.ninfa.visible, "después la ninfa da la reflexión")
	for i in per.paginas.size():
		per._siguiente()
	await create_timer(1.2).timeout
	check(per.cierre.visible and per.texto_fin.text.begins_with("FIN"), "termina con FIN")
	per._al_terminar()
	await esperar(5)
	check(current_scene.scene_file_path == "res://inicio.tscn", "vuelve al menú")

	print("== Final del hospital (después del nivel 3)")
	router.go("res://final_hospital.tscn")
	await esperar(5)
	var hos: Node = current_scene
	check(hos.negro.visible, "empieza en negro (abres los ojos)")
	await create_timer(2.4).timeout
	check(hos.panel_dialogo.visible and not hos.etiqueta.visible, "primera página: narración sin etiqueta")
	hos._siguiente()
	check(hos.ninfa.visible and hos.etiqueta.text == "NINFA", "aparece la ninfa y habla")
	while hos._indice < hos.paginas.size() - 1:
		hos._siguiente()
	check(hos.pantalla_telefono.visible, "en la última frase se apaga el teléfono")
	hos._siguiente()
	await create_timer(0.6).timeout
	check(hos.cierre.visible and hos.texto_fin.text.begins_with("FIN DEL JUEGO"), "termina con FIN DEL JUEGO")
	check(hos.boton_inicio.visible and hos.boton_inicio.text == "Volver al menú", "hay botón para volver al menú")
	check(hos.boton_menu.text == "Salir del juego", "y otro para salir del juego")
	hos.boton_inicio.pressed.emit()
	await esperar(5)
	check(current_scene.scene_file_path == "res://inicio.tscn", "el botón lleva al menú principal")

	print("\n" + ("TODO OK" if _fallas == 0 else "%d FALLAS" % _fallas))
	root.get_node("Audio").detener_todo()
	await create_timer(0.3).timeout
	quit(1 if _fallas > 0 else 0)
