class_name Niveles
extends RefCounted
## Una estrategia por nivel: Tutorial (árbol), Nivel 1, Nivel 2 y Nivel 3 (jefe invencible).
##
## PATRÓN: Strategy (+ Factory Method en crear / crear_tutorial).
## Antes fightSystem.gd tenía `if nivel_actual == 3` / `match nivel_actual`
## repetidos en 9 sitios (historia, vida, IA, daño, comentarios, HUD...).
## Ahora cada nivel responde esas preguntas por sí mismo y fightSystem.gd
## solo llama a `estrategia.algo()`. Para cambiar un nivel se toca SOLO su clase.


## Valores por defecto = comportamiento de un rival "normal".
class Estrategia extends RefCounted:
	var numero: int = 1
	var nombre_enemigo: String = ""
	## Prefijo de animaciones: "arbol_", "n1_", "n2_", "n3_".
	var prefijo_anim: String = ""
	var vida_max: float = 100.0
	var dialogo_inicio: String = ""
	var color_historia: Color = Color(0.08, 0.12, 0.22, 0.96)
	## Imagen de fondo de la pelea de este nivel.
	var fondo_textura: String = "res://forest.png"
	## Color con el que se tiñe al enemigo para distinguir los niveles (blanco = sprite original).
	var tinte: Color = Color.WHITE

	func texto_historia(_titulo_video: String) -> String:
		return ""

	## Segundos entre decisiones del enemigo. `factor` viene de la dificultad.
	func intervalo_ia(_factor: float) -> float:
		return 2.0

	## Jefe final: no recibe daño y todos sus golpes conectan.
	func es_jefe_invencible() -> bool:
		return false

	## Daño al jugador cuando el golpe conecta. peso 1 = golpe/patada, 2 = golpe fuerte.
	func dano_a_jugador(peso: int) -> float:
		return 12.0 if peso == 1 else 18.0

	## Se llama cada frame de la pelea. Devuelve una frase del enemigo o "".
	func pensar(_delta: float) -> String:
		return ""

	func comentarios_ambiente() -> Array[String]:
		return [
			"¡Dale con el Uppercut!",
			"Buena guardia frente a la cámara 🥊",
			"¡Esquiva, esquiva!",
			"Llegando al directo, ¿quién va ganando?",
		]

	## Elige la acción del enemigo según un dado 0..99. Devuelve un Dictionary con:
	##   estado (EstadosEnemigo.Id), tiempo (s), ataque (texto o ""), peso (int),
	##   dialogo (texto o ""), reiniciar_combo (bool).
	func elegir_accion(dado: int) -> Dictionary:
		if dado < 35:
			return _accion(EstadosEnemigo.Id.GOLPE, 0.6, "GOLPE", 1)
		elif dado < 60:
			return _accion(EstadosEnemigo.Id.GOLPE_FUERTE, 0.75, "GOLPE FUERTE", 2)
		elif dado < 80:
			return _accion(EstadosEnemigo.Id.PATADA, 0.7, "PATADA", 1)
		elif dado < 90:
			return _accion(EstadosEnemigo.Id.BLOQUEO, 1.2, "", 0, "", true)
		return _accion(
			EstadosEnemigo.Id.BURLA, 1.3, "", 0,
			"😜 ¡El rival hace una BURLA! ¡Golpéalo ahora!"
		)

	func _accion(
		estado: int, tiempo: float, ataque: String = "", peso: int = 0,
		dialogo: String = "", reiniciar_combo: bool = false
	) -> Dictionary:
		return {
			"estado": estado,
			"tiempo": tiempo,
			"ataque": ataque,
			"peso": peso,
			"dialogo": dialogo,
			"reiniciar_combo": reiniciar_combo,
		}


## Calentamiento contra el árbol (solo en el Video #1). Los pasos del
## tutorial están en fightSystem.gd; aquí solo van los datos del "enemigo".
class Tutorial extends Estrategia:
	func _init() -> void:
		numero = 0
		nombre_enemigo = "🌳 Árbol de Entrenamiento"
		prefijo_anim = "arbol_"
		vida_max = 100.0


class Nivel1 extends Estrategia:
	func _init() -> void:
		numero = 1
		nombre_enemigo = "🥊 Rival #1: Buscapleitos Callejero"
		prefijo_anim = "n1_"
		vida_max = 100.0
		dialogo_inicio = "Rival #1: '¡Hoy te quedas sin canal en NeTube!'"
		color_historia = Color(0.08, 0.12, 0.22, 0.96)

	func texto_historia(titulo_video: String) -> String:
		return (
			"🎬 HISTORIA NIVEL 1: " + titulo_video
			+ "\n\nEl directo comienza tras derribar el árbol.\n"
			+ "Tu primer rival callejero entra al encuadre buscando tumbarte el stream.\n\n"
			+ "[Presiona ENTER o espera 4 segundos]"
		)

	func intervalo_ia(factor: float) -> float:
		return 2.0 * factor


