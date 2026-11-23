class_name ManosJugador
extends Node2D
## Puños (y pie) del jugador, animados POR CÓDIGO con tweens.
##
## No hay sprites de "atacar" ni "defender": solo la imagen de un puño. Aquí se
## duplica (izquierdo = imagen normal, derecho = imagen espejada) y se mueve:
##   - reposo ..... los puños abajo, a los lados
##   - guardia .... los dos puños suben delante de la cara (mientras te defiendes)
##   - golpear .... adelante (más pequeño = se aleja hacia el rival) y de vuelta
##   - patada ..... el pie sube desde abajo, se aleja y regresa
##   - esquivar ... todo el cuerpo se inclina hacia un lado
##   - recibir .... sacudida y destello cuando te pegan
## fightSystem.gd solo llama a estos métodos: no sabe nada de tweens.

## Dónde está el rival en pantalla (hacia allá viajan los golpes).
const OBJETIVO: Vector2 = Vector2(420.0, 330.0)
const ESCALA_REPOSO: float = 0.30
const ESCALA_GUARDIA: float = 0.32
const ESCALA_GOLPE: float = 0.17
## Centro del puño dentro de la imagen (assets/ui/puno.png: el antebrazo es largo para que nunca se vea el corte).
## Coincide con el Offset de los Sprite2D.
const PIVOTE: Vector2 = Vector2(-1375.0, -300.0)

@onready var puno_izq: Sprite2D = $PunoIzquierdo
@onready var puno_der: Sprite2D = $PunoDerecho
@onready var pie: Sprite2D = $Pie

var _guardia: bool = false
var _rota: bool = false
var _desgaste: float = 0.0
var _ocupado_izq: bool = false
var _ocupado_der: bool = false
var _tweens: Dictionary = {}
var _tween_cuerpo: Tween


func _ready() -> void:
	pie.visible = false
	_aplicar_pose(puno_izq, true, 0.0)
	_aplicar_pose(puno_der, false, 0.0)


# ---------------------------------------------------------------- POSES ----

## Devuelve [posición, rotación en grados, escala] de un puño según la pose actual.
func _destino(izq: bool) -> Array:
	if _rota:
		return [Vector2(250.0, 690.0) if izq else Vector2(900.0, 690.0), -12.0 if izq else 12.0, ESCALA_REPOSO]
	if _guardia:
		return [Vector2(470.0, 480.0) if izq else Vector2(690.0, 480.0), 14.0 if izq else -14.0, ESCALA_GUARDIA]
	return [Vector2(300.0, 585.0) if izq else Vector2(850.0, 585.0), 0.0, ESCALA_REPOSO]


func _escala_vec(izq: bool, esc: float) -> Vector2:
	# El puño derecho es la imagen espejada (escala X negativa).
	return Vector2(esc if izq else -esc, esc)


func _matar_tween(spr: Sprite2D) -> void:
	var previo: Tween = _tweens.get(spr)
	if previo != null and previo.is_valid():
		previo.kill()


func _guardar_tween(spr: Sprite2D, t: Tween) -> void:
	_tweens[spr] = t


func _aplicar_pose(spr: Sprite2D, izq: bool, dur: float) -> void:
	_matar_tween(spr)
	var d: Array = _destino(izq)
	var pos: Vector2 = d[0]
	var rot: float = d[1]
	var esc: float = d[2]
	if dur <= 0.0:
		spr.position = pos
		spr.rotation_degrees = rot
		spr.scale = _escala_vec(izq, esc)
		return
	var t: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(spr, "position", pos, dur)
	t.tween_property(spr, "rotation_degrees", rot, dur)
	t.tween_property(spr, "scale", _escala_vec(izq, esc), dur)
	_guardar_tween(spr, t)


func _refrescar_poses(dur: float) -> void:
	if not _ocupado_izq:
		_aplicar_pose(puno_izq, true, dur)
	if not _ocupado_der:
		_aplicar_pose(puno_der, false, dur)


func _colorear() -> void:
	var c: Color = Color.WHITE
	if _rota:
		c = Color(0.55, 0.25, 0.25)
	else:
		c = Color.WHITE.lerp(Color(1.0, 0.45, 0.4), clampf(_desgaste, 0.0, 1.0))
	puno_izq.modulate = c
	puno_der.modulate = c


## Los dos puños suben delante de la cara (true) o vuelven abajo (false).
func poner_guardia(activa: bool) -> void:
	if _guardia == activa:
		return
	_guardia = activa
	_refrescar_poses(0.14)


## Guardia rota: los puños caen oscurecidos hasta que se recupera.
func guardia_rota(rota: bool) -> void:
	if _rota == rota:
		return
	_rota = rota
	_colorear()
	_refrescar_poses(0.18)


## 0 = guardia intacta, 1 = a punto de romperse (los puños se ponen rojizos).
func set_desgaste(ratio: float) -> void:
	_desgaste = ratio
	_colorear()


# --------------------------------------------------------------- ATAQUES ----

