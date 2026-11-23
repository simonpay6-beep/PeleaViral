extends SceneTree
## Toma capturas de pantalla de las escenas (para el informe y la página web).
## Ejecutar (con pantalla):  godot -s res://pruebas/capturas.gd -- <carpeta_salida>

var salida: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	salida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	_correr.call_deferred()


func esperar(frames: int) -> void:
	for i in frames:
		await process_frame


func foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(salida.path_join(nombre + ".png"))
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
	var cd: Node = root.get_node("ChannelData")
	await abrir("res://inicio.tscn")
	await foto("01_menu")
	var intro: Node = await abrir("res://phone_intro.tscn")
	await foto("02_telefono")
	intro._start_story_intro()
	await esperar(30)
	await foto("03_historia")
	await abrir("res://netube_platform.tscn")
	await foto("04_netube")
	await abrir("res://channel_dashboard.tscn")
	await foto("05_panel_canal")
	cd.current_video_index = 2
	var juego: Node = await abrir("res://juego.tscn")
	await esperar(60)
	if juego.panel_controles.visible:
		await foto("06_ayuda_controles")
		juego._on_controles_cerrado()
	juego.iniciar_pelea_nivel()
	for i in 8:
		root.get_node("EventBus").evento_combate.emit(["golpe_conecta", "esquivaste", "rival_golpea"][i % 3])
		await esperar(15)
	juego.views_en_vivo = 1350
	await esperar(60)
	await foto("07_pelea")
	quit()
