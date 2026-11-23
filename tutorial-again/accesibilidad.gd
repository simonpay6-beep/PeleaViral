extends CanvasLayer
## Opciones de accesibilidad (autoload "Accesibilidad").
##
## Modo daltonismo: dibuja ENCIMA de todo el juego un filtro de corrección de
## color (daltonismo.gdshader). Se elige en el panel del canal y se mantiene en
## todas las escenas, porque este nodo vive fuera de ellas.

const MODOS: Dictionary = {
	"Daltonismo: Protanopia": 0,
	"Daltonismo: Deuteranopia": 1,
	"Daltonismo: Tritanopia": 2,
}

var modo_actual: String = ""
var _filtro: ColorRect


func _ready() -> void:
	layer = 100 # encima de todas las escenas
	_filtro = ColorRect.new()
	_filtro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filtro.mouse_filter = Control.MOUSE_FILTER_IGNORE # no bloquea clics
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://daltonismo.gdshader")
	_filtro.material = material
	_filtro.visible = false
	add_child(_filtro)


## Activa el filtro si `nombre` es un modo de daltonismo; si no, lo apaga.
func aplicar(nombre: String) -> void:
	modo_actual = nombre if MODOS.has(nombre) else ""
	_filtro.visible = modo_actual != ""
	if _filtro.visible:
		var material: ShaderMaterial = _filtro.material
		material.set_shader_parameter("tipo", MODOS[modo_actual])
		# La corrección de tritanopia tiñe mucho de violeta: se aplica más suave.
		material.set_shader_parameter("intensidad", 0.55 if MODOS[modo_actual] == 2 else 1.0)


func activo() -> bool:
	return modo_actual != ""
