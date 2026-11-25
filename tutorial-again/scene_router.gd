extends Node
## Cambio de escenas centralizado (autoload "SceneRouter").
##
## PATRÓN: Singleton + Facade. Todas las rutas de escena viven aquí. Si
## renombras una escena, solo cambias esta lista. (Antes channel_dashboard.gd
## cargaba "res://Juego.tscn" con J mayúscula y el archivo es "juego.tscn":
## en Windows funciona, en Linux / exportado no.)

const MENU: String = "res://inicio.tscn"
const INICIO_JUEGO: String = "res://phone_intro.tscn"
const NETUBE: String = "res://netube_platform.tscn"
const ADMIN_CANAL: String = "res://channel_dashboard.tscn"
const JUEGO: String = "res://juego.tscn"
const RESULTADOS: String = "res://video_results.tscn"
const FINAL_PERIODICO: String = "res://final_periodico.tscn"
const FINAL_HOSPITAL: String = "res://final_hospital.tscn"


func go(path: String) -> void:
	Audio.musica_para_escena(path)
	var result: Error = get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("SceneRouter: no se pudo cargar '%s' (error %d)" % [path, result])


## Cierra el juego. Primero detiene el audio y espera un cuadro para que Godot
## libere la reproducción; así se cierra limpio, sin avisos en la consola.
func quit_game() -> void:
	Audio.detener_todo()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
