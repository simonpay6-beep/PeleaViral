extends Control
## Introducción: el teléfono, la historia del creador (el gallo) y la ninfa,
## que le pide no pelear por visitas. El jugador elige:
##   - "Hacerle caso"      -> final del periódico (termina el juego)
##   - "Seguir con mi plan" -> NeTube, el juego sigue normal

@onready var phone_container: CenterContainer = $PhoneContainer
@onready var phone_button: TextureButton = $PhoneContainer/PhoneButton
@onready var screen_light: Sprite2D = $PhoneContainer/PhoneButton/ScreenLight
@onready var story_panel: PanelContainer = $StoryPanel
@onready var story_text: RichTextLabel = $StoryPanel/VBoxContainer/StoryText
@onready var continue_button: Button = $StoryPanel/VBoxContainer/Botones/ContinueButton
@onready var personaje: TextureRect = $Personaje
@onready var ninfa: TextureRect = $Ninfa
@onready var nombre_hablante: Label = $NombreHablante
@onready var flash_overlay: ColorRect = $FlashOverlay

## Poses del gallo (el creador de contenido) y de la ninfa.
const POSE_BRAZOS: Texture2D = preload("res://assets/personajes/creador_brazos.png")
const POSE_HABLANDO: Texture2D = preload("res://assets/personajes/creador_hablando.png")
const NINFA_BRAZOS: Texture2D = preload("res://assets/personajes/ninfa_brazos.png")
const NINFA_HABLANDO: Texture2D = preload("res://assets/personajes/ninfa_hablando.png")

const GALLO: String = "TÚ"
const NINFA: String = "NINFA"
const COLOR_GALLO: Color = Color(0.89, 0.13, 0.11)
const COLOR_NINFA: Color = Color(0.78, 0.45, 0.78)

## Páginas de la historia: quién habla y qué dice.
var story_lines: Array[Dictionary] = [
	{"quien": GALLO, "texto": "Este eres tú: un creador novato con ganas de hacerse viral a cualquier costo."},
	{"quien": GALLO, "texto": "El algoritmo es salvaje y la competencia no perdona."},
	{"quien": GALLO, "texto": "Tu única salida: prender cámara en NeTube y demostrar tus reflejos en vivo."},
	{"quien": NINFA, "texto": "¡Espera! ¿De verdad vas a pelear en la calle solo por unas visitas?"},
	{"quien": NINFA, "texto": "Te pueden lastimar de verdad. Ningún like vale más que tu salud."},
	{"quien": NINFA, "texto": "Todavía estás a tiempo de no prender la cámara. ¿Me vas a hacer caso?"},
]
## Páginas de la historia en una lista doblemente enlazada (TAD ListaDoble):
## "Siguiente" avanza y "Anterior" retrocede, ambos en O(1).
var historia: ListaDoble = ListaDoble.desde(story_lines)
var back_button: Button
var caso_button: Button
var is_phone_activated: bool = false
var _ninfa_en_escena: bool = false
var _ninfa_x_final: float = 0.0


func _ready() -> void:
	screen_light.visible = false
	story_panel.visible = false
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	phone_button.pressed.connect(_on_phone_clicked)
	continue_button.pressed.connect(_on_continue_story_pressed)

	# Botones creados por código: "Anterior" y la elección "Hacerle caso".
	back_button = Button.new()
	back_button.text = "Anterior"
	back_button.visible = false
	back_button.pressed.connect(_on_back_story_pressed)
	caso_button = Button.new()
	caso_button.text = "Hacerle caso"
	caso_button.visible = false
	caso_button.pressed.connect(_on_hacer_caso_pressed)
	var fila: Node = continue_button.get_parent()
	fila.add_child(back_button)
	fila.move_child(back_button, continue_button.get_index())
	fila.add_child(caso_button)
	fila.move_child(caso_button, continue_button.get_index())
	_ninfa_x_final = ninfa.position.x


