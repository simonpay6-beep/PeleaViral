extends SceneTree
## Capturas de la propuesta de cambios (legibilidad y personaje).

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
	await esperar(20)
	return escena


func _correr() -> void:
	var intro: Node = await abrir("res://phone_intro.tscn")
	intro._on_phone_clicked()
	await esperar(100)
	await foto("p1_historia_pagina1")
	intro._on_continue_story_pressed()
	await esperar(40)
	await foto("p2_historia_pagina2")
	intro._on_continue_story_pressed()
	await esperar(40)
	await foto("p3_historia_pagina3")

	root.get_node("ChannelData").current_video_index = 1
	await abrir("res://juego.tscn")
	await esperar(40)
	await foto("p4_ayuda_tutorial")

	var menu: Node = await abrir("res://inicio.tscn")
	menu._on_instrucciones_pressed()
	await esperar(10)
	await foto("p5_ayuda_menu")
	quit()
