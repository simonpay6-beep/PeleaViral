class_name Cola
extends RefCounted
## TAD Cola (FIFO) implementado con una lista enlazada simple.
##
## Se usa en live_overlay.gd: cada mensaje del chat en vivo se ENCOLA al final;
## cuando hay más de MAX_MENSAJES, se DESENCOLA el más antiguo (el primero que
## entró) y se borra de la pantalla. Una cola es la estructura natural porque
## el chat siempre elimina por el frente y agrega por el final, ambos en O(1).


class Nodo extends RefCounted:
	var dato: Variant
	var siguiente: Nodo = null

	func _init(valor: Variant) -> void:
		dato = valor


var _frente: Nodo = null
var _final: Nodo = null
var _tamano: int = 0


## Agrega un elemento al final de la cola. O(1).
func encolar(valor: Variant) -> void:
	var nuevo: Nodo = Nodo.new(valor)
	if _final == null:
		_frente = nuevo
	else:
		_final.siguiente = nuevo
	_final = nuevo
	_tamano += 1


## Quita y devuelve el elemento del frente. Devuelve null si está vacía. O(1).
func desencolar() -> Variant:
	if _frente == null:
		return null
	var valor: Variant = _frente.dato
	_frente = _frente.siguiente
	if _frente == null:
		_final = null
	_tamano -= 1
	return valor


## Devuelve el elemento del frente sin quitarlo (null si está vacía).
func frente() -> Variant:
	return null if _frente == null else _frente.dato


func esta_vacia() -> bool:
	return _tamano == 0


func tamano() -> int:
	return _tamano


func vaciar() -> void:
	_frente = null
	_final = null
	_tamano = 0
