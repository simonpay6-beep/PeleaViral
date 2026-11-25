# Controles de PeleaViral

Tu vida es la **batería** de abajo a la izquierda (5 niveles de carga). La vida del rival no se muestra.

## Con la cámara (Python / MediaPipe, puerto UDP 4242)

De pie, con cabeza y hombros a la vista:

| Acción | Gesto |
|---|---|
| Defensa | Sube una mano delante de la cara, sobre la barbilla, tapando la nariz. Mantenla mientras te atacan |
| Esquivar | Inclina el cuerpo a la izquierda o a la derecha |
| Recto | Puñetazo al frente |
| Hook | Gancho lateral, en arco |
| Uppercut | Puñetazo ascendente, de abajo hacia arriba |
| Patada | Levanta la rodilla o el pie |

## Con el teclado (respaldo)

| Tecla | Acción |
|---|---|
| Shift (mantener) | Defender |
| A / D (mantener) | Esquivar a la izquierda / derecha |
| J | Recto |
| K | Hook |
| L | Uppercut |
| Espacio | Patada |
| ENTER o clic | Continuar en las historias / cerrar la ayuda |
| H | Abrir / cerrar la ayuda (en el tutorial) |

## Cómo se pelea

- **Un golpe por gesto / pulsación**: mantener la tecla o el gesto no repite el golpe.
- **Patadas**: no se pueden bloquear. El rival se gira hacia el lado por el que viene la patada: esquiva hacia el lado **contrario**.
- El rival **avisa** cada ataque: levanta el guante o la pierna. Defiéndete o esquiva justo entonces.
  Si lo golpeas **justo cuando prepara** el ataque, lo interrumpes y queda mareado (solo cada 4 segundos y nunca en modo furia).
  Si no, aguanta el golpe y te ataca igual.
- Si le das 3 golpes seguidos (2 en modo furia), **contraataca** con un ataque que no se puede interrumpir.
- Si te cubres demasiado, la **guardia se rompe** y quedas sin defensa 3 segundos (tus puños se ponen rojizos y bajan).
- Burla y "noqueado de pie": el rival recibe más daño.
- El Nivel 3 es un jefe invencible: sus 10 ataques atraviesan cualquier defensa (es parte de la historia).
- Mientras peleas suben las visitas del directo y el chat reacciona a lo que pasa.

*Nota: el script de Python de la cámara no venía en el zip; los gestos de arriba son los que el juego espera
según `combat/entradas.gd` y los textos del tutorial.*
