extends Control
## Menú principal: usa la portada assets/sprites/pv.png. Los botones son
## transparentes y están colocados justo encima de los óvalos dibujados en la
## imagen (JUGAR, INSTRUCCIONES, CREDITOS, SALIR).

@onready var capa_instrucciones: ColorRect = $CapaInstrucciones
@onready var capa_creditos: ColorRect = $CapaCreditos


func _on_jugar_pressed() -> void:
	SceneRouter.go(SceneRouter.INICIO_JUEGO)


func _on_instrucciones_pressed() -> void:
	capa_instrucciones.visible = true


func _on_creditos_pressed() -> void:
	capa_creditos.visible = true


func _on_salir_pressed() -> void:
	SceneRouter.quit_game()


# Señal `cerrado` del panel de controles.
func _on_controles_cerrado() -> void:
	capa_instrucciones.visible = false


func _on_cerrar_creditos_pressed() -> void:
	capa_creditos.visible = false
