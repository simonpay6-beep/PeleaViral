extends SceneTree
## Capturas de la barra de estamina (normal, media y agotado).

var salida: String = ""


func _initialize() -> void:
	salida = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	_correr.call_deferred()


func esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func foto(nombre: String) -> void:
	await esperar(3)
	root.get_texture().get_image().save_png(salida.path_join(nombre + ".png"))


func _correr() -> void:
	root.get_node("ChannelData").current_video_index = 2
	var juego: Node = load("res://juego.tscn").instantiate()
	root.add_child(juego)
	await esperar(5)
	juego.iniciar_pelea_nivel()
	juego.timer_ia_enemigo = 999.0
	await create_timer(1.0).timeout
	await foto("estamina_llena")
	juego.camara.esquiva = "IZQUIERDA"
	juego.estamina = 45.0
	await foto("estamina_media")
	juego.estamina = 0.0
	juego._gastar_estamina(1.0)
	await create_timer(0.1).timeout
	await foto("estamina_agotado")
	quit()
