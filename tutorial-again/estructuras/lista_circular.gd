class_name ListaCircular
extends RefCounted
## TAD Lista circular simplemente enlazada.
##
## El último nodo apunta al primero, así que recorrerla con siguiente() nunca
## termina: después del último vuelve al primero.
##
## Se usa en fightSystem.gd para el TURNO de los espectadores que comentan
## durante la pelea: cada comentario lo escribe el siguiente usuario de la
## ronda. Así todos participan por turnos y nadie comenta dos veces seguidas.


class Nodo extends RefCounted:
	var dato: Variant
	var siguiente: Nodo = null

	func _init(valor: Variant) -> void:
		dato = valor


var _ultimo: Nodo = null   # _ultimo.siguiente es el primero
var _actual: Nodo = null   # cursor del recorrido
var _tamano: int = 0


## Crea la lista a partir de un arreglo (útil para inicializarla).
static func desde(valores: Array) -> ListaCircular:
	var lista: ListaCircular = ListaCircular.new()
	for v in valores:
		lista.insertar(v)
	return lista


## Inserta al final de la ronda (justo antes del primero). O(1).
func insertar(valor: Variant) -> void:
	var nuevo: Nodo = Nodo.new(valor)
	if _ultimo == null:
		nuevo.siguiente = nuevo
	else:
		nuevo.siguiente = _ultimo.siguiente
		_ultimo.siguiente = nuevo
	_ultimo = nuevo
	_tamano += 1


## Elimina la primera aparición de `valor`. Devuelve true si lo encontró. O(n).
func eliminar(valor: Variant) -> bool:
	if _ultimo == null:
		return false
	var previo: Nodo = _ultimo
	for i in _tamano:
		var nodo: Nodo = previo.siguiente
		if nodo.dato == valor:
			if _tamano == 1:
				nodo.siguiente = null # rompe el ciclo del único nodo
				_ultimo = null
				_actual = null
			else:
				previo.siguiente = nodo.siguiente
				if nodo == _ultimo:
					_ultimo = previo
				if nodo == _actual:
					_actual = previo
			_tamano -= 1
			return true
		previo = nodo
	return false


## Avanza el cursor y devuelve el dato. Da la vuelta al llegar al final.
## Devuelve null si la lista está vacía.
func siguiente() -> Variant:
	if _ultimo == null:
		return null
	_actual = _ultimo.siguiente if _actual == null else _actual.siguiente
	return _actual.dato


## Avanza el cursor `pasos` posiciones (para empezar la ronda en otro punto).
func rotar(pasos: int) -> void:
	for i in pasos:
		siguiente()


## Vacía la lista. Rompe el ciclo último -> primero para que Godot pueda
## liberar los nodos (RefCounted no libera referencias circulares solo).
func vaciar() -> void:
	if _ultimo != null:
		_ultimo.siguiente = null
	_ultimo = null
	_actual = null
	_tamano = 0


func _notification(what: int) -> void:
	# Al destruirse la lista se rompe el ciclo (no se puede llamar a vaciar() aquí).
	if what == NOTIFICATION_PREDELETE and _ultimo != null:
		_ultimo.siguiente = null


func esta_vacia() -> bool:
	return _tamano == 0


func tamano() -> int:
	return _tamano
