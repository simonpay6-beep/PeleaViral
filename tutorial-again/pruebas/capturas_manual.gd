extends SceneTree
## Capturas adicionales para el manual de usuario.
## Ejecutar (con pantalla):  godot -s res://pruebas/capturas_manual.gd -- <carpeta_salida>

var salida: String = ""


func _initialize() -> void:
	salida = OS.get_cmdline_user_args()[0]
	_correr.call_deferred()


func esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("captura: ", nombre)


func abrir(ruta: String) -> Node:
	for n in root.get_children():
		if n.scene_file_path != "":
			n.queue_free()
	await esperar(2)
	var escena: Node = load(ruta).instantiate()
	root.add_child(escena)
	current_scene = escena
	await esperar(30)
	return escena


func _correr() -> void:
	var cd: Node = root.get_node("ChannelData")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://historial_peleas.json"))

	var menu: Node = await abrir("res://inicio.tscn")
	menu._on_instrucciones_pressed()
	await esperar(10)
	await foto("m01_menu_instrucciones")
	menu._on_controles_cerrado()
	menu._on_creditos_pressed()
	await esperar(10)
	await foto("m02_menu_creditos")

	var intro: Node = await abrir("res://phone_intro.tscn")
	intro._on_phone_clicked()
	await esperar(90)
	intro._on_continue_story_pressed()
	await esperar(30)
	await foto("m03_historia_pagina2")

	# Tutorial contra el árbol (video 1)
	cd.current_video_index = 1
	var tut: Node = await abrir("res://juego.tscn")
	tut._on_controles_cerrado()
	tut.ejecutar_ataque_jugador("RECTO_DER")
	await esperar(40)
	await foto("m04_tutorial_arbol")

	# Historia del nivel 1 y victoria con récord
	tut.iniciar_historia_nivel()
	await esperar(40)
	await foto("m05_historia_nivel")
	tut.iniciar_pelea_nivel()
	await esperar(20)
	tut.views_en_vivo = 1200
	tut.finalizar_combate(true)
	await esperar(30)
	await foto("m06_victoria")

	# Guardia rota en el nivel 2
	cd.current_video_index = 2
	var n2: Node = await abrir("res://juego.tscn")
	n2._on_controles_cerrado()
	n2.iniciar_pelea_nivel()
	await esperar(20)
	n2.guardia_rota = true
	n2.timer_ruptura = 3.0
	n2.manos.guardia_rota(true)
	n2.lbl_dialogo_enemigo.text = "¡GUARDIA ROTA! Sin defensa por 3 segundos"
	await esperar(30)
	await foto("m07_guardia_rota")

	# Jefe final (nivel 3)
	cd.current_video_index = 3
	var n3: Node = await abrir("res://juego.tscn")
	n3.iniciar_historia_nivel()
	await esperar(30)
	await foto("m08_historia_jefe")
	n3.iniciar_pelea_nivel()
	await esperar(90)
	await foto("m09_jefe_final")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://historial_peleas.json"))
	quit()
