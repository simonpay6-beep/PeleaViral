# PeleaViral: cómo está organizado

Resolución del proyecto: **1152 x 648** (la de la tabla de `juego.tscn`).

## Flujo del juego

```
inicio (menú con pv.png) -> phone_intro -> netube_platform -> channel_dashboard -> juego -> channel_dashboard (video 2, 3)
                             (historia)     (crear canal)     (configurar live)   (pelea)        |
                                                                                                  +-> Nivel 3: cinemática final -> cierra el juego
```

`inicio.tscn` es ahora la escena principal: la portada `assets/sprites/pv.png` con botones transparentes
encima de los óvalos JUGAR / INSTRUCCIONES / CREDITOS / SALIR. (Para arrancar directo en `phone_intro`
cambia `run/main_scene` en Proyecto > Configuración.)

`video_results.tscn` sigue existiendo (créditos / reinicio) y usa las mismas rutas.
Todas las rutas de escena están en `scene_router.gd` (autoload `SceneRouter`).

## Árbol de `juego.tscn`

Valores exactos de la tabla. El orden importa: lo de abajo se dibuja encima.

| Nodo | Tipo | Posición | Tamaño |
|---|---|---|---|
| juego | Control (script `fightSystem.gd`) | 0, 0 | 1152, 648 |
| Fondo | ColorRect | 0, 0 | 1152, 648 |
| ↳ ImagenFondo | TextureRect (imagen del nivel) | -30, 0 | 1212, 648 |
| EnemigoSprite | AnimatedSprite2D | 390, 310 | (se ajusta con Scale = 0.34) |
| ↳ Moscas | AnimatedSprite2D (solo cuando está en el piso) | 0, 0 | |
| **ManosJugador** | Node2D (script `manos_jugador.gd`) | 0, 0 | |
| ↳ PunoIzquierdo / PunoDerecho / Pie | Sprite2D | animados por código | |
| UI_Combate | Control | 0, 0 | 1152, 648 |
| ↳ TituloNivel | Label | 40, 18 | 1070, 35 |
| ↳ VidaEnemigo | ProgressBar (**oculta**: la vida del rival no se ve) | 40, 65 | 700, 30 |
| ↳ DialogoEnemigo | Label (Autowrap = Word Smart) | 40, 105 | 700, 65 |
| ↳ EstadoEnemigoTexto | Label (**oculto**: no se muestra el nombre del estado) | 140, 230 | 500, 120 |
| ↳ VidaJugador | ProgressBar | 40, 570 | 700, 36 |
| ↳ EstadoJugadorTexto | Label | 40, 530 | 700, 35 |
| ↳ LiveOverlay | Escena `live_overlay.tscn` (cuadrado, opaco) | 780, 65 | 360, 360 |
| ↳ FlashDano | ColorRect (destello rojo al recibir un golpe) | 0, 0 | 1152, 648 |
| ↳ PanelControles | Escena `controles_panel.tscn` (ayuda de controles) | 96, 40 | 960, 540 |
| **PantallaCinematica** | ColorRect (**siempre el último**, oculto) | 0, 0 | 1152, 648 |
| ↳ TextoCinematica | Label (Autowrap = Word Smart) | 80, 60 | 992, 528 |

`UI_Combate` y `Fondo` tienen `mouse_filter = Ignore` para no bloquear clics.

## Señales

| Desde | Señal | Hacia |
|---|---|---|
| PantallaCinematica | `gui_input` | `fightSystem.gd::_on_pantalla_cinematica_gui_input` (clic = ENTER para avanzar) |
| PanelControles | `cerrado` (botón "Entendido") | `fightSystem.gd::_on_controles_cerrado` |
| Menú: Jugar / Instrucciones / Creditos / Salir | `pressed` | `inicio.gd::_on_*_pressed` |
| Cámara (adapter) | `ataque`, `conectada` | `ejecutar_ataque_jugador`, `_on_camara_conectada` (conectadas por código) |
| Teclado (adapter) | `ataque` | `ejecutar_ataque_jugador` |
| `EventBus` | `chat_message`, `views_changed`, `evento_combate` | `live_overlay.gd` (el chat reacciona a la pelea) |

Los botones de las demás escenas (`phone_intro`, `netube_platform`, `channel_dashboard`, `video_results`)
ya conectaban sus señales por código con `.pressed.connect(...)`; se dejaron igual.

## Patrones de diseño aplicados

| Patrón | Dónde | Qué resuelve |
|---|---|---|
| **State** | `combat/estados_enemigo.gd` | Los 10 estados del enemigo (antes un `enum` + un `match` enorme + comparaciones sueltas). Cada estado dice su animación, texto, color y cómo reacciona a los golpes. |
| **Strategy** | `combat/niveles.gd` | Tutorial, Nivel 1, 2 y 3 (jefe invencible). Antes había `if nivel_actual == 3` repetido en 9 sitios. |
| **Factory Method** | `Niveles.crear()`, `EstadosEnemigo.crear()` | Crean la estrategia / el estado a partir de un número. |
| **Adapter** | `combat/entradas.gd` | Cámara Python (UDP) y teclado hablan el mismo idioma: `defensa`, `esquiva`, señal `ataque`. |
| **Observer** | `event_bus.gd` | El combate publica chat y views; el panel del directo se suscribe. Ya no hay que buscar el chat dentro del árbol. |
| **Singleton + Facade** | `EventBus`, `SceneRouter`, `ChannelData` | Un solo dueño de eventos, rutas de escena y datos del canal (`reset_campaign()`). |