class Nivel2 extends Estrategia:
	func _init() -> void:
		numero = 2
		nombre_enemigo = "🦵 Rival #2: Campeón Pesado"
		prefijo_anim = "n2_"
		fondo_textura = "res://assets/fondos/calle.png"
		tinte = Color(1.0, 0.82, 0.62)
		vida_max = 180.0
		dialogo_inicio = "Rival #2: 'Tus golpes del primer video no servirán conmigo.'"
		color_historia = Color(0.18, 0.08, 0.25, 0.96)

	func texto_historia(titulo_video: String) -> String:
		return (
			"🎬 HISTORIA NIVEL 2: " + titulo_video
			+ "\n\nTus suscriptores subieron y ahora te reta un peleador pesado.\n"
			+ "Bloquea tus ataques, se burla y patea con fuerza.\n\n"
			+ "[Presiona ENTER o espera 4 segundos]"
		)

	func intervalo_ia(factor: float) -> float:
		return 1.35 * factor

	func dano_a_jugador(peso: int) -> float:
		return 15.0 if peso == 1 else 22.0


## Jefe final: vida infinita, nunca bloquea ni se burla, y sus 10 ataques
## atraviesan cualquier defensa. El jugador pierde SÍ O SÍ (es la enseñanza).
class Nivel3 extends Estrategia:
	var _timer_dialogo: float = 3.0
	const DIALOGOS: Array[String] = [
		"Por más que levantes las manos, no puedes bloquear tu propio ego.",
		"¿Todo esto por unas cuantas visitas en NeTube? Mírate.",
		"Tengo VIDA INFINITA porque la obsesión por la fama nunca se acaba.",
		"Cada golpe que recibes sube tus views... ¿valió la pena?",
		"Ni tu cámara ni tus puños pueden derrotar al Algoritmo.",
		"Acepta la derrota. El directo está a punto de terminar.",
	]

	func _init() -> void:
		numero = 3
		nombre_enemigo = "👁️ NIVEL 3: EL ALGORITMO (INVENCIBLE)"
		prefijo_anim = "n3_"
		fondo_textura = "res://assets/fondos/arena.png"
		tinte = Color(1.0, 0.55, 0.55)
		vida_max = 999999.0
		dialogo_inicio = "Jefe Final: 'Soy invencible. En 10 ataques aprenderás la lección.'"
		color_historia = Color(0.25, 0.02, 0.02, 0.96)

	func texto_historia(titulo_video: String) -> String:
		return (
			"🎬 HISTORIA NIVEL 3: " + titulo_video
			+ "\n\n⚠️ EL COMBATE FINAL ⚠️\n"
			+ "La fama te trajo hasta aquí, pero este rival es IMPOSIBLE.\n"
			+ "Tiene VIDA INFINITA y caerás en exactamente 10 ATAQUES.\n\n"
			+ "[Presiona ENTER o espera 4 segundos]"
		)

	# Ataca sin descanso: no depende de la dificultad.
	func intervalo_ia(_factor: float) -> float:
		return 1.05

	func es_jefe_invencible() -> bool:
		return true

	func pensar(delta: float) -> String:
		_timer_dialogo -= delta
		if _timer_dialogo <= 0.0:
			_timer_dialogo = 3.2
			return "👁️ Jefe Final: \"" + DIALOGOS.pick_random() + "\""
		return ""

	func comentarios_ambiente() -> Array[String]:
		return [
			"¡¡NO LE BAJA NADA LA VIDA!! 😱",
			"¡Para el directo bro, te va a matar!",
			"¡Ni cubriéndote puedes parar sus golpes!",
			"¡100,000 espectadores viendo cómo cae! 🔥",
		]

	func elegir_accion(dado: int) -> Dictionary:
		if dado < 40:
			return _accion(EstadosEnemigo.Id.GOLPE, 0.55, "GOLPE INEVITABLE", 1)
		elif dado < 75:
			return _accion(EstadosEnemigo.Id.GOLPE_FUERTE, 0.65, "IMPACTO BRUTAL", 2)
		return _accion(EstadosEnemigo.Id.PATADA, 0.6, "PATADA DESTRUCTORA", 1)


## Fábrica: la estrategia de un nivel (1, 2 o 3).
static func crear(nivel: int) -> Estrategia:
	match clampi(nivel, 1, 3):
		1:
			return Nivel1.new()
		2:
			return Nivel2.new()
		_:
			return Nivel3.new()


static func crear_tutorial() -> Estrategia:
	return Tutorial.new()
