class_name ListaDoble
extends RefCounted
## TAD Lista doblemente enlazada con cursor.
##
## Cada nodo conoce al anterior y al siguiente, así que se puede avanzar y
## retroceder en O(1).
##
## Se usa en phone_intro.gd para las páginas de la historia: los botones
## "Siguiente" y "Anterior" mueven el cursor hacia adelante y hacia atrás.


class Nodo extends RefCounted:
	var dato: Variant
	var anterior: Nodo = null
	var siguiente: Nodo = null

	func _init(valor: Variant) -> void:
		dato = valor


var _cabeza: Nodo = null
var _cola: Nodo = null
var _cursor: Nodo = null
var _indice: int = -1
var _tamano: int = 0


static func desde(valores: Array) -> ListaDoble:
	var lista: ListaDoble = ListaDoble.new()
	for v in valores:
		lista.insertar_final(v)
	return lista


func insertar_final(valor: Variant) -> void:
	var nuevo: Nodo = Nodo.new(valor)
	if _cola == null:
		_cabeza = nuevo
	else:
		_cola.siguiente = nuevo
		nuevo.anterior = _cola
	_cola = nuevo
	_tamano += 1


func insertar_inicio(valor: Variant) -> void:
	var nuevo: Nodo = Nodo.new(valor)
	if _cabeza == null:
		_cola = nuevo
	else:
		_cabeza.anterior = nuevo
		nuevo.siguiente = _cabeza
	_cabeza = nuevo
	_tamano += 1
	if _cursor != null:
		_indice += 1


## Pone el cursor en el primer elemento y lo devuelve (null si está vacía).
func ir_al_inicio() -> Variant:
	_cursor = _cabeza
	_indice = 0 if _cabeza != null else -1
	return actual()


func actual() -> Variant:
	return null if _cursor == null else _cursor.dato


func hay_siguiente() -> bool:
	return _cursor != null and _cursor.siguiente != null


func hay_anterior() -> bool:
	return _cursor != null and _cursor.anterior != null


## Mueve el cursor hacia adelante. Si no hay siguiente, no se mueve.
func avanzar() -> Variant:
	if hay_siguiente():
		_cursor = _cursor.siguiente
		_indice += 1
	return actual()


## Mueve el cursor hacia atrás. Si no hay anterior, no se mueve.
func retroceder() -> Variant:
	if hay_anterior():
		_cursor = _cursor.anterior
		_indice -= 1
	return actual()


## Vacía la lista. Rompe los enlaces anterior <-> siguiente para que Godot
## pueda liberar los nodos (RefCounted no libera referencias circulares solo).
func vaciar() -> void:
	var nodo: Nodo = _cabeza
	while nodo != null:
		var sig: Nodo = nodo.siguiente
		nodo.anterior = null
		nodo.siguiente = null
		nodo = sig
	_cabeza = null
	_cola = null
	_cursor = null
	_indice = -1
	_tamano = 0


func _notification(what: int) -> void:
	# Al destruirse la lista se rompen los enlaces (no se puede llamar a vaciar() aquí).
	if what == NOTIFICATION_PREDELETE:
		var nodo: Nodo = _cabeza
		while nodo != null:
			var sig: Nodo = nodo.siguiente
			nodo.anterior = null
			nodo.siguiente = null
			nodo = sig


func indice() -> int:
	return _indice


func tamano() -> int:
	return _tamano


func esta_vacia() -> bool:
	return _tamano == 0
