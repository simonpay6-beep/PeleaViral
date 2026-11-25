class_name EstadosEnemigo
extends RefCounted
## Los 10 estados del enemigo.
##
## PATRÓN: State. Antes había un enum + un `match` gigante en
## cambiar_estado_enemigo() + comparaciones sueltas (`== BLOQUEO`,
## `== BURLA or == NOQUEADO`...) repartidas por fightSystem.gd. Ahora cada
## estado se describe a sí mismo (animación, texto, color y cómo reacciona a
## los golpes) y fightSystem.gd solo le pregunta.
##
## Uso:  var estado := EstadosEnemigo.crear(EstadosEnemigo.Id.BLOQUEO)
##       if estado.bloquea_ataques: ...

enum Id {
	IDLE,          # 1. En guardia
	GOLPE,         # 2. Golpe rápido
	GOLPE_FUERTE,  # 3. Golpe fuerte
	PATADA,        # 4. Patada
	BLOQUEO,       # 5. Bloqueo
	RISA,          # 6. Risa
	BURLA,         # 7. Burla (vulnerable)
	HERIDO,        # 8. Herido
	NOQUEADO,      # 9. Noqueado de pie
	EN_EL_PISO,    # 10. En el piso (K.O.)
}


## Estado base: los valores por defecto son los de un estado "normal".
class Estado extends RefCounted:
	var id: int = 0
	## Sufijo de la animación: se busca "<prefijo_nivel>_<sufijo>" y luego "<sufijo>".
	var sufijo_anim: String = "idle"
	var descripcion: String = ""
	var color: Color = Color.WHITE
	## ¿Puede el enemigo decidir una nueva acción estando en este estado?
	var puede_actuar: bool = false
	## ¿Los golpes del jugador rebotan (no hacen daño)?
	var bloquea_ataques: bool = false
	## ¿Los golpes del jugador le afectan? (en el piso: no)
	var acepta_ataques: bool = true
	## Multiplicador de daño y views extra al golpearlo en este estado.
	var multiplicador_dano: float = 1.0
	var bonus_views: int = 0
	## ¿Vuelve solo a IDLE cuando termina su temporizador?
	var vuelve_a_idle: bool = true

	func _configurar(nuevo_id: int, sufijo: String, texto: String, nuevo_color: Color) -> void:
		id = nuevo_id
		sufijo_anim = sufijo
		descripcion = texto
		color = nuevo_color


class Idle extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.IDLE, "idle", "[1/10] EN GUARDIA (IDLE)", Color(0.8, 0.9, 1.0))
		puede_actuar = true


class Golpe extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.GOLPE, "golpe", "[2/10] GOLPE", Color(1.0, 0.6, 0.2))


class GolpeFuerte extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.GOLPE_FUERTE, "golpe_fuerte", "[3/10] GOLPE FUERTE", Color(1.0, 0.2, 0.2))


class Patada extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.PATADA, "patada", "[4/10] PATADA", Color(1.0, 0.5, 0.0))


class Bloqueo extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.BLOQUEO, "bloqueo", "[5/10] BLOQUEO", Color(0.3, 0.8, 1.0))
		bloquea_ataques = true


class Risa extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.RISA, "risa", "[6/10] RISA", Color(0.9, 0.4, 1.0))


class Burla extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.BURLA, "burla", "[7/10] BURLA", Color(1.0, 1.0, 0.3))
		multiplicador_dano = 1.8
		bonus_views = 80


class Herido extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.HERIDO, "herido", "[8/10] HERIDO", Color(1.0, 0.4, 0.4))


class Noqueado extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.NOQUEADO, "noqueado", "[9/10] NOQUEADO DE PIE", Color(1.0, 1.0, 0.5))
		multiplicador_dano = 1.8
		bonus_views = 80


class EnElPiso extends Estado:
	func _init() -> void:
		_configurar(EstadosEnemigo.Id.EN_EL_PISO, "en_el_piso", "[10/10] EN EL PISO (K.O.)", Color(0.5, 0.5, 0.5))
		acepta_ataques = false
		vuelve_a_idle = false


## Fábrica: crea el objeto del estado a partir de su Id.
static func crear(estado_id: int) -> Estado:
	match estado_id:
		Id.GOLPE:
			return Golpe.new()
		Id.GOLPE_FUERTE:
			return GolpeFuerte.new()
		Id.PATADA:
			return Patada.new()
		Id.BLOQUEO:
			return Bloqueo.new()
		Id.RISA:
			return Risa.new()
		Id.BURLA:
			return Burla.new()
		Id.HERIDO:
			return Herido.new()
		Id.NOQUEADO:
			return Noqueado.new()
		Id.EN_EL_PISO:
			return EnElPiso.new()
		_:
			return Idle.new()
