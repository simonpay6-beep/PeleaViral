class_name FinalDialogo
extends Control
## Base de las escenas finales (periódico y hospital): un cuadro de diálogo con
## la etiqueta de quien habla, la ninfa y un cierre con "FIN".
## Cada final define sus páginas y qué pasa antes y después del diálogo.

const COLOR_NINFA: Color = Color(0.78, 0.45, 0.78)
const NINFA_BRAZOS: Texture2D = preload("res://assets/personajes/ninfa_brazos.png")
const NINFA_HABLANDO: Texture2D = preload("res://assets/personajes/ninfa_hablando.png")

@onready var panel_dialogo: PanelContainer = $PanelDialogo
@onready var texto: RichTextLabel = $PanelDialogo/VBox/Texto
@onready var boton_siguiente: Button = $PanelDialogo/VBox/Botones/Siguiente
@onready var etiqueta: Label = $Etiqueta
@onready var ninfa: TextureRect = $Ninfa
@onready var cierre: ColorRect = $Cierre
@onready var texto_fin: Label = $Cierre/Centro/VBox/TextoFin
## Botón principal del cierre (se busca por nombre: cada final lo ubica donde quiere).
@onready var boton_menu: Button = $Cierre.find_child("BotonMenu")

## Cada página: {"quien": "NINFA" o "", "texto": "...", "pose": "hablando"/"brazos"}
var paginas: Array[Dictionary] = []
var _indice: int = -1
var _dialogo_activo: bool = false
var _ninfa_x_final: float = 0.0


func _ready() -> void:
	panel_dialogo.visible = false
	etiqueta.visible = false
	ninfa.visible = false
	cierre.visible = false
	_ninfa_x_final = ninfa.position.x
	boton_siguiente.pressed.connect(_siguiente)
	boton_menu.pressed.connect(_al_terminar)
	_iniciar()


## Cada final lo redefine: animación de entrada y luego empezar_dialogo().
func _iniciar() -> void:
	empezar_dialogo()


func empezar_dialogo() -> void:
	_dialogo_activo = true
	panel_dialogo.visible = true
	_indice = -1
	_siguiente()


func _unhandled_input(event: InputEvent) -> void:
	if _dialogo_activo and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_siguiente()


func _siguiente() -> void:
	if not _dialogo_activo:
		return
	_indice += 1
	if _indice >= paginas.size():
		_dialogo_activo = false
		panel_dialogo.visible = false
		etiqueta.visible = false
		await al_terminar_dialogo()
		_mostrar_cierre()
		return
	var p: Dictionary = paginas[_indice]
	texto.text = p["texto"]
	texto.modulate.a = 0.0
	create_tween().tween_property(texto, "modulate:a", 1.0, 0.25)
	etiqueta.visible = p["quien"] != ""
	etiqueta.text = p["quien"]
	if p["quien"] != "":
		if not ninfa.visible:
			_entrada_ninfa()
		ninfa.texture = NINFA_BRAZOS if p.get("pose", "hablando") == "brazos" else NINFA_HABLANDO
		_salto(ninfa)
	boton_siguiente.text = "Terminar" if _indice == paginas.size() - 1 else "Siguiente"
	al_mostrar_pagina(_indice)


## Ganchos para cada final.
func al_mostrar_pagina(_i: int) -> void:
	pass


func al_terminar_dialogo() -> void:
	pass


func _al_terminar() -> void:
	ChannelData.reset_campaign()
	SceneRouter.go(SceneRouter.MENU)


func _entrada_ninfa() -> void:
	ninfa.visible = true
	ninfa.position.x = _ninfa_x_final + 380.0
	ninfa.modulate.a = 0.0
	var t: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ninfa, "position:x", _ninfa_x_final, 0.5)
	t.parallel().tween_property(ninfa, "modulate:a", 1.0, 0.3)


func _salto(quien: Control) -> void:
	quien.pivot_offset = Vector2(quien.size.x * 0.5, quien.size.y)
	var t: Tween = create_tween()
	t.tween_property(quien, "scale", Vector2(1.0, 0.96), 0.08)
	t.tween_property(quien, "scale", Vector2.ONE, 0.12)


func _mostrar_cierre() -> void:
	cierre.visible = true
	cierre.modulate.a = 0.0
	create_tween().tween_property(cierre, "modulate:a", 1.0, 1.0)
	boton_menu.grab_focus()
