extends SceneTree
## Captura la pelea con y sin el filtro de daltonismo (para comparar).

func esperar(frames: int) -> void:
	for i in frames:
		await process_frame

func _initialize() -> void:
	_correr.call_deferred()

func _correr() -> void:
	var salida: String = OS.get_cmdline_user_args()[0]
	var juego: Node = load("res://juego.tscn").instantiate()
	root.get_node("ChannelData").current_video_index = 2
	root.add_child(juego)
	await esperar(30)
	juego._on_controles_cerrado()
	juego.iniciar_pelea_nivel()
	await esperar(40)
	for modo in ["", "Daltonismo: Protanopia", "Daltonismo: Deuteranopia", "Daltonismo: Tritanopia"]:
		root.get_node("Accesibilidad").aplicar(modo)
		await esperar(5)
		await RenderingServer.frame_post_draw
		var nombre: String = "08_filtro_" + ("normal" if modo == "" else modo.get_slice(" ", 1).to_lower())
		root.get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
		print("captura: ", nombre)
	quit()
