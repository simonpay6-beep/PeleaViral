# Audio de PeleaViral

Todo el sonido lo maneja `audio_manager.gd` (autoload `Audio`). **No hay que tocar código**:
copien el archivo con el nombre exacto en la carpeta indicada y Godot lo usa solo.
Si falta un archivo, ese sonido simplemente no suena.

Formatos: `.ogg` (recomendado), `.wav` o `.mp3`. La música se repite en bucle automáticamente.

## Música — `assets/audio/musica/`

| Archivo | Cuándo suena |
|---|---|
| `menu` | Menú principal (`inicio.tscn`) |
| `intro` | Desde la bienvenida (teléfono) hasta configurar el directo: `phone_intro`, `netube_platform` y `channel_dashboard`. Sigue sonando sin reiniciarse entre esas pantallas |
| `canal` | Pantalla de resultados (`video_results.tscn`) |
| `pelea` | Todas las peleas (y el tutorial). Al vencer al rival baja de volumen para que se oigan los sonidos del K.O. |
| `pelea_jefe` | Pelea del nivel 3 (opcional: si no existe, suena `pelea`) |
| `final` | Cinemática final del nivel 3 |

## Efectos — `assets/audio/sfx/`

| Archivo | Cuándo suena |
|---|---|
| `clic` | Cualquier botón del juego |
| `campana` | Empieza una pelea |
| `puno_aire` | El jugador lanza un puñetazo (conecte o no) |
| `patada_aire` | El jugador lanza una patada |
| `golpe` | Tu golpe le pega al rival |
| `bloqueo` | Tú o el rival bloquean un golpe |
| `esquiva` | Esquivas un ataque |
| `aviso_ataque` | El rival prepara un ataque (la señal para defenderte) |
| `recibir_golpe` | El rival te pega |
| `guardia_rota` | Se te rompe la guardia |
| `guardia_recuperada` | Recuperas la guardia |
| `noqueado` | El rival queda noqueado de pie |
| `ko` | K.O. al rival |
| `burla` | El rival se burla |
| `furia` | El rival entra en modo furia |
| `victoria` | Ganas la pelea (fanfarria corta) |
| `derrota` | Pierdes la pelea |

## Ajustes rápidos (arriba de `audio_manager.gd`)

- `VOLUMEN_MUSICA_DB` / `VOLUMEN_SFX_DB`: volumen (en dB; -6 ≈ la mitad).
- `VOLUMEN_POR_MUSICA`: volumen propio de una canción (la de pelea suena a -0,8 dB).
- `MUSICA_POR_ESCENA`: qué música va en cada escena.
- `SFX_POR_EVENTO`: qué efecto suena con cada evento de la pelea.
- Desde cualquier script: `Audio.sfx("nombre")` o `Audio.musica("nombre")`.

## Consejos

- Efectos cortos (menos de 1 s) y sin silencio al principio, o se sentirán atrasados.
- Música en `.ogg`, sin silencio al final, para que el bucle no tenga un hueco.
- Si usan sonidos de internet, revisen la licencia (CC0 es la más segura) y anoten
  el autor en los créditos.
