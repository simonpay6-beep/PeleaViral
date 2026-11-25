class_name SelectorControl
extends ColorRect
## Ventana "¿Cómo quieres pelear?" que aparece al tocar "Iniciar Live".
## El jugador elige CÁMARA (pelear con el cuerpo) o TECLADO.
## La tarjeta de la cámara muestra si el detector de Python está conectado.
## Se arma por código: add_child(SelectorControl.new()) y escuchar sus señales.

signal elegido(modo: String)
signal cancelado

const ROJO: Color = Color(0.89, 0.13, 0.11)
const VERDE: Color = Color(0.31, 1.0, 0.55)
const GRIS_TEXTO: Color = Color(0.82, 0.83, 0.88)

var modo: String = "teclado"
var tarjeta_camara: Button
var tarjeta_teclado: Button
var lbl_estado_camara: Label
var boton_detector: Button
var boton_iniciar: Button
var boton_volver: Button
var _estilos: Dictionary = {}


func _init() -> void:
	name = "SelectorControl"
	color = Color(0, 0, 0, 0.72)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_estilos()
	_armar()


func _ready() -> void:
	_elegir(ChannelData.modo_control)
	_actualizar_estado()
	boton_iniciar.grab_focus()


func _process(_delta: float) -> void:
	_actualizar_estado()


func _armar() -> void:
	var centro: CenterContainer = CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var ventana: PanelContainer = PanelContainer.new()
	ventana.add_theme_stylebox_override("panel", _estilos["ventana"])
	centro.add_child(ventana)
	var caja: VBoxContainer = VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	ventana.add_child(caja)

	caja.add_child(_texto("¿CÓMO QUIERES PELEAR?", 32, Color.WHITE, true))
	caja.add_child(_texto("Puedes cambiarlo antes de cada transmisión.", 16, Color(0.66, 0.68, 0.75), true))

	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 22)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(fila)
	tarjeta_camara = _tarjeta("CÁMARA", Dibujo.Tipo.CAMARA,
			"Pelea con tu cuerpo: la cámara\ndetecta tus golpes, guardia\ny esquivas.")
	lbl_estado_camara = tarjeta_camara.get_node("Caja/Estado")
	boton_detector = Button.new()
	boton_detector.text = "Abrir detector de cámara"
	boton_detector.focus_mode = Control.FOCUS_ALL
	boton_detector.add_theme_font_size_override("font_size", 14)
	boton_detector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton_detector.pressed.connect(_abrir_detector)
	tarjeta_camara.get_node("Caja").add_child(boton_detector)
	tarjeta_teclado = _tarjeta("TECLADO", Dibujo.Tipo.TECLADO,
			"P recto · L / Ñ ganchos · O uppercut\nEspacio patada · Shift defender\nA / D esquivar")
	var estado_teclado: Label = tarjeta_teclado.get_node("Caja/Estado")
	estado_teclado.text = "Siempre disponible"
	estado_teclado.add_theme_color_override("font_color", VERDE)
	fila.add_child(tarjeta_camara)
	fila.add_child(tarjeta_teclado)
	tarjeta_camara.pressed.connect(_elegir.bind("camara"))
	tarjeta_teclado.pressed.connect(_elegir.bind("teclado"))

	var botones: HBoxContainer = HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 18)
	caja.add_child(botones)
	boton_volver = Button.new()
	boton_volver.text = "Volver"
	boton_volver.custom_minimum_size = Vector2(150, 52)
	boton_volver.pressed.connect(func() -> void:
		cancelado.emit()
		queue_free())
	boton_iniciar = Button.new()
	boton_iniciar.text = "¡Iniciar Live!"
	boton_iniciar.custom_minimum_size = Vector2(260, 52)
	boton_iniciar.add_theme_font_size_override("font_size", 22)
	for estado in ["normal", "hover", "pressed", "focus"]:
		boton_iniciar.add_theme_stylebox_override(estado, _estilos["iniciar_" + estado] if _estilos.has("iniciar_" + estado) else _estilos["iniciar_normal"])
	boton_iniciar.add_theme_color_override("font_color", Color.WHITE)
	boton_iniciar.add_theme_color_override("font_hover_color", Color.WHITE)
	boton_iniciar.add_theme_color_override("font_focus_color", Color.WHITE)
	boton_iniciar.add_theme_color_override("font_pressed_color", Color.WHITE)
	boton_iniciar.pressed.connect(func() -> void:
		ChannelData.modo_control = modo
		elegido.emit(modo)
		queue_free())
	botones.add_child(boton_volver)
	botones.add_child(boton_iniciar)


