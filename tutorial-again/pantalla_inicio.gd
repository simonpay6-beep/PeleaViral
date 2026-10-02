extends Node2D
@onready var jugar: Button = $JUGAR


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	



func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file("res://level_1.tscn");
	


func _on_instrucciones_pressed() -> void:
	get_tree().change_scene_to_file("res://PLACEHOLDER.tscn");


func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://PLACEHOLDER.tscn");


func _on_salir_pressed() -> void:
	get_tree().quit()
