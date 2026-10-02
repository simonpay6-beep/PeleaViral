extends Control
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var anima: AnimatedSprite2D = $AnimatedSprite2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	progress_bar.value = 100.0;
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	health_state_animation();
	
func health_state_animation():
	if progress_bar.value <= 100 and progress_bar.value > 80:
		anima.play("bateria1");
	elif progress_bar.value <= 80 and progress_bar.value > 60:
		anima.play("bateria2");
	elif progress_bar.value <= 60 and progress_bar.value > 40:
		anima.play("bateria3");
	elif progress_bar.value <= 40 and progress_bar.value > 20:
		anima.play("bateria4");
	elif progress_bar.value <= 20 and progress_bar.value > 0:
		anima.play("bateria5");
	elif progress_bar.value == 0 :
		anima.play("bateriablack");
