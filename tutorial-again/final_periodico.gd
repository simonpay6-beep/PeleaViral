extends FinalDialogo
## Final "le hiciste caso a la ninfa": aparece un periódico girando con la
## noticia de un creador en el hospital por grabar sus propias peleas, y la
## ninfa da la reflexión. Así pudo terminar tu historia si prendías la cámara.

@onready var periodico: PanelContainer = $Periodico


func _ready() -> void:
	paginas = [
		{"quien": "NINFA", "texto": "Así pudo terminar tu historia si prendías esa cámara.", "pose": "brazos"},
		{"quien": "NINFA", "texto": "Muchos creadores se lastiman, o lastiman a otros, solo por conseguir unas visitas más."},
		{"quien": "NINFA", "texto": "Tú elegiste escuchar. La verdadera victoria no está en hacerse viral, sino en saber cuándo apagar la cámara."},
	]
	super._ready()


func _iniciar() -> void:
	# El periódico entra girando, como en las películas.
	periodico.modulate.a = 0.0
	await get_tree().process_frame  # esperar a que Godot acomode el texto antes de medirlo
	periodico.pivot_offset = periodico.size / 2.0
	periodico.modulate.a = 1.0
	periodico.rotation_degrees = -720.0
	periodico.scale = Vector2(0.05, 0.05)
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(periodico, "rotation_degrees", -3.0, 1.3)
	t.parallel().tween_property(periodico, "scale", Vector2.ONE, 1.3)
	await t.finished
	await get_tree().create_timer(3.5).timeout
	# Se corre hacia la izquierda para dejar lugar a la ninfa y al diálogo.
	var t2: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(periodico, "position:y", periodico.position.y - 70.0, 0.6)
	t2.parallel().tween_property(periodico, "scale", Vector2(0.78, 0.78), 0.6)
	t2.parallel().tween_property(periodico, "position:x", periodico.position.x - 150.0, 0.6)
	await t2.finished
	empezar_dialogo()


func al_terminar_dialogo() -> void:
	texto_fin.text = "FIN\n\nElegiste tu salud antes que las visitas.\nGracias por jugar."
