extends Node
@onready var enemigo_healthbar: ProgressBar = $fight_beta2/enemigo_healthbar
@onready var enemigo: Node2D = $fight_beta2/enemigo
@onready var muerto: Sprite2D = $Arte/muerto
@onready var moscas: AnimatedSprite2D = $Arte/moscas
var i = 0;



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	muerto.visible = false;
	moscas.visible = false;
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	ganaste()
	pass
func ganaste():
	if enemigo_healthbar.value <= 0:
		muerto.visible = true;
		moscas.visible = true;
	if i == 0 and enemigo_healthbar.value <= 0:
		enemigo.queue_free()
		i = i + 1;
		
