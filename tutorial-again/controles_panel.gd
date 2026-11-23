class_name ControlesPanel
extends PanelContainer
## Panel "Cómo se juega". Se usa en el menú (INSTRUCCIONES) y al inicio del
## tutorial dentro de juego.tscn. Quien lo muestre se suscribe a `cerrado`.

signal cerrado


func _on_cerrar_pressed() -> void:
	cerrado.emit()
