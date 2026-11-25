extends SceneTree
## Verifica que la música del menú se cargue y suene.

func _initialize() -> void:
	_correr.call_deferred()

func _correr() -> void:
	var menu: Node = load("res://inicio.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 30:
		await process_frame
	var audio: Node = root.get_node("Audio")
	audio._musica_de_escena_actual()
	for i in 30:
		await process_frame
	var sonando: bool = audio._musica_a.playing or audio._musica_b.playing
	print("musica actual: ", audio._musica_actual, " | sonando: ", sonando)
	var stream: AudioStream = audio._cargar(audio.CARPETA_MUSICA, "menu")
	print("archivo: ", stream, " | duracion: %.1f s" % (stream.get_length() if stream else 0.0))
	quit(0 if sonando else 1)
