extends Node
## Bus global de eventos (autoload "EventBus").
##
## PATRÓN: Observer (publicar / suscribirse) + Singleton (autoload).
##
## fightSystem.gd publica lo que pasa en el combate y NO sabe quién escucha.
## live_overlay.gd (el panel del directo) se suscribe y lo dibuja. Así el
## combate ya no tiene que buscar el chat dentro del árbol de nodos.

## Un mensaje nuevo en el chat del directo.
@warning_ignore("unused_signal")
signal chat_message(usuario: String, mensaje: String)

## Cambiaron las views del directo en curso.
@warning_ignore("unused_signal")
signal views_changed(views: int)

## Algo pasó en la pelea y el chat puede reaccionar. `tipo` puede ser:
## golpe_conecta, bloqueo_rival, burla, noqueado, ko_enemigo, rival_golpea,
## bloqueaste, esquivaste, guardia_rota, guardia_recuperada, derrota.
@warning_ignore("unused_signal")
signal evento_combate(tipo: String)
