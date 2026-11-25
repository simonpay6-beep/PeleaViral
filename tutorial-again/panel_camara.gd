class_name PanelCamara
extends Control
## Recuadro de la cámara que va debajo del chat cuando se pelea con la cámara.
## Muestra lo que ve la cámara (imagen que manda el detector de Python), lo que
## está detectando ("DEFENSA", "RECTO DER"...) y, abajo en el centro, el
## personaje que el jugador eligió al crear su canal.
## Se arma por código: solo hay que hacer add_child(PanelCamara.new()).

const TAMANO: Vector2 = Vector2(360.0, 234.0)
const TAMANO_AVATAR: float = 64.0
const AVATAR_POR_DEFECTO: String = "res://assets/avatares/avatar_gallo.png"
const SHADER_CIRCULO: String = "res://avatar_circular.gdshader"
const VERDE: Color = Color(0.31, 1.0, 0.55)
const ROJO: Color = Color(0.89, 0.13, 0.11)

var video: TextureRect
var lbl_estado: Label
var punto_estado: Panel
var lbl_movimiento: Label
var aviso_sin_senal: Label
var avatar: TextureRect
var _punto_verde: StyleBoxFlat
var _punto_rojo: StyleBoxFlat


func _init() -> void:
	name = "PanelCamara"
	size = TAMANO
	custom_minimum_size = TAMANO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armar()


func _armar() -> void:
	# Marco igual al del chat: fondo oscuro, borde blanco y sombra.
	var marco: Panel = Panel.new()
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.07, 0.1)
	estilo.border_color = Color.WHITE
	estilo.set_border_width_all(4)
	estilo.shadow_color = Color(0, 0, 0, 0.6)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(5, 6)
	marco.add_theme_stylebox_override("panel", estilo)
	add_child(marco)

	# Cabecera: etiqueta CAM y estado de la conexión.
	var cam: Label = _etiqueta("CAM", 15, Color.WHITE)
	var fondo_cam: StyleBoxFlat = StyleBoxFlat.new()
	fondo_cam.bg_color = ROJO
	fondo_cam.content_margin_left = 8
	fondo_cam.content_margin_right = 8
	cam.add_theme_stylebox_override("normal", fondo_cam)
	cam.position = Vector2(12, 9)
	add_child(cam)
	_punto_verde = StyleBoxFlat.new()
	_punto_verde.bg_color = VERDE
	_punto_verde.set_corner_radius_all(6)
	_punto_rojo = _punto_verde.duplicate()
	_punto_rojo.bg_color = ROJO
	punto_estado = Panel.new()
	punto_estado.size = Vector2(12, 12)
	punto_estado.position = Vector2(72, 15)
	punto_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(punto_estado)
	lbl_estado = _etiqueta("", 14, Color(0.78, 0.8, 0.86))
	lbl_estado.position = Vector2(90, 9)
	add_child(lbl_estado)

	# Pantalla con la imagen de la cámara (recortada para llenar el cuadro).
	var pantalla: ColorRect = ColorRect.new()
	pantalla.name = "Pantalla"
	pantalla.color = Color(0.02, 0.02, 0.04)
	pantalla.position = Vector2(12, 38)
	pantalla.size = Vector2(TAMANO.x - 24, TAMANO.y - 50)
	pantalla.clip_contents = true
	pantalla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pantalla)
	video = TextureRect.new()
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	video.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pantalla.add_child(video)
	aviso_sin_senal = _etiqueta("SIN SEÑAL DE LA CÁMARA\nAbre el detector: camara/iniciar_camara.bat\nMientras tanto puedes usar el teclado.", 13, Color(0.8, 0.82, 0.9))
	aviso_sin_senal.set_anchors_preset(Control.PRESET_FULL_RECT)
	aviso_sin_senal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_sin_senal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aviso_sin_senal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pantalla.add_child(aviso_sin_senal)

	# Lo que se está detectando, arriba a la derecha de la imagen.
	lbl_movimiento = _etiqueta("", 15, Color(1.0, 0.84, 0.29))
	var fondo_mov: StyleBoxFlat = StyleBoxFlat.new()
	fondo_mov.bg_color = Color(0, 0, 0, 0.8)
	fondo_mov.set_corner_radius_all(7)
	fondo_mov.content_margin_left = 8
	fondo_mov.content_margin_right = 8
	fondo_mov.content_margin_top = 2
	fondo_mov.content_margin_bottom = 2
	lbl_movimiento.add_theme_stylebox_override("normal", fondo_mov)
	lbl_movimiento.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_movimiento.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl_movimiento.position = Vector2(pantalla.size.x - 8, 8)
	pantalla.add_child(lbl_movimiento)

	# Personaje del canal: abajo, justo en el centro, montado sobre el borde.
	var aro: Panel = Panel.new()
	var estilo_aro: StyleBoxFlat = StyleBoxFlat.new()
	estilo_aro.bg_color = Color.WHITE
	estilo_aro.set_corner_radius_all(int(TAMANO_AVATAR))
	aro.add_theme_stylebox_override("panel", estilo_aro)
	aro.size = Vector2(TAMANO_AVATAR + 8, TAMANO_AVATAR + 8)
	aro.position = Vector2(TAMANO.x / 2.0 - aro.size.x / 2.0, TAMANO.y - aro.size.y / 2.0 - 6.0)
	aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(aro)
	avatar = TextureRect.new()
	avatar.name = "Avatar"
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.size = Vector2(TAMANO_AVATAR, TAMANO_AVATAR)
	avatar.position = Vector2(4, 4)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_circulo: ShaderMaterial = ShaderMaterial.new()
	material_circulo.shader = load(SHADER_CIRCULO)
	avatar.material = material_circulo
	aro.add_child(avatar)


func _ready() -> void:
	var textura: Texture2D = ChannelData.avatar_texture
	avatar.texture = textura if textura != null else load(AVATAR_POR_DEFECTO)
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var conectada: bool = CamaraEnVivo.conectada()
	lbl_estado.text = "Cámara conectada" if conectada else "Sin señal"
	punto_estado.add_theme_stylebox_override("panel", _punto_verde if conectada else _punto_rojo)
	video.texture = CamaraEnVivo.textura if conectada else null
	aviso_sin_senal.visible = not conectada or CamaraEnVivo.textura == null
	if conectada and CamaraEnVivo.textura == null:
		aviso_sin_senal.text = "Cámara conectada.\nEsperando la imagen..."
	lbl_movimiento.text = CamaraEnVivo.movimiento if conectada else ""
	lbl_movimiento.visible = lbl_movimiento.text != ""


func _etiqueta(texto: String, tam: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
