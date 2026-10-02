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


@export var defending1:bool
@export var defending2:bool
@export var defending3:bool
@export var defending4:bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
func _physics_process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()

func _on_button_1_pressed() -> void:
	# Cuadrado de arriba a la izquierda
	progress_bar2.value = progress_bar2.value - 5;


func _on_button_2_pressed() -> void:
	# Cuadrado de abajo a la izquierda
	progress_bar2.value = progress_bar2.value - 5;


func _on_button_3_pressed() -> void:
	# Cuadrado de arriba a la derecha
	progress_bar2.value = progress_bar2.value - 5;


func _on_button_4_pressed() -> void:
	# Cuadrado de abajo a la derecha
	progress_bar2.value = progress_bar2.value - 5;
	
func _on_defensebox_mouse_entered() -> void:
	defending1 = true;
func _on_defensebox_mouse_exited() -> void:
	defending1 = false;


func _on_defensebox_2_mouse_entered() -> void:
	defending2 = true;
func _on_defensebox_2_mouse_exited() -> void:
	defending2 = false;

func _on_defensebox_3_mouse_entered() -> void:
	defending3 = true;
func _on_defensebox_3_mouse_exited() -> void:
	defending3 = false;

func _on_defensebox_4_mouse_entered() -> void:
	defending4 = true;
func _on_defensebox_4_mouse_exited() -> void:
	defending4 = false;
