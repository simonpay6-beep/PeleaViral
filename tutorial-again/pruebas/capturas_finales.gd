extends SceneTree
## Capturas de la elección de la intro y de los dos finales.

var salida: String = ""


func _initialize() -> void:
	salida = OS.get_cmdline_user_args()[0]
	_correr.call_deferred()


func esperar(n: int) -> void:
	for i in n:
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
	await esperar(10)
	return escena


func _correr() -> void:
	var intro: Node = await abrir("res://phone_intro.tscn")
	intro._start_story_intro()
	for i in 3:
		intro._on_continue_story_pressed()
	await create_timer(0.8).timeout
	await foto("f1_ninfa_entra")
	intro._on_continue_story_pressed()
	intro._on_continue_story_pressed()
	await create_timer(0.6).timeout
	await foto("f2_eleccion")

	var per: Node = await abrir("res://final_periodico.tscn")
	await create_timer(2.2).timeout
	await foto("f3_periodico")
	await create_timer(4.0).timeout
	await foto("f4_periodico_reflexion")

	var hos: Node = await abrir("res://final_hospital.tscn")
	await create_timer(2.4).timeout
	await foto("f5_hospital_despiertas")
	hos._siguiente()
	hos._siguiente()
	await create_timer(0.8).timeout
	await foto("f6_hospital_ninfa")
	quit()
