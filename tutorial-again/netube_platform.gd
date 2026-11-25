extends Control
## Pantalla "Crea tu canal en NeTube".
## A la izquierda el formulario (nombre y foto de perfil) y a la derecha una
## vista previa del canal que se actualiza mientras el jugador escribe.

const RUTA_FORM: String = "MainContent/Fila/CreateChannelPanel/VBoxContainer/"
const RUTA_PREVIEW: String = "MainContent/Fila/PreviewPanel/VBox/"

## Fotos de perfil disponibles (mismo orden que los botones).
const AVATARES: Array[String] = [
	"res://assets/avatares/avatar_gallo.png",
	"res://assets/avatares/avatar_luchador.png",
	"res://assets/avatares/avatar_mosca.png",
]
const COLOR_ELEGIDO: Color = Color(0.89, 0.13, 0.11)
const COLOR_NORMAL: Color = Color(0.35, 0.35, 0.35)

@onready var name_input: LineEdit = get_node(RUTA_FORM + "NameInput")
@onready var error_label: Label = get_node(RUTA_FORM + "ErrorLabel")
@onready var confirm_button: Button = get_node(RUTA_FORM + "ConfirmButton")
@onready var botones_avatar: Array[Button] = [
	get_node(RUTA_FORM + "AvatarGrid/AvatarBtn1"),
	get_node(RUTA_FORM + "AvatarGrid/AvatarBtn2"),
	get_node(RUTA_FORM + "AvatarGrid/AvatarBtn3"),
]
@onready var preview_avatar: TextureRect = get_node(RUTA_PREVIEW + "Perfil/MarcoFoto/PreviewAvatar")
@onready var preview_nombre: Label = get_node(RUTA_PREVIEW + "Perfil/Datos/PreviewNombre")
@onready var preview_usuario: Label = get_node(RUTA_PREVIEW + "Perfil/Datos/PreviewUsuario")

var avatars: Array[Texture2D] = []
var selected_avatar_index: int = 0


func _ready() -> void:
	error_label.visible = false
	for i in AVATARES.size():
		var textura: Texture2D = load(AVATARES[i])
		avatars.append(textura)
		botones_avatar[i].icon = textura
		botones_avatar[i].pressed.connect(_select_avatar.bind(i))

	name_input.text_changed.connect(_on_nombre_cambiado)
	name_input.text_submitted.connect(func(_t: String) -> void: _on_confirm_pressed())
	confirm_button.pressed.connect(_on_confirm_pressed)

	_select_avatar(0)
	_on_nombre_cambiado("")
	name_input.grab_focus()


## Marca la foto elegida con borde rojo y la muestra en la vista previa.
func _select_avatar(index: int) -> void:
	selected_avatar_index = index
	for i in botones_avatar.size():
		var elegido: bool = i == index
		var estilo: StyleBoxFlat = StyleBoxFlat.new()
		estilo.bg_color = Color(0.17, 0.05, 0.05) if elegido else Color(0.1, 0.1, 0.1)
		estilo.border_color = COLOR_ELEGIDO if elegido else COLOR_NORMAL
		estilo.set_border_width_all(5 if elegido else 3)
		estilo.set_corner_radius_all(14)
		estilo.set_content_margin_all(8)
		for estado in ["normal", "hover", "pressed", "focus"]:
			botones_avatar[i].add_theme_stylebox_override(estado, estilo)
		botones_avatar[i].text = ("» " if elegido else "") + botones_avatar[i].text.trim_prefix("» ")
	preview_avatar.texture = avatars[index]


## La vista previa del canal cambia mientras el jugador escribe.
func _on_nombre_cambiado(texto: String) -> void:
	var nombre: String = texto.strip_edges()
	preview_nombre.text = nombre if not nombre.is_empty() else "Tu canal"
	var usuario: String = nombre.replace(" ", "").to_lower()
	preview_usuario.text = "@" + (usuario if not usuario.is_empty() else "tucanal")
	if not nombre.is_empty():
		error_label.visible = false


func _on_confirm_pressed() -> void:
	var channel_name_clean: String = name_input.text.strip_edges()

	if channel_name_clean.is_empty():
		error_label.text = "¡Debes escribir un nombre para tu canal!"
		error_label.visible = true
		name_input.grab_focus()
		return

	error_label.visible = false

	ChannelData.channel_name = channel_name_clean
	if selected_avatar_index < avatars.size():
		ChannelData.avatar_texture = avatars[selected_avatar_index]

	ChannelData.channel_profile_updated.emit()

	SceneRouter.go(SceneRouter.ADMIN_CANAL)
