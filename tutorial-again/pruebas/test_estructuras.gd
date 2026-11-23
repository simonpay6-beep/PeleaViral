extends SceneTree
## Pruebas unitarias de los TAD de estructuras/.
## Ejecutar:  godot --headless -s res://pruebas/test_estructuras.gd

var _fallas: int = 0
var _total: int = 0


func check(cond: bool, nombre: String) -> void:
	_total += 1
	if cond:
		print("  OK   ", nombre)
	else:
		_fallas += 1
		printerr("  FALLA ", nombre)


func _init() -> void:
	print("== Cola")
	var c: Cola = Cola.new()
	check(c.esta_vacia() and c.desencolar() == null, "cola vacía devuelve null")
	for i in 5:
		c.encolar(i)
	check(c.tamano() == 5 and c.frente() == 0, "encolar 5")
	check(c.desencolar() == 0 and c.desencolar() == 1, "FIFO")
	c.encolar(9)
	var resto: Array = []
	while not c.esta_vacia():
		resto.append(c.desencolar())
	check(resto == [2, 3, 4, 9], "orden tras mezclar operaciones")
	c.encolar("x")
	check(c.frente() == "x" and c.tamano() == 1, "reutilizable tras vaciarse")

	print("== ListaCircular")
	var lc: ListaCircular = ListaCircular.new()
	check(lc.siguiente() == null, "vacía devuelve null")
	lc = ListaCircular.desde(["a", "b", "c"])
	var vuelta: Array = []
	for i in 7:
		vuelta.append(lc.siguiente())
	check(vuelta == ["a", "b", "c", "a", "b", "c", "a"], "da la vuelta")
	check(lc.eliminar("b") and lc.tamano() == 2, "eliminar intermedio")
	vuelta = []
	for i in 4:
		vuelta.append(lc.siguiente())
	check(vuelta == ["c", "a", "c", "a"], "ronda sin el eliminado")
	check(lc.eliminar("c") and lc.eliminar("a") and lc.esta_vacia(), "eliminar todos")
	check(not lc.eliminar("z"), "eliminar inexistente")

	print("== ListaDoble")
	var ld: ListaDoble = ListaDoble.desde([1, 2, 3])
	check(ld.ir_al_inicio() == 1 and not ld.hay_anterior(), "inicio")
	check(ld.avanzar() == 2 and ld.avanzar() == 3 and not ld.hay_siguiente(), "avanzar")
	check(ld.avanzar() == 3, "no pasa del final")
	check(ld.retroceder() == 2 and ld.indice() == 1, "retroceder")
	ld.insertar_inicio(0)
	check(ld.indice() == 2 and ld.actual() == 2, "insertar_inicio conserva el cursor")
	check(ListaDoble.new().ir_al_inicio() == null, "vacía")

	print("== HistorialPeleas (archivo)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HistorialPeleas.RUTA))
	var h: HistorialPeleas = HistorialPeleas.new()
	check(h.total_peleas() == 0 and h.mejor_views(1) == 0, "sin archivo empieza vacío")
	h.registrar(1, true, 800)
	h.registrar(1, false, 300)
	h.registrar(2, true, 1200)
	var h2: HistorialPeleas = HistorialPeleas.new() # vuelve a leer el archivo
	check(h2.total_peleas() == 3 and h2.victorias() == 2, "persiste en disco")
	check(h2.mejor_views(1) == 800 and h2.mejor_views(2) == 1200 and h2.mejor_views(3) == 0, "récord por nivel")
	var f: FileAccess = FileAccess.open(HistorialPeleas.RUTA, FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	check(HistorialPeleas.new().total_peleas() == 0, "archivo dañado no rompe el juego")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HistorialPeleas.RUTA))

	print("\n%d/%d pruebas OK" % [_total - _fallas, _total])
	quit(1 if _fallas > 0 else 0)
