extends CanvasLayer

@onready var stream_title_label: Label = $HUDControl/TopStreamBar/HBoxContainer/StreamTitleLabel
@onready var viewers_label: Label = $HUDControl/TopStreamBar/HBoxContainer/ViewersLabel
@onready var points_label: Label = $HUDControl/TopStreamBar/HBoxContainer/PointsLabel
@onready var chat_messages: VBoxContainer = $HUDControl/ChatBoxContainer/MarginContainer/VBoxContainer/ChatScroll/ChatMessages
@onready var chat_scroll: ScrollContainer = $HUDControl/ChatBoxContainer/MarginContainer/VBoxContainer/ChatScroll
@onready var combo_notice_label: Label = $HUDControl/ComboNoticeLabel

var user_names: Array[String] = [
	"GamerPro", "ElPolloFirme", "Kike99", "SoyFan", "NeTuber_Fan",
	"Hater01", "SpeedyG", "LoliGamer", "Bot34", "ElTioNeTube"
]

var idle_comments: Array[String] = [
	"¡Dale con todo!", "Se viene épico", "Buena calidad de stream",
	"¿Dónde compró esa ropa?", "Salúdame porfa", "¡Firme ahí!"
]

var dodge_comments: Array[String] = [
	"¡QUÉ REFLEJOS!", "Ufff casi", "Lo esquivó en la cara jajaja",
	"Matrix total", "¡Clipeen eso!", "Suban las views"
]

var hit_comments: Array[String] = [
	"F", "Eso dolió hasta acá", "Noooo se cayó el stream",
	"Le reiniciaron el Windows", "Cuidado con la guardia"
]

var comment_timer: float = 0.0
var next_comment_delay: float = 2.0

func _ready() -> void:
	combo_notice_label.visible = false
	stream_title_label.text = ChannelData.video_title
	
	ChannelData.stats_updated.connect(_on_stats_updated)
	ChannelData.reset_live_session()
	
	add_chat_message("Sistema", "Transmisión iniciada. ¡Buena suerte!", Color.YELLOW)

func _process(delta: float) -> void:
	comment_timer += delta
	if comment_timer >= next_comment_delay:
		comment_timer = 0.0
		next_comment_delay = randf_range(1.5, 3.5)
		var user: String = user_names.pick_random()
		var comment: String = idle_comments.pick_random()
		add_chat_message(user, comment, Color.WHITE)

func _on_stats_updated(views: int, points: int) -> void:
	viewers_label.text = "👁️ %d viewers" % views
	points_label.text = "⭐ %d pts" % points

func add_chat_message(user: String, text: String, color: Color = Color.WHITE) -> void:
	var msg_label: Label = Label.new()
	msg_label.text = "%s: %s" % [user, text]
	msg_label.modulate = color
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_messages.add_child(msg_label)
	
	if chat_messages.get_child_count() > 10:
		var oldest: Node = chat_messages.get_child(0)
		chat_messages.remove_child(oldest)
		oldest.queue_free()
	
	
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)


func notify_dodge(consecutive: int) -> void:
	var user: String = user_names.pick_random()
	var comment: String = dodge_comments.pick_random()
	add_chat_message(user, comment, Color.GREEN)
	

	combo_notice_label.visible = true
	combo_notice_label.text = "¡ESQUIVA PERFECTA! Racha: x%d" % consecutive
	combo_notice_label.modulate = Color.GREEN
	
	var tween: Tween = create_tween()
	combo_notice_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(combo_notice_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(0.5)
	tween.tween_callback(func(): combo_notice_label.visible = false)


func notify_hit() -> void:
	var user: String = user_names.pick_random()
	var comment: String = hit_comments.pick_random()
	add_chat_message(user, comment, Color.RED)
	
	combo_notice_label.visible = true
	combo_notice_label.text = "¡GOLPE RECIBIDO! Pierdes viewers"
	combo_notice_label.modulate = Color.RED
	
	var tween: Tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func(): combo_notice_label.visible = false)
	