func _on_phone_clicked() -> void:
	if is_phone_activated:
		return
	is_phone_activated = true
	phone_button.disabled = true

	screen_light.visible = true
	screen_light.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.tween_property(screen_light, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(phone_button, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_overlay, "color:a", 0.9, 0.25)

	tween.tween_callback(func():
		phone_container.visible = false
		_start_story_intro()
	)

	tween.tween_property(flash_overlay, "color:a", 0.0, 0.3)


func _start_story_intro() -> void:
	story_panel.visible = true
	nombre_hablante.visible = true
	historia.ir_al_inicio()
	_show_current_story_line()
	_entrada_personaje()


## El gallo entra deslizándose desde la izquierda.
func _entrada_personaje() -> void:
	var x_final: float = personaje.position.x
	personaje.visible = true
	personaje.position.x = x_final - 360.0
	personaje.modulate.a = 0.0
	var t: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(personaje, "position:x", x_final, 0.45)
	t.parallel().tween_property(personaje, "modulate:a", 1.0, 0.3)


## La ninfa entra deslizándose desde la derecha; el cuadro de diálogo se achica.
func _mostrar_ninfa(visible_ahora: bool) -> void:
	if visible_ahora == _ninfa_en_escena:
		return
	_ninfa_en_escena = visible_ahora
	story_panel.offset_right = -320.0 if visible_ahora else -36.0
	if visible_ahora:
		ninfa.visible = true
		ninfa.position.x = _ninfa_x_final + 360.0
		ninfa.modulate.a = 0.0
		var t: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(ninfa, "position:x", _ninfa_x_final, 0.45)
		t.parallel().tween_property(ninfa, "modulate:a", 1.0, 0.3)
	else:
		ninfa.visible = false


func _show_current_story_line() -> void:
	var pagina: Dictionary = historia.actual()
	var habla_ninfa: bool = pagina["quien"] == NINFA
	story_text.text = pagina["texto"]
	back_button.visible = historia.hay_anterior()
	_mostrar_ninfa(habla_ninfa or historia.indice() >= 3)

	# Etiqueta con el nombre de quien habla.
	nombre_hablante.text = pagina["quien"]
	var estilo: StyleBoxFlat = nombre_hablante.get_theme_stylebox("normal").duplicate()
	estilo.bg_color = COLOR_NINFA if habla_ninfa else COLOR_GALLO
	nombre_hablante.add_theme_stylebox_override("normal", estilo)

	# Poses: quien habla se ve brillante y "salta"; el otro queda en segundo plano.
	if habla_ninfa:
		personaje.texture = POSE_BRAZOS
		ninfa.texture = NINFA_HABLANDO
		personaje.modulate = Color(0.6, 0.6, 0.65)
		ninfa.modulate = Color.WHITE
		_salto(ninfa)
	else:
		personaje.texture = POSE_BRAZOS if historia.indice() == 0 else POSE_HABLANDO
		personaje.modulate = Color.WHITE
		_salto(personaje)

	story_text.modulate.a = 0.0
	var text_tween: Tween = create_tween()
	text_tween.tween_property(story_text, "modulate:a", 1.0, 0.25)

	# En la última página, el jugador elige.
	var es_eleccion: bool = not historia.hay_siguiente()
	caso_button.visible = es_eleccion
	continue_button.text = "Seguir con mi plan" if es_eleccion else "Siguiente"


func _salto(quien: TextureRect) -> void:
	quien.pivot_offset = Vector2(quien.size.x * 0.5, quien.size.y)
	var salto: Tween = create_tween()
	salto.tween_property(quien, "scale", Vector2(1.0, 0.96), 0.08)
	salto.tween_property(quien, "scale", Vector2.ONE, 0.12)


func _on_continue_story_pressed() -> void:
	if historia.hay_siguiente():
		historia.avanzar()
		_show_current_story_line()
	else:
		_salir_a(SceneRouter.NETUBE)


func _on_back_story_pressed() -> void:
	historia.retroceder()
	_show_current_story_line()


## El jugador le hace caso a la ninfa: final del periódico.
func _on_hacer_caso_pressed() -> void:
	_salir_a(SceneRouter.FINAL_PERIODICO)


func _salir_a(ruta: String) -> void:
	continue_button.disabled = true
	back_button.disabled = true
	caso_button.disabled = true
	var exit_tween: Tween = create_tween()
	exit_tween.tween_property(flash_overlay, "color:a", 1.0, 0.35)
	exit_tween.tween_callback(func(): SceneRouter.go(ruta))
