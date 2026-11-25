extends SceneTree
## Prueba de la pantalla "Crea tu canal" y de la música de la introducción.

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


func _correr() -> void:
	var audio: Node = root.get_node("Audio")
	var router: Node = root.get_node("SceneRouter")
	var datos: Node = root.get_node("ChannelData")

	print("== Música de la introducción")
	router.go("res://phone_intro.tscn")
	await esperar(20)
	check(audio._musica_actual == "intro", "suena 'intro' en la bienvenida")
	var reproductor: AudioStreamPlayer = audio._musica_a if audio._musica_a.playing else audio._musica_b
	check(reproductor.playing, "el reproductor está sonando")
	await esperar(30)
	var pos_antes: float = reproductor.get_playback_position()

	print("== Pantalla Crea tu canal")
	router.go("res://netube_platform.tscn")
	await esperar(20)
	check(audio._musica_actual == "intro" and reproductor.playing, "la canción sigue al pasar a NeTube")
	check(reproductor.get_playback_position() >= pos_antes, "no se reinicia la canción")
	var netube: Node = current_scene
	check(netube.preview_nombre.text == "Tu canal" and netube.preview_usuario.text == "@tucanal", "vista previa vacía por defecto")
	netube._on_confirm_pressed()
	await esperar(2)
	check(netube.error_label.visible, "nombre vacío muestra el aviso")
	check(current_scene == netube, "con nombre vacío no avanza")
	netube.name_input.text = "Pro Gamer 99"
	netube._on_nombre_cambiado("Pro Gamer 99")
	check(netube.preview_nombre.text == "Pro Gamer 99", "el nombre aparece en la vista previa")
	check(netube.preview_usuario.text == "@progamer99", "el @usuario se arma sin espacios")
	check(not netube.error_label.visible, "el aviso se oculta al escribir")
	netube._select_avatar(2)
	check(netube.preview_avatar.texture == netube.avatars[2], "la foto elegida aparece en la vista previa")
	check(netube.botones_avatar[2].text.begins_with("» "), "la tarjeta elegida se marca")
	check(not netube.botones_avatar[0].text.begins_with("» "), "las demás se desmarcan")
	var foto_elegida: Texture2D = netube.avatars[2]
	netube._on_confirm_pressed()
	await esperar(20)
	check(datos.channel_name == "Pro Gamer 99", "guarda el nombre del canal")
	check(datos.avatar_texture == foto_elegida, "guarda la foto elegida")
	check(current_scene.scene_file_path == "res://channel_dashboard.tscn", "pasa al panel del canal")
	check(audio._musica_actual == "intro", "la canción sigue en la configuración del directo")

	print("\n" + ("TODO OK" if _fallas == 0 else "%d FALLAS" % _fallas))
	audio.detener_todo()
	await create_timer(0.3).timeout
	quit(1 if _fallas > 0 else 0)
