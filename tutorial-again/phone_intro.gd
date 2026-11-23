extends Control

@onready var phone_container: CenterContainer = $PhoneContainer
@onready var phone_button: TextureButton = $PhoneContainer/PhoneButton
@onready var screen_light: Sprite2D = $PhoneContainer/PhoneButton/ScreenLight
@onready var story_panel: PanelContainer = $StoryPanel
@onready var story_text: RichTextLabel = $StoryPanel/VBoxContainer/StoryText
@onready var continue_button: Button = $StoryPanel/VBoxContainer/ContinueButton
@onready var flash_overlay: ColorRect = $FlashOverlay

# Lista de textos para la pequeña animación/explicación de historia
var story_lines: Array[String] = [
	"Este eres tú: un creador novato con ganas de hacerse viral a cualquier costo.",
	"El algoritmo es salvaje y la competencia no perdona.",
	"Tu única salida: prender cámara en NeTube y demostrar tus reflejos en vivo."
]
## Páginas de la historia en una lista doblemente enlazada (TAD ListaDoble):
## "Siguiente" avanza y "Anterior" retrocede, ambos en O(1).
var historia: ListaDoble = ListaDoble.desde(story_lines)
var back_button: Button
var is_phone_activated: bool = false

func _ready() -> void:
	screen_light.visible = false
	story_panel.visible = false
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	phone_button.pressed.connect(_on_phone_clicked)
	continue_button.pressed.connect(_on_continue_story_pressed)

	# Botón "Anterior" creado por código, justo antes de "Siguiente".
	back_button = Button.new()
	back_button.text = "Anterior"
	back_button.visible = false
	back_button.pressed.connect(_on_back_story_pressed)
	continue_button.get_parent().add_child(back_button)
	continue_button.get_parent().move_child(back_button, continue_button.get_index())

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
	historia.ir_al_inicio()
	_show_current_story_line()

func _show_current_story_line() -> void:
	story_text.text = str(historia.actual())
	back_button.visible = historia.hay_anterior()
	
	story_text.modulate.a = 0.0
	var text_tween: Tween = create_tween()
	text_tween.tween_property(story_text, "modulate:a", 1.0, 0.25)
	
	if not historia.hay_siguiente():
		continue_button.text = "Abrir NeTube"
	else:
		continue_button.text = "Siguiente"

func _on_continue_story_pressed() -> void:
	if historia.hay_siguiente():
		historia.avanzar()
		_show_current_story_line()
	else:
		_transition_to_netube()


func _on_back_story_pressed() -> void:
	historia.retroceder()
	_show_current_story_line()

func _transition_to_netube() -> void:
	continue_button.disabled = true
	back_button.disabled = true
	var exit_tween: Tween = create_tween()
	exit_tween.tween_property(flash_overlay, "color:a", 1.0, 0.35)
	exit_tween.tween_callback(func():
		SceneRouter.go(SceneRouter.NETUBE)
		)
