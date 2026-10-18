extends Node2D

@onready var button_1: Button = $HITBOX/Button1
@onready var button_2: Button = $HITBOX2/Button2
@onready var button_3: Button = $HITBOX3/Button3
@onready var button_4: Button = $HITBOX4/Button4

@onready var defensebox: Area2D = $DEFENSEBOX
@onready var defensebox2: Area2D = $DEFENSEBOX2
@onready var defensebox3: Area2D = $DEFENSEBOX3
@onready var defensebox4: Area2D = $DEFENSEBOX4
@onready var progress_bar2: ProgressBar = $enemigo_healthbar
@onready var player_hp: Control = $"Player Healthbar"

@export var defending1: bool
@export var defending2: bool
@export var defending3: bool
@export var defending4: bool

func _ready() -> void:
	pass

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	@warning_ignore("unused_variable")
	var mouse_pos = get_global_mouse_position()


func _on_button_1_pressed() -> void:
	_deal_damage_to_enemy(5)

func _on_button_2_pressed() -> void:
	_deal_damage_to_enemy(5)

func _on_button_3_pressed() -> void:
	_deal_damage_to_enemy(5)

func _on_button_4_pressed() -> void:
	_deal_damage_to_enemy(5)

func _deal_damage_to_enemy(amount: float) -> void:
	progress_bar2.value -= amount
	
	ChannelData.current_live_views += 10
	ChannelData.current_video_points += 5
	ChannelData.stats_updated.emit(ChannelData.current_live_views, ChannelData.current_video_points)
	
	if progress_bar2.value <= 0:
		ChannelData.finish_video_session(true)
		get_tree().change_scene_to_file("res://video_results.tscn")


func _on_defensebox_mouse_entered() -> void:
	defending1 = true
	_on_defense_activated(1)

func _on_defensebox_mouse_exited() -> void:
	defending1 = false

func _on_defensebox_2_mouse_entered() -> void:
	defending2 = true
	_on_defense_activated(2)

func _on_defensebox_2_mouse_exited() -> void:
	defending2 = false

func _on_defensebox_3_mouse_entered() -> void:
	defending3 = true
	_on_defense_activated(3)

func _on_defensebox_3_mouse_exited() -> void:
	defending3 = false

func _on_defensebox_4_mouse_entered() -> void:
	defending4 = true
	_on_defense_activated(4)

func _on_defensebox_4_mouse_exited() -> void:
	defending4 = false


func _on_defense_activated(_box_index: int) -> void:
	ChannelData.register_dodge()
	if has_node("LiveOverlay"):
		$LiveOverlay.notify_dodge(ChannelData.consecutive_dodges)

func take_damage_from_enemy(amount: int = 1) -> void:
	ChannelData.register_hit_taken()
	if has_node("LiveOverlay"):
		$LiveOverlay.notify_hit()
	
	if player_hp and player_hp.has_method("take_damage"):
		player_hp.take_damage(amount)
		
