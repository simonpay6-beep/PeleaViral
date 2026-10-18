extends Control

@onready var video_title_label: Label = $ContentCenter/ResultsPanel/Margin/VBoxContainer/VideoTitleLabel
@onready var views_value: Label = $ContentCenter/ResultsPanel/Margin/VBoxContainer/StatsGrid/ViewsValue
@onready var subs_value: Label = $ContentCenter/ResultsPanel/Margin/VBoxContainer/StatsGrid/SubsValue
@onready var points_value: Label = $ContentCenter/ResultsPanel/Margin/VBoxContainer/StatsGrid/PointsValue
@onready var message_label: Label = $ContentCenter/ResultsPanel/Margin/VBoxContainer/MessageLabel
@onready var action_button: Button = $ContentCenter/ResultsPanel/Margin/VBoxContainer/ActionButton

# Sección de créditos finales
@onready var credits_overlay: ColorRect = $CreditsOverlay
@onready var final_stats_label: Label = $CreditsOverlay/CenterContainer/VBoxContainer/FinalStatsLabel
@onready var restart_button: Button = $CreditsOverlay/CenterContainer/VBoxContainer/RestartButton

func _ready() -> void:
	credits_overlay.visible = false
	_display_video_summary()
	action_button.pressed.connect(_on_action_button_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

func _display_video_summary() -> void:
	video_title_label.text = ChannelData.video_title
	
	views_value.text = str(ChannelData.current_live_views)
	var earned_subs: int = int(ChannelData.current_live_views * 0.15)
	subs_value.text = "+%d" % earned_subs
	points_value.text = "+%d pts" % ChannelData.current_video_points
	
	if not ChannelData.took_damage_in_level:
		message_label.text = "🔥 ¡IMPECABLE! Terminaste el directo sin recibir un solo golpe. El algoritmo recomendó tu video a miles."
		message_label.modulate = Color.GOLD
	else:
		message_label.text = "📈 Buen directo. Recibiste algunos golpes, pero la audiencia disfrutó la tensión."
		message_label.modulate = Color.WHITE
	
	if ChannelData.current_video_index <= 3:
		action_button.text = "Ir al Estudio (Preparar Video #%d)" % ChannelData.current_video_index
	else:
		action_button.text = "Ver Estadísticas Finales y Créditos"

func _on_action_button_pressed() -> void:
	if ChannelData.current_video_index <= 3:
		get_tree().change_scene_to_file("res://channel_dashboard.tscn")
	else:
		_show_credits()

func _show_credits() -> void:
	credits_overlay.visible = true
	credits_overlay.modulate.a = 0.0
	
	final_stats_label.text = "Canal: %s\nTotal Suscriptores: %d\nTotal Visitas: %d\nPuntos de Creador: %d" % [
		ChannelData.channel_name,
		ChannelData.total_subscribers,
		ChannelData.total_views,
		ChannelData.channel_points
	]
	
	var tween: Tween = create_tween()
	tween.tween_property(credits_overlay, "modulate:a", 1.0, 0.5)

func _on_restart_pressed() -> void:
	ChannelData.total_subscribers = 0
	ChannelData.total_views = 0
	ChannelData.channel_points = 0
	ChannelData.current_video_index = 1
	
	get_tree().change_scene_to_file("res://phone_intro.tscn")
