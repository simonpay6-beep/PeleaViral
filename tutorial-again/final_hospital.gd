extends FinalDialogo
## Final del juego (después de caer ante El Algoritmo): despiertas en una cama
## de hospital, en primera persona, y la ninfa te da la reflexión final.

## Al terminar se puede volver al menú o salir del juego.

@onready var negro: ColorRect = $Negro
@onready var boton_inicio: Button = $Cierre/Centro/VBox/Botones/BotonInicio
@onready var pantalla_telefono: ColorRect = $PantallaTelefono


func _ready() -> void:
	paginas = [
		{"quien": "", "texto": "Despiertas en una cama de hospital. La transmisión se cortó en el golpe 10..."},
		{"quien": "NINFA", "texto": "¡Por fin despertaste! Me tenías muy preocupada.", "pose": "brazos"},
		{"quien": "NINFA", "texto": "Empezaste golpeando un árbol por deporte, pero la obsesión por las visitas, los likes y la aprobación te arrastró a pelear en la calle."},
		{"quien": "NINFA", "texto": "Cuando peleas solo para alimentar las vistas de otros, siempre aparece un rival imposible que no puedes derrotar."},
		{"quien": "NINFA", "texto": "La verdadera victoria no está en ganar peleas por fama en internet, sino en saber cuándo apagar la cámara."},
	]
	super._ready()
	boton_inicio.pressed.connect(_volver_al_menu)


func _iniciar() -> void:
	# Abres los ojos: el negro se desvanece despacio.
	negro.visible = true
	negro.color.a = 1.0
	var t: Tween = create_tween()
	t.tween_property(negro, "color:a", 0.0, 2.0)
	await t.finished
	negro.visible = false
	empezar_dialogo()


func al_mostrar_pagina(i: int) -> void:
	# En la última frase, la pantalla del teléfono se apaga.
	if i == paginas.size() - 1:
		pantalla_telefono.visible = true
		pantalla_telefono.color.a = 0.0
		create_tween().tween_property(pantalla_telefono, "color:a", 1.0, 1.2)


func al_terminar_dialogo() -> void:
	texto_fin.text = "FIN DEL JUEGO\n\nGracias por jugar."
	await get_tree().create_timer(0.3).timeout


func _mostrar_cierre() -> void:
	super._mostrar_cierre()
	boton_inicio.grab_focus()


## Botón "Volver al menú": reinicia el canal y vuelve al menú principal.
func _volver_al_menu() -> void:
	ChannelData.reset_campaign()
	SceneRouter.go(SceneRouter.MENU)


## Botón "Salir del juego".
func _al_terminar() -> void:
	ChannelData.reset_campaign()
	SceneRouter.quit_game()
