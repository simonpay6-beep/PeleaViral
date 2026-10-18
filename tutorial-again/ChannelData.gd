extends Node

var channel_name: String = "MiCanal"
var avatar_texture: Texture2D = null
var current_video_index: int = 1 # 1 para Nivel 1, 2 para Nivel 2, etc.

var total_subscribers: int = 0
var total_views: int = 0
var channel_points: int = 0

var video_title: String = "Mi Primer Video"
var selected_filter: String = "Ninguno"
var selected_difficulty: String = "Normal" 

var current_live_views: int = 0
var current_video_points: int = 0
var consecutive_dodges: int = 0
var took_damage_in_level: bool = false

signal stats_updated(views: int, points: int)
signal channel_profile_updated()


func reset_live_session() -> void:
	current_live_views = 10 # Empieza con una base mínima de espectadores
	current_video_points = 0
	consecutive_dodges = 0
	took_damage_in_level = false
	stats_updated.emit(current_live_views, current_video_points)


func register_dodge() -> void:
	consecutive_dodges += 1
	var multiplier: int = 1
	
	if not took_damage_in_level:
		multiplier = 2 # Bonus si mantiene el invicto sin daño
	
	var views_gained: int = (15 + (consecutive_dodges * 5)) * multiplier
	var points_gained: int = 10 * multiplier
	
	current_live_views += views_gained
	current_video_points += points_gained
	
	stats_updated.emit(current_live_views, current_video_points)


func register_hit_taken() -> void:
	took_damage_in_level = true
	consecutive_dodges = 0
	
	current_live_views = int(max(5, current_live_views - 20))
	stats_updated.emit(current_live_views, current_video_points)


func finish_video_session(won: bool) -> void:
	if won:
		var new_subs: int = int(current_live_views * 0.15)
		total_subscribers += new_subs
		total_views += current_live_views
		channel_points += current_video_points
		current_video_index += 1