## Tarjeta grande que se puede tocar: dibujo, título, descripción y estado.
func _tarjeta(titulo: String, dibujo: Dibujo.Tipo, descripcion: String) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(340, 300)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	var caja: VBoxContainer = VBoxContainer.new()
	caja.name = "Caja"
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_top = 18
	caja.offset_left = 14
	caja.offset_right = -14
	caja.add_theme_constant_override("separation", 8)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(caja)
	var icono: Dibujo = Dibujo.new()
	icono.tipo = dibujo
	icono.custom_minimum_size = Vector2(0, 56)
	caja.add_child(icono)
	caja.add_child(_texto(titulo, 26, Color.WHITE, true))
	caja.add_child(_texto(descripcion, 15, GRIS_TEXTO, true))
	var estado: Label = _texto("", 15, GRIS_TEXTO, true)
	estado.name = "Estado"
	caja.add_child(estado)
	return b


func _elegir(nuevo: String) -> void:
	modo = nuevo
	_pintar(tarjeta_camara, modo == "camara")
	_pintar(tarjeta_teclado, modo == "teclado")


func _pintar(tarjeta: Button, elegida: bool) -> void:
	tarjeta.set_pressed_no_signal(elegida)
	var base: String = "tarjeta_elegida" if elegida else "tarjeta"
	for estado in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		tarjeta.add_theme_stylebox_override(estado, _estilos[base])


func _actualizar_estado() -> void:
	var conectada: bool = CamaraEnVivo.conectada()
	lbl_estado_camara.text = "Cámara detectada" if conectada else "Cámara no detectada"
	lbl_estado_camara.add_theme_color_override("font_color", VERDE if conectada else Color(1.0, 0.55, 0.45))
	boton_detector.visible = not conectada


func _abrir_detector() -> void:
	if CamaraEnVivo.abrir_detector():
		boton_detector.text = "Abriendo... (espera unos segundos)"
	else:
		boton_detector.text = "No se encontró la carpeta camara/"


func _texto(t: String, tam: int, c: Color, centrado: bool) -> Label:
	var l: Label = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centrado:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _crear_estilos() -> void:
	var ventana: StyleBoxFlat = StyleBoxFlat.new()
	ventana.bg_color = Color(0.07, 0.07, 0.1)
	ventana.border_color = Color.WHITE
	ventana.set_border_width_all(4)
	ventana.set_corner_radius_all(18)
	ventana.set_content_margin_all(28)
	ventana.shadow_color = Color(0, 0, 0, 0.6)
	ventana.shadow_size = 8
	_estilos["ventana"] = ventana
	var tarjeta: StyleBoxFlat = StyleBoxFlat.new()
	tarjeta.bg_color = Color(0.13, 0.13, 0.18)
	tarjeta.border_color = Color(0.43, 0.43, 0.5)
	tarjeta.set_border_width_all(2)
	tarjeta.set_corner_radius_all(14)
	_estilos["tarjeta"] = tarjeta
	var elegida: StyleBoxFlat = tarjeta.duplicate()
	elegida.bg_color = Color(0.24, 0.07, 0.07)
	elegida.border_color = ROJO
	elegida.set_border_width_all(5)
	_estilos["tarjeta_elegida"] = elegida
	var iniciar: StyleBoxFlat = StyleBoxFlat.new()
	iniciar.bg_color = ROJO
	iniciar.set_corner_radius_all(12)
	_estilos["iniciar_normal"] = iniciar
	var iniciar_hover: StyleBoxFlat = iniciar.duplicate()
	iniciar_hover.bg_color = ROJO.lightened(0.15)
	iniciar_hover.border_color = Color.WHITE
	iniciar_hover.set_border_width_all(3)
	_estilos["iniciar_hover"] = iniciar_hover
	_estilos["iniciar_focus"] = iniciar_hover


## Dibujo simple de una cámara o de un teclado (sin imágenes ni emojis).
class Dibujo extends Control:
	enum Tipo { CAMARA, TECLADO }
	var tipo: Tipo = Tipo.CAMARA

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		var claro: Color = Color(0.9, 0.9, 0.92)
		if tipo == Tipo.CAMARA:
			draw_rect(Rect2(c - Vector2(42, 26), Vector2(84, 52)), claro)
			draw_circle(c, 20.0, Color(0.16, 0.16, 0.19))
			draw_circle(c, 9.0, Color(0.47, 0.67, 1.0))
			draw_circle(c + Vector2(30, -16), 4.0, Color(0.89, 0.13, 0.11))
		else:
			for i in 5:
				draw_rect(Rect2(c + Vector2(-82 + i * 34, -26), Vector2(28, 26)), claro)
			draw_rect(Rect2(c + Vector2(-50, 6), Vector2(100, 18)), claro)