## tipo: "RECTO_DER", "HOOK_IZQ", "UPPERCUT_DER", "PATADA_DER"...
func golpear(tipo: String) -> void:
	if tipo.begins_with("PATADA"):
		_patada()
		return

	var izq: bool = tipo.ends_with("_IZQ")
	if (izq and _ocupado_izq) or ((not izq) and _ocupado_der):
		return
	var spr: Sprite2D = puno_izq if izq else puno_der
	_matar_tween(spr)
	if izq:
		_ocupado_izq = true
	else:
		_ocupado_der = true

	var lado: float = -1.0 if izq else 1.0
	var base: Array = _destino(izq)
	var pos0: Vector2 = base[0]
	var t: Tween = create_tween().set_trans(Tween.TRANS_QUAD)

	if tipo.begins_with("HOOK"):
		# Se abre hacia su lado y barre en arco hasta el rival.
		_fase(t, spr, izq, pos0 + Vector2(lado * 180.0, -80.0), lado * 35.0, ESCALA_REPOSO * 1.1, 0.09)
		_fase(t, spr, izq, OBJETIVO + Vector2(lado * -10.0, 0.0), lado * -40.0, ESCALA_GOLPE, 0.10)
	elif tipo.begins_with("UPPERCUT"):
		# Se hunde y sube de abajo hacia arriba.
		_fase(t, spr, izq, pos0 + Vector2(0.0, 110.0), 0.0, ESCALA_GUARDIA * 1.05, 0.08)
		_fase(t, spr, izq, OBJETIVO + Vector2(lado * 15.0, 50.0), lado * -22.0, ESCALA_GOLPE * 1.1, 0.10)
	else:
		# RECTO: breve impulso hacia atrás y disparo recto al frente.
		_fase(t, spr, izq, pos0 + Vector2(0.0, 28.0), 0.0, ESCALA_REPOSO * 1.04, 0.05)
		_fase(t, spr, izq, OBJETIVO + Vector2(lado * 18.0, 0.0), 0.0, ESCALA_GOLPE, 0.09)

	t.tween_interval(0.05)
	t.tween_callback(_volver.bind(izq))
	_guardar_tween(spr, t)


func _fase(t: Tween, spr: Sprite2D, izq: bool, pos: Vector2, rot: float, esc: float, dur: float) -> void:
	t.tween_property(spr, "position", pos, dur)
	t.parallel().tween_property(spr, "rotation_degrees", rot, dur)
	t.parallel().tween_property(spr, "scale", _escala_vec(izq, esc), dur)


func _volver(izq: bool) -> void:
	if izq:
		_ocupado_izq = false
		_aplicar_pose(puno_izq, true, 0.16)
	else:
		_ocupado_der = false
		_aplicar_pose(puno_der, false, 0.16)


func _patada() -> void:
	_matar_tween(pie)
	pie.visible = true
	pie.position = Vector2(OBJETIVO.x + 140.0, 800.0)
	pie.rotation_degrees = 0.0
	pie.scale = Vector2.ONE * 0.5
	var t: Tween = create_tween().set_trans(Tween.TRANS_QUAD)
	t.tween_property(pie, "position", Vector2(OBJETIVO.x + 120.0, 560.0), 0.10)
	t.parallel().tween_property(pie, "rotation_degrees", -8.0, 0.10)
	t.tween_property(pie, "position", OBJETIVO + Vector2(40.0, 70.0), 0.10)
	t.parallel().tween_property(pie, "scale", Vector2.ONE * 0.2, 0.10)
	t.tween_interval(0.04)
	t.tween_property(pie, "position", Vector2(OBJETIVO.x + 140.0, 800.0), 0.18)
	t.parallel().tween_property(pie, "scale", Vector2.ONE * 0.5, 0.18)
	t.tween_callback(pie.hide)
	_guardar_tween(pie, t)


# ------------------------------------------------- DEFENSA Y REACCIONES ----

## lado: "IZQUIERDA", "CENTRO" o "DERECHA". El cuerpo se inclina hacia ese lado.
func esquivar(lado: String) -> void:
	var dx: float = 0.0
	var rot: float = 0.0
	if lado == "IZQUIERDA":
		dx = -90.0
		rot = -6.0
	elif lado == "DERECHA":
		dx = 90.0
		rot = 6.0
	if _tween_cuerpo != null and _tween_cuerpo.is_valid():
		_tween_cuerpo.kill()
	_tween_cuerpo = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_cuerpo.tween_property(self, "position:x", dx, 0.12)
	_tween_cuerpo.tween_property(self, "rotation_degrees", rot, 0.12)


## Te pegaron: sacudida de los puños y destello rojo.
func recibir_golpe() -> void:
	_sacudir(14.0, 0.3)
	for spr: Sprite2D in [puno_izq, puno_der]:
		var c: Color = spr.modulate
		spr.modulate = Color(1.0, 0.3, 0.3)
		create_tween().tween_property(spr, "modulate", c, 0.25)


## El golpe rebotó en tu guardia: pequeño empujón.
func bloquear_impacto() -> void:
	_sacudir(6.0, 0.18)
	for spr: Sprite2D in [puno_izq, puno_der]:
		if (spr == puno_izq and _ocupado_izq) or (spr == puno_der and _ocupado_der):
			continue
		var base: Vector2 = spr.scale
		var t: Tween = create_tween()
		t.tween_property(spr, "scale", base * 1.12, 0.05)
		t.tween_property(spr, "scale", base, 0.12)


func _sacudir(fuerza: float, dur: float) -> void:
	var t: Tween = create_tween()
	var pasos: int = 5
	for i in pasos:
		var k: float = 1.0 - float(i) / float(pasos)
		t.tween_property(self, "offset_sacudida", Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza)) * k, dur / float(pasos))
	t.tween_property(self, "offset_sacudida", Vector2.ZERO, 0.04)


## Desplazamiento temporal de la sacudida (se suma a la posición X de la esquiva).
var offset_sacudida: Vector2 = Vector2.ZERO:
	set(valor):
		offset_sacudida = valor
		for spr: Sprite2D in [puno_izq, puno_der]:
			if spr != null:
				spr.offset = PIVOTE + valor * 2.0
