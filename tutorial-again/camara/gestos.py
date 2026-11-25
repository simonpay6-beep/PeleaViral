"""Reconocimiento de gestos de pelea a partir de los puntos del cuerpo.

No depende de la cámara ni de MediaPipe: recibe los puntos ya detectados y
devuelve lo que el juego necesita (el mismo idioma que entiende el juego):

    {"defensa": bool,
     "esquiva": "IZQUIERDA" | "CENTRO" | "DERECHA",
     "ataque": "NINGUNO" | "RECTO_DER" | "HOOK_IZQ" | "UPPERCUT_DER" | "PATADA_DER" ...,
     "movimiento": "DEFENSA + RECTO DER"}   <- texto que se muestra en el juego

Coordenadas: x e y van de 0 a 1 (y crece hacia abajo) y ya están en ESPEJO
(como cuando te ves en un espejo: tu mano izquierda queda a la izquierda).
z es la profundidad que da MediaPipe (más negativo = más cerca de la cámara).

Todas las distancias se miden en "anchos de hombros", así no importa si estás
cerca o lejos de la cámara. Los UMBRALES de abajo se pueden ajustar.
"""
from collections import deque
from dataclasses import dataclass

# --- Índices de los puntos del cuerpo (MediaPipe Pose) ---
NARIZ = 0
HOMBRO_IZQ, HOMBRO_DER = 11, 12
CODO_IZQ, CODO_DER = 13, 14
MUNECA_IZQ, MUNECA_DER = 15, 16
CADERA_IZQ, CADERA_DER = 23, 24
RODILLA_IZQ, RODILLA_DER = 25, 26

# --- UMBRALES (ajustables) ---
DEFENSA_DISTANCIA = 0.85     # mano a menos de esto de la nariz = cubriéndose la cara
ESQUIVA_INCLINACION = 0.45   # cabeza corrida hacia un lado (en anchos de hombros)
VEL_GOLPE = 4.0              # velocidad mínima de un golpe (anchos de hombros por segundo)
VEL_RECTO_Z = 3.0            # velocidad hacia la cámara para el recto
VENTANA_VELOCIDAD = 0.12     # segundos que se miran para medir la velocidad
DURACION_GOLPE = 0.2         # cuánto se mantiene el aviso de un golpe
RECARGA_GOLPE = 0.35         # tiempo mínimo entre dos golpes de la misma mano
PATADA_ALTURA = 0.25         # rodilla a esta distancia (o menos) de la altura de la cadera
VISIBLE = 0.5                # visibilidad mínima para confiar en un punto


@dataclass
class Punto:
    x: float
    y: float
    z: float = 0.0
    visibilidad: float = 1.0


NOMBRES = {"RECTO": "RECTO", "HOOK": "GANCHO", "UPPERCUT": "UPPERCUT", "PATADA": "PATADA"}


