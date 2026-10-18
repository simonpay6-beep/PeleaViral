extends Control

@onready var name_input: LineEdit = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/NameInput
@onready var selected_preview: TextureRect = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/SelectedPreview
@onready var error_label: Label = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/ErrorLabel
@onready var confirm_button: Button = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/ConfirmButton

@onready var avatar_btn_1: Button = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/AvatarGrid/AvatarBtn1
@onready var avatar_btn_2: Button = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/AvatarGrid/AvatarBtn2
@onready var avatar_btn_3: Button = $MainContent/CreateChannelPanel/MarginContainer/VBoxContainer/AvatarGrid/AvatarBtn3

var avatars: Array[Texture2D] = []
var selected_avatar_index: int = 0

func _ready() -> void:
	error_label.visible = false
	
	_setup_custom_cursor()
	
	
	var avatar1: Texture2D = load("res://Screenshot 2026-09-12 at 17-01-40 pollo - Google Search.png")
	var avatar2: Texture2D = load("res://assets/sprites/animations;lv1/idle1.png")
	var avatar3: Texture2D = load("res://assets/sprites/animations;lv1/moscas1.png")
	
	avatars = [avatar1, avatar2, avatar3]
	
	_select_avatar(0)
	
	avatar_btn_1.pressed.connect(func(): _select_avatar(0))
	avatar_btn_2.pressed.connect(func(): _select_avatar(1))
	avatar_btn_3.pressed.connect(func(): _select_avatar(2))
	
	confirm_button.pressed.connect(_on_confirm_pressed)

func _setup_custom_cursor() -> void:
	var cursor_img: Texture2D = load("res://icon.svg")
	if cursor_img:
		Input.set_custom_mouse_cursor(cursor_img, Input.CURSOR_ARROW, Vector2(16, 16))

func _select_avatar(index: int) -> void:
	selected_avatar_index = index
	if index < avatars.size() and avatars[index] != null:
		selected_preview.texture = avatars[index]
		selected_preview.custom_minimum_size = Vector2(80, 80)
		selected_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		selected_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _on_confirm_pressed() -> void:
	var channel_name_clean: String = name_input.text.strip_edges()
	
	if channel_name_clean.is_empty():
		error_label.text = "¡Debes escribir un nombre para tu canal!"
		error_label.visible = true
		return
	
	error_label.visible = false
	
	ChannelData.channel_name = channel_name_clean
	if selected_avatar_index < avatars.size():
		ChannelData.avatar_texture = avatars[selected_avatar_index]
	
	ChannelData.channel_profile_updated.emit()
	
	get_tree().change_scene_to_file("res://channel_dashboard.tscn")
