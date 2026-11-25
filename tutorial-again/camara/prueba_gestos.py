"""Pruebas de gestos.py con cuerpos simulados (no necesita cámara).
Uso: python prueba_gestos.py
"""
import gestos as g
from gestos import Punto

fallas = 0


def check(cond, nombre):
    global fallas
    print(("  OK   " if cond else "  FALLA ") + nombre)
    if not cond:
        fallas += 1


def cuerpo(**cambios):
    """Persona de pie, derecha, frente a la cámara (hombros de 0.4 a 0.6, ancho 0.2)."""
    p = [Punto(0.5, 0.9, 0.0, 0.0) for _ in range(33)]
    p[g.NARIZ] = Punto(0.5, 0.25)
    p[g.HOMBRO_IZQ], p[g.HOMBRO_DER] = Punto(0.4, 0.4), Punto(0.6, 0.4)
    p[g.CODO_IZQ], p[g.CODO_DER] = Punto(0.38, 0.55), Punto(0.62, 0.55)
    p[g.MUNECA_IZQ], p[g.MUNECA_DER] = Punto(0.4, 0.62), Punto(0.6, 0.62)
    p[g.CADERA_IZQ], p[g.CADERA_DER] = Punto(0.44, 0.8), Punto(0.56, 0.8)
    p[g.RODILLA_IZQ], p[g.RODILLA_DER] = Punto(0.44, 1.0), Punto(0.56, 1.0)
    for k, v in cambios.items():
        p[getattr(g, k)] = v
    return p


def secuencia(det, cuadros, t0=0.0, paso=1 / 30):
    """Pasa varios cuadros y devuelve el último resultado y todos los ataques vistos."""
    ataques, r = [], None
    for i, c in enumerate(cuadros):
        r = det.actualizar(c, t0 + i * paso)
        if r["ataque"] != "NINGUNO" and r["ataque"] not in ataques:
            ataques.append(r["ataque"])
    return r, ataques


print("== Quieto")
d = g.Gestos()
r, a = secuencia(d, [cuerpo()] * 10)
check(r == {"defensa": False, "esquiva": "CENTRO", "ataque": "NINGUNO", "movimiento": ""}, "de pie y quieto: nada")
check(d.actualizar(None, 1.0)["movimiento"] == "NO TE VEO", "sin persona: avisa que no te ve")

print("== Defensa")
r, _ = secuencia(g.Gestos(), [cuerpo(MUNECA_DER=Punto(0.52, 0.28))] * 5)
check(r["defensa"] and r["movimiento"] == "DEFENSA", "mano delante de la cara = defensa")

print("== Esquivas")
r, _ = secuencia(g.Gestos(), [cuerpo(NARIZ=Punto(0.36, 0.27))] * 5)
check(r["esquiva"] == "IZQUIERDA", "cabeza corrida a la izquierda = esquiva izquierda")
r, _ = secuencia(g.Gestos(), [cuerpo(NARIZ=Punto(0.64, 0.27))] * 5)
check(r["esquiva"] == "DERECHA" and r["movimiento"] == "ESQUIVA DER", "a la derecha = esquiva derecha")
sin_caderas = dict(CADERA_IZQ=Punto(0.44, 1.2, 0, 0.1), CADERA_DER=Punto(0.56, 1.2, 0, 0.1))
d = g.Gestos()
secuencia(d, [cuerpo(**sin_caderas)] * 10)
r, _ = secuencia(d, [cuerpo(NARIZ=Punto(0.62, 0.27), **sin_caderas)] * 3, t0=1.0)
check(r["esquiva"] == "DERECHA", "sin caderas a la vista también detecta la esquiva")

print("== Golpes")
# Recto derecho: la muñeca va rápido hacia la cámara (z baja) a la altura de la cara.
cuadros = [cuerpo(MUNECA_DER=Punto(0.58, 0.35, -0.02 * i)) for i in range(8)]
_, a = secuencia(g.Gestos(), cuadros)
check(a == ["RECTO_DER"], "recto derecho")
# Gancho izquierdo: la mano izquierda barre rápido hacia el centro a la altura de la cara.
cuadros = [cuerpo(MUNECA_IZQ=Punto(0.25 + 0.03 * i, 0.32)) for i in range(8)]
_, a = secuencia(g.Gestos(), cuadros)
check(a == ["HOOK_IZQ"], "gancho izquierdo")
cuadros = [cuerpo(MUNECA_DER=Punto(0.75 - 0.03 * i, 0.32)) for i in range(8)]
_, a = secuencia(g.Gestos(), cuadros)
check(a == ["HOOK_DER"], "gancho derecho")
# Uppercut derecho: sube rápido desde la cintura hasta el mentón.
cuadros = [cuerpo(MUNECA_DER=Punto(0.58, 0.66 - 0.045 * i)) for i in range(8)]
_, a = secuencia(g.Gestos(), cuadros)
check(a == ["UPPERCUT_DER"], "uppercut derecho")
# Mover la mano despacio no es un golpe.
cuadros = [cuerpo(MUNECA_IZQ=Punto(0.3 + 0.002 * i, 0.32)) for i in range(20)]
_, a = secuencia(g.Gestos(), cuadros)
check(a == [], "mover la mano despacio no golpea")
# Un golpe se avisa un momento y luego vuelve a NINGUNO (el juego necesita la pausa).
d = g.Gestos()
secuencia(d, [cuerpo(MUNECA_IZQ=Punto(0.25 + 0.03 * i, 0.32)) for i in range(8)])
r, _ = secuencia(d, [cuerpo()] * 12, t0=0.4)
check(r["ataque"] == "NINGUNO", "después del golpe vuelve a NINGUNO")

print("== Patada")
_, a = secuencia(g.Gestos(), [cuerpo(RODILLA_DER=Punto(0.56, 0.82))] * 3)
check(a == ["PATADA_DER"], "levantar la rodilla = patada")
r = g.Gestos().actualizar(cuerpo(RODILLA_DER=Punto(0.56, 0.82), MUNECA_DER=Punto(0.52, 0.28)), 0.0)
check(r["movimiento"] == "DEFENSA + PATADA", "texto con dos movimientos a la vez")

print("\n%s" % ("TODO OK" if fallas == 0 else "%d FALLAS" % fallas))
raise SystemExit(1 if fallas else 0)
