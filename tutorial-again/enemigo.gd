extends Node2D
@onready var t_pre_cargar: Timer = $Tiempo_antes_de_cargar
@onready var t_cargar: Timer = $Tiempo_de_carga
@onready var t_aturdido: Timer = $Tiempo_aturdido
@onready var fight: Node2D = $".."

@onready var anima: AnimatedSprite2D = $AnimatedSprite2D
# hitbox es para guardar la caja que esta siendo actualmente atacada.
# La forma en que el juego decide que caja atacar es mediante randi_range entre 1 y 4.
var hitbox

# Esta variable es el estado actual del enemigo, ya sea pegando, aturdido, etc.
var state = "quieto"
# Los states son:
# quieto: No esta haciendo nada, esperando a la proxima vez que intente pegar.
# cargando_ataque: Esta cargando el ataque, dandole tiempo al jugador para poner su mouse y defenderse.
# aturdido: Esta vulnerable en la misma casilla que ataco.

func _ready() -> void:
	anima.play("idle")
	t_pre_cargar.start()
	hitbox_random()
	_on_tiempo_antes_de_cargar_timeout()
	_on_tiempo_de_carga_timeout()
	_on_tiempo_aturdido_timeout()
	
func _physics_process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position();
	animacion()
	
func hitbox_random():
	hitbox = randi_range(1, 4);

func animacion():
	
	match state:
		"quieto":
			anima.flip_h = false;
			anima.play("idle")
		"cargando_ataque":
			match hitbox:
				1:
					anima.flip_h = true;
					anima.play("preparing_punch")
				2:
					anima.flip_h = true;
					anima.play("preparing_kick")
				3: 
					anima.flip_h = false;
					anima.play("preparing_punch")
				4:
					anima.flip_h = false;
					anima.play("preparing_kick")
				_:
					print("error_cargando_ataque")
		"aturdido":
			match hitbox:
				1:
					anima.flip_h = true;
					anima.play("blocked_punch")
				2:
					anima.flip_h = true;
					anima.play("blocked_kick")
				3:
					anima.flip_h = false;
					anima.play("blocked_punch")
				4:
					anima.flip_h = false;
					anima.play("blocked_kick")
				_:
					print("error_aturdido")
		"ataque":
				match hitbox:
					1:
						anima.flip_h = true;
						anima.play("successful_punch")
					2:
						anima.flip_h = true;
						anima.play("successful_kick")
					3:  
						anima.flip_h = false;
						anima.play("successful_punch")
					4:  
						anima.flip_h = false;
						anima.play("successful_kick")
					_:
						print("error_ataque")


func _on_tiempo_antes_de_cargar_timeout() -> void:
	if state == "quieto":
		t_cargar.start()
		state = "cargando_ataque"
	
func _on_tiempo_de_carga_timeout() -> void:
	if state == "cargando_ataque":
		t_aturdido.start()
		match hitbox:
			1:
				if fight.defending1 == true:
					state = "aturdido"
				elif fight.defending1 == false:
					state = "ataque"
				else:
					state = "ataque"
			2:
				if fight.defending2 == true:
					state = "aturdido"
				elif fight.defending2 == false:
					state = "ataque"
				else:
					state = "ataque"
			3: 
				if fight.defending3 == true:
					state = "aturdido"
				elif fight.defending3 == false:
					state = "ataque"
				else:
					state = "ataque"
			4:
				if fight.defending4 == true:
					state = "aturdido"
				elif fight.defending4 == false:
					state = "ataque"
				else: 
					state = "ataque"
		
func _on_tiempo_aturdido_timeout() -> void:
	if state == "aturdido":
		t_pre_cargar.start()
		state = "quieto"
		hitbox_random()
	if state == "ataque":
		t_pre_cargar.start()
		state = "quieto"
		hitbox_random()
		