class Gestos:
    def __init__(self):
        self._historia = {"IZQ": deque(), "DER": deque()}
        self._ultimo_golpe = {"IZQ": -99.0, "DER": -99.0}
        self._ataque = "NINGUNO"
        self._ataque_hasta = -99.0
        self._ultima_patada = -99.0
        self._centro = None          # posición "normal" del cuerpo (se aprende sola)

    # ------------------------------------------------------------------ uso
    def actualizar(self, puntos, t):
        """puntos: lista de 33 Punto (o None si no se ve a nadie); t: segundos."""
        if not puntos:
            return self._resultado(False, "CENTRO", t, sin_persona=True)
        hi, hd = puntos[HOMBRO_IZQ], puntos[HOMBRO_DER]
        if hi.visibilidad < VISIBLE or hd.visibilidad < VISIBLE:
            return self._resultado(False, "CENTRO", t, sin_persona=True)
        escala = max(_dist(hi, hd), 1e-3)
        medio = Punto((hi.x + hd.x) / 2, (hi.y + hd.y) / 2, (hi.z + hd.z) / 2)
        nariz = puntos[NARIZ]

        defensa = self._defensa(puntos, nariz, medio, escala)
        esquiva = self._esquiva(puntos, nariz, medio, escala)
        for lado, (muneca, hombro) in {"IZQ": (MUNECA_IZQ, HOMBRO_IZQ), "DER": (MUNECA_DER, HOMBRO_DER)}.items():
            golpe = self._golpe(lado, puntos[muneca], puntos[hombro], medio, escala, t)
            if golpe:
                self._lanzar(golpe, t)
        patada = self._patada(puntos, escala, t)
        if patada:
            self._lanzar(patada, t)
        return self._resultado(defensa, esquiva, t)

    # ----------------------------------------------------------- defensa
    def _defensa(self, puntos, nariz, medio, escala):
        for m in (MUNECA_IZQ, MUNECA_DER):
            p = puntos[m]
            if p.visibilidad >= VISIBLE and _dist(p, nariz) / escala < DEFENSA_DISTANCIA and p.y < medio.y:
                return True
        return False

    # ----------------------------------------------------------- esquiva
    def _esquiva(self, puntos, nariz, medio, escala):
        ci, cd = puntos[CADERA_IZQ], puntos[CADERA_DER]
        if ci.visibilidad >= VISIBLE and cd.visibilidad >= VISIBLE:
            referencia = (ci.x + cd.x) / 2          # con las caderas a la vista, ellas son el centro
        else:
            # Sin caderas: el centro es la posición normal de los hombros, que se aprende
            # despacio mientras el jugador está derecho.
            if self._centro is None:
                self._centro = medio.x
            referencia = self._centro
        inclinacion = (nariz.x - referencia) / escala
        if self._centro is not None and abs(inclinacion) < 0.15:
            self._centro += (medio.x - self._centro) * 0.05
        if inclinacion < -ESQUIVA_INCLINACION:
            return "IZQUIERDA"
        if inclinacion > ESQUIVA_INCLINACION:
            return "DERECHA"
        return "CENTRO"

    # ----------------------------------------------------------- golpes
    def _golpe(self, lado, muneca, hombro, medio, escala, t):
        h = self._historia[lado]
        if muneca.visibilidad < VISIBLE:
            h.clear()
            return None
        h.append((t, muneca.x / escala, muneca.y / escala, (muneca.z - medio.z) / escala))
        while h and t - h[0][0] > VENTANA_VELOCIDAD:
            h.popleft()
        if len(h) < 2 or t - self._ultimo_golpe[lado] < RECARGA_GOLPE:
            return None
        t0, x0, y0, z0 = h[0]
        dt = t - t0
        if dt < 0.04:
            return None
        vx, vy, vz = (muneca.x / escala - x0) / dt, (muneca.y / escala - y0) / dt, ((muneca.z - medio.z) / escala - z0) / dt
        # hacia el centro del cuerpo: la mano izquierda va a la derecha (+x) y la derecha a la izquierda
        hacia_centro = vx if lado == "IZQ" else -vx
        alto_hombro = medio.y / escala
        empezo_abajo = y0 > alto_hombro + 0.3
        termina_arriba = muneca.y / escala < alto_hombro + 0.2
        cerca_de_la_cara = abs(muneca.y / escala - alto_hombro) < 0.9

        candidatos = []
        if -vy > VEL_GOLPE and empezo_abajo and termina_arriba:
            candidatos.append((-vy / VEL_GOLPE, "UPPERCUT"))
        if hacia_centro > VEL_GOLPE and cerca_de_la_cara:
            candidatos.append((hacia_centro / VEL_GOLPE, "HOOK"))
        if -vz > VEL_RECTO_Z and cerca_de_la_cara:
            candidatos.append((-vz / VEL_RECTO_Z, "RECTO"))
        if not candidatos:
            return None
        self._ultimo_golpe[lado] = t
        h.clear()
        return max(candidatos)[1] + "_" + lado

    def _patada(self, puntos, escala, t):
        if t - self._ultima_patada < RECARGA_GOLPE * 2:
            return None
        for rodilla, cadera, lado in ((RODILLA_IZQ, CADERA_IZQ, "IZQ"), (RODILLA_DER, CADERA_DER, "DER")):
            r, c = puntos[rodilla], puntos[cadera]
            if r.visibilidad >= VISIBLE and c.visibilidad >= VISIBLE and (r.y - c.y) / escala < PATADA_ALTURA:
                self._ultima_patada = t
                return "PATADA_" + lado
        return None

    # ----------------------------------------------------------- salida
    def _lanzar(self, golpe, t):
        self._ataque = golpe
        self._ataque_hasta = t + DURACION_GOLPE

    def _resultado(self, defensa, esquiva, t, sin_persona=False):
        if t > self._ataque_hasta:
            self._ataque = "NINGUNO"
        partes = []
        if sin_persona:
            partes.append("NO TE VEO")
        if defensa:
            partes.append("DEFENSA")
        if esquiva != "CENTRO":
            partes.append("ESQUIVA " + ("IZQ" if esquiva == "IZQUIERDA" else "DER"))
        if self._ataque != "NINGUNO":
            tipo, lado = self._ataque.split("_")
            partes.append(NOMBRES[tipo] + ("" if tipo == "PATADA" else " " + lado))
        return {"defensa": defensa, "esquiva": esquiva, "ataque": self._ataque, "movimiento": " + ".join(partes)}


def _dist(a, b):
    return ((a.x - b.x) ** 2 + (a.y - b.y) ** 2) ** 0.5
