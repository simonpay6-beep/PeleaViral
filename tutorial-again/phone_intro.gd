extends Control

@onready var phone_container: CenterContainer = $PhoneContainer
@onready var phone_button: Button = $PhoneContainer/PhoneButton
@onready var screen_light: ColorRect = $PhoneContainer/PhoneButton/ScreenLight
@onready var story_panel: PanelContainer = $StoryPanel
@onready var story_text: Label = $StoryPanel/VBoxContainer/StoryText
@onready var continue_button: Button = $StoryPanel/VBoxContainer/ContinueButton
@onready var flash_overlay: ColorRect = $FlashOverlay

# Lista de textos para la pequeña animación/explicación de historia
var story_lines: Array[String] = [
	"Este eres tú: un creador novato con ganas de hacerse viral a cualquier costo.",
	"El algoritmo es salvaje y la competencia no perdona.",
	"Tu única salida: prender cámara en NeTube y demostrar tus reflejos en vivo."
]
var current_story_index: int = 0
var is_phone_activated: bool = false

func _ready() -> void:
	screen_light.visible = false
	story_panel.visible = false
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	phone_button.pressed.connect(_on_phone_clicked)
	continue_button.pressed.connect(_on_continue_story_pressed)

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
	current_story_index = 0
	_show_current_story_line()

func _show_current_story_line() -> void:
	story_text.text = story_lines[current_story_index]
	
	story_text.modulate.a = 0.0
	var text_tween: Tween = create_tween()
	text_tween.tween_property(story_text, "modulate:a", 1.0, 0.25)
	
	if current_story_index == story_lines.size() - 1:
		continue_button.text = "Abrir NeTube"
	else:
		continue_button.text = "Siguiente"

func _on_continue_story_pressed() -> void:
	current_story_index += 1
	if current_story_index < story_lines.size():
		_show_current_story_line()
	else:
		_transition_to_netube()

func _transition_to_netube() -> void:
	continue_button.disabled = true
	var exit_tween: Tween = create_tween()
	exit_tween.tween_property(flash_overlay, "color:a", 1.0, 0.35)
	exit_tween.tween_callback(func():
		get_tree().change_scene_to_file("res://netube_platform.tscn")
		)
