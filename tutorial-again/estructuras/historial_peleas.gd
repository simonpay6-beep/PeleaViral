class_name HistorialPeleas
extends RefCounted
## TAD Historial de peleas, guardado en un ARCHIVO JSON.
##
## Cada pelea terminada se agrega como un registro
## {fecha, nivel, gano, views} y se guarda en user://historial_peleas.json, de
## modo que el récord sobrevive aunque se cierre el juego. fightSystem.gd lo
## usa para mostrar el mejor directo del nivel al terminar cada pelea.
##
## Robusto ante archivos dañados o editados a mano: si no se puede leer, se
## empieza con un historial vacío en lugar de fallar.

const RUTA: String = "user://historial_peleas.json"
const MAX_REGISTROS: int = 200

var _registros: Array[Dictionary] = []


func _init() -> void:
	cargar()


## Lee el archivo. Si no existe o está dañado, deja el historial vacío.
func cargar() -> void:
	_registros.clear()
	if not FileAccess.file_exists(RUTA):
		return
	var archivo: FileAccess = FileAccess.open(RUTA, FileAccess.READ)
	if archivo == null:
		return
	var json: JSON = JSON.new()
	var error: Error = json.parse(archivo.get_as_text())
	archivo.close()
	if error != OK or not (json.data is Array):
		return
	var datos: Array = json.data
	for r in datos:
		if r is Dictionary and r.has("nivel") and r.has("views"):
			_registros.append(r)


## Escribe todo el historial en el archivo. Devuelve true si pudo guardar.
func guardar() -> bool:
	var archivo: FileAccess = FileAccess.open(RUTA, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(_registros, "\t"))
	archivo.close()
	return true


## Agrega una pelea al historial y la guarda en disco.
func registrar(nivel: int, gano: bool, views: int) -> void:
	_registros.append({
		"fecha": Time.get_datetime_string_from_system(false, true),
		"nivel": nivel,
		"gano": gano,
		"views": views,
	})
	while _registros.size() > MAX_REGISTROS:
		_registros.pop_front()
	guardar()


## Mayor cantidad de views lograda en un nivel (0 si nunca se jugó).
func mejor_views(nivel: int) -> int:
	var mejor: int = 0
	for r in _registros:
		if int(r["nivel"]) == nivel:
			mejor = maxi(mejor, int(r["views"]))
	return mejor


## Cuántas peleas se han jugado en total.
func total_peleas() -> int:
	return _registros.size()


## Cuántas peleas se han ganado en total.
func victorias() -> int:
	var n: int = 0
	for r in _registros:
		if bool(r.get("gano", false)):
			n += 1
	return n
