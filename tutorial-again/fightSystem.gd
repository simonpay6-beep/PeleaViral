extends Node2D

var health:float = 100.0;
@onready var timer: Timer = $Timer
@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var area_2d: Area2D = $Area2D
@onready var button: Button = $Area2D/Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var screen_size = get_viewport_rect();
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	gameOver();
	pass


func _on_button_pressed() -> void:
	progress_bar.value = progress_bar.value - 10;
	pass # Replace with function body.
	
func gameOver():
	if progress_bar.value == 0:
		print("Ganaste!")
		get_tree().exit()
