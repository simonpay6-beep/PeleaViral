extends Control

@onready var avatar_display: TextureRect = $MainVBox/TopProfileBar/AvatarDisplay
@onready var channel_name_label: Label = $MainVBox/TopProfileBar/ChannelInfoVBox/ChannelNameLabel
@onready var stats_label: Label = $MainVBox/TopProfileBar/ChannelInfoVBox/StatsLabel

@onready var current_video_badge: Label = $MainVBox/ConfigCenter/ConfigPanel/Margin/VBoxContainer/CurrentVideoBadge
@onready var video_title_input: LineEdit = $MainVBox/ConfigCenter/ConfigPanel/Margin/VBoxContainer/VideoTitleInput
@onready var filter_options: OptionButton = $MainVBox/ConfigCenter/ConfigPanel/Margin/VBoxContainer/FilterOptions
@onready var difficulty_options: OptionButton = $MainVBox/ConfigCenter/ConfigPanel/Margin/VBoxContainer/DifficultyOptions
@onready var start_live_button: Button = $MainVBox/ConfigCenter/ConfigPanel/Margin/VBoxContainer/StartLiveButton

@onready var intro_overlay: ColorRect = $IntroAnimationOverlay
@onready var status_label: Label = $IntroAnimationOverlay/CenterContainer/VBoxContainer/ProtagonistStatusLabel
@onready var subtext_label: Label = $IntroAnimationOverlay/CenterContainer/VBoxContainer/SubtextLabel

func _ready() -> void:
	intro_overlay.visible = false
	intro_overlay.color = Color(0, 0, 0, 0)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_load_channel_data()
	_populate_dropdowns()
	
	start_live_button.pressed.connect(_on_start_live_pressed)

func _load_channel_data() -> void:
	channel_name_label.text = ChannelData.channel_name
	stats_label.text = "Suscriptores: %d | Visitas totales: %d" % [ChannelData.total_subscribers, ChannelData.total_views]
	
	if ChannelData.avatar_texture:
		avatar_display.texture = ChannelData.avatar_texture
		avatar_display.custom_minimum_size = Vector2(64, 64)
		avatar_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	current_video_badge.text = "Grabando Video #%d de 3" % ChannelData.current_video_index
	video_title_input.text = "Pelea Callejera Salvaje #%d" % ChannelData.current_video_index

func _populate_dropdowns() -> void:
	filter_options.clear()
	filter_options.add_item("Ninguno (Normal)")
	filter_options.add_item("Sepia Retro")
	filter_options.add_item("Blanco y Negro")
	filter_options.add_item("Cyber Glitch")
	
	difficulty_options.clear()
	difficulty_options.add_item("Fácil (Enemigo lento, menos views)")
	difficulty_options.add_item("Normal (Equilibrado)")
	difficulty_options.add_item("Hardcore (Enemigo rápido, x2 views)")
	difficulty_options.select(1) 

func _on_start_live_pressed() -> void:
	start_live_button.disabled = true
	
	ChannelData.video_title = video_title_input.text.strip_edges()
	if ChannelData.video_title.is_empty():
		ChannelData.video_title = "Transmisión Sin Título"
	
	ChannelData.selected_filter = filter_options.get_item_text(filter_options.selected)
	
	match difficulty_options.selected:
		0:
			ChannelData.selected_difficulty = "Fácil"
		1:
			ChannelData.selected_difficulty = "Normal"
		2:
			ChannelData.selected_difficulty = "Hardcore"
	
	_play_pre_stream_intro()

func _play_pre_stream_intro() -> void:
	intro_overlay.visible = true
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var contextual_intro: String = ""
	match ChannelData.current_video_index:
		1:
			contextual_intro = "Acomodando el trípode... Tu primer rival se acerca al callejón."
		2:
			contextual_intro = "Las notificaciones suben... Esta vez te enfrentas a alguien más pesado."
		3:
			contextual_intro = "La transmisión final. Miles de personas te miran en directo."
		_:
			contextual_intro = "Encendiendo luces y verificando bitrate..."
	
	status_label.text = contextual_intro
	subtext_label.text = "Conectando al servidor NeTube..."
	
	var tween: Tween = create_tween()
	tween.tween_property(intro_overlay, "color:a", 0.95, 0.4)
	tween.tween_interval(1.6)
	tween.tween_callback(func():
		status_label.text = "¡EN VIVO EN 3, 2, 1!"
		subtext_label.text = "¡Esquiva los golpes para ganar views!"
	)
	tween.tween_interval(1.2)
	tween.tween_property(intro_overlay, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://fight_beta_2.tscn")
	)
