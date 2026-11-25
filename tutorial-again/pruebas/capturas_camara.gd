extends SceneTree
## Captura de la pelea con cámara (el detector de Python debe estar mandando datos)
## y de la ventana para elegir cámara o teclado.

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
	var datos: Node = root.get_node("ChannelData")
	datos.avatar_texture = load("res://assets/avatares/avatar_gallo.png")
	datos.modo_control = "camara"
	datos.current_video_index = 2
	var panel: Node = load("res://channel_dashboard.tscn").instantiate()
	root.add_child(panel)
	await create_timer(1.5).timeout
	panel._elegir_control()
	await create_timer(0.5).timeout
	await foto("elegir_control")
	panel.queue_free()
	await esperar(3)

	var juego: Node = load("res://juego.tscn").instantiate()
	root.add_child(juego)
	await esperar(5)
	juego.iniciar_pelea_nivel()
	juego.timer_ia_enemigo = 999.0
	await create_timer(2.5).timeout
	await foto("pelea_camara")
	print("conectada: ", root.get_node("CamaraEnVivo").conectada(), " movimiento: ", root.get_node("CamaraEnVivo").movimiento)
	quit()