Dónde cambiar cada cosa:
- Daño, vida, velocidad y textos de historia de un nivel -> su clase en `combat/niveles.gd`.
- Cómo se ve o reacciona un estado del enemigo -> `combat/estados_enemigo.gd`.
- Controles (teclas, puerto UDP) -> `combat/entradas.gd`.
- Dificultad (velocidad / multiplicador de views) -> `DIFICULTADES` arriba de `fightSystem.gd`.
- Cerrar o reiniciar al final -> `CERRAR_JUEGO_AL_FINAL` arriba de `fightSystem.gd`.

## Controles

Están explicados en el juego (menú > INSTRUCCIONES y al empezar el tutorial; `H` la abre y cierra) y en `docs/CONTROLES.md`.

## Imágenes y animaciones

| Imagen | Dónde se usa |
|---|---|
| `assets/sprites/pv.png` | portada del menú (`inicio.tscn`) |
| `assets/sprites/bateria1..5` / `bateriablack` | vida del jugador (copias sin fondo negro en `assets/ui/`) |
| `assets/sprites/punch.png` | puños del jugador (copia recortada `assets/ui/puno.png`, duplicada y espejada) |
| `assets/sprites/animations;lv1/*` | animaciones del enemigo (`combat/enemigo_frames.tres`) |
| `forest.png` | fondo del tutorial y del Nivel 1 |
| `assets/fondos/calle.png` / `arena.png` | fondos creados para el Nivel 2 y el Nivel 3 |
| `assets/fondos/escritorio.png` | fondo creado para phone_intro, netube, channel_dashboard y video_results |
| `assets/ui/pie.png` | pie para la patada (creado) |

Animaciones del enemigo (cada ataque tiene 4 versiones): `golpe_preparar` (levanta el guante) -> `golpe` (impacta,
frame del puñetazo rojo) / `golpe_bloqueo` (tú te defendiste: figura azul que rebota) / `golpe_fallo` (esquivaste).
Igual con `golpe_fuerte_*` y `patada_*`. Además `idle`, `bloqueo`, `risa`, `burla`, `herido`, `noqueado`
y `en_el_piso` (cuerpo + `moscas`). Si algún día haces arte por nivel, nómbralo `n1_golpe`, `n2_idle`,
`n3_patada_bloqueo`... y se usará solo.

Los puños no tienen animación dibujada: `manos_jugador.gd` los mueve por código (adelante y atrás, guardia
delante de la cara, caída al romperse la guardia, esquiva, sacudida al recibir un golpe).

El enemigo ya no se tiñe de color por estado (eso hacía que los sprites se vieran mal); solo se tiñe un poco por
nivel (Nivel 2 anaranjado, Nivel 3 rojizo; está en `combat/niveles.gd`, variable `tinte`).

`phone_intro.tscn` usa un teléfono provisional hecho con rectángulos: asigna tu sprite en
`PhoneButton > Texture Normal`.

## Si Godot marca un error al abrir

- **"Node not found: ..."**: el nombre o la ruta del `$Nodo` en el script no coincide con el árbol de la escena. Renombra el nodo o ajusta la ruta.
- **"Cannot assign ... of type X"**: el tipo en `@onready var x: Tipo` no es el del nodo (por ejemplo `TextureButton` declarado como `Button`). Cambia el tipo al que dice el error.
- **Una señal no hace nada**: en Nodo > Señales comprueba que apunta al método correcto.
- Si se queja de un `class_name` desconocido (`Niveles`, `EstadosEnemigo`, `Entradas`), cierra y vuelve a abrir el proyecto para que reescanee los scripts.

## Scripts sin escena (no se tocaron)

`enemigo.gd`, `fight_beta_2.gd`, `hitzone.gd`, `player_healthbar.gd`, `state_manager.gd` y `pantalla_inicio.gd`
ya no tienen su `.tscn` en el proyecto y ninguna escena los usa. Siguen ahí por si los necesitas.

## Cambios de la ronda 3

- **Configurar video** (`channel_dashboard.tscn`): usa `tema_caricatura.tres` (estética del menú: negro con borde blanco,
  rojo al pasar el mouse, texto con contorno) y el fondo `assets/fondos/dashboard.png`, hecho con el degradado y el
  personaje de `pv.png`. Para dar ese estilo a otra escena, asigna el tema al nodo raíz (propiedad Theme).
- **Cursor**: logo de Godot (`assets/ui/cursor.png`), configurado en Proyecto > Configuración > Display > Mouse Cursor.
- **Puños**: `assets/ui/puno.png` tiene el antebrazo reconstruido y muy largo, así que el corte del sprite nunca queda a la vista.
- **Fondos** `calle`, `arena`, `escritorio`: 2 colores con trama ordenada, igual que `forest.png`
  (generados por código).
- **Pie**: sombreado + semitono de puntos como los puños. No es una foto real: para usar una, `herramientas/pixelar_foto.py`.
- **Jugabilidad estilo Punch-Out**: un golpe por pulsación o gesto (mantener no repite); el rival no contraataca justo después de
  recibir un golpe (`REPOSO_TRAS_GOLPE`); las patadas no se bloquean: vienen por un lado y se esquivan hacia el contrario
  (`PATADA_REQUIERE_LADO` en `fightSystem.gd` para exigir o no el lado).
