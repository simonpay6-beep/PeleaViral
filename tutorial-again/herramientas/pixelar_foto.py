#!/usr/bin/env python3
"""Convierte una FOTO real en el estilo de los puños (semitono de puntos blanco/negro + contorno).

Uso:   python3 pixelar_foto.py foto.jpg salida.png [ancho_final]

- Si la foto no tiene transparencia, se quita el fondo liso (el color de las esquinas).
- Sirve para reemplazar assets/ui/pie.png por una foto real de un zapato / pie:
  fondo liso, el pie en el centro, vista desde abajo (de la suela) para que parezca la patada.
Requiere: pip install pillow numpy
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

PERIODO = 9.0      # tamaño de los puntos (los puños usan ~11)


def trama(tono, periodo, angulo=45.0):
    h, w = tono.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a = np.deg2rad(angulo)
    u = (xx * np.cos(a) + yy * np.sin(a)) / periodo
    v = (-xx * np.sin(a) + yy * np.cos(a)) / periodo
    return tono > (np.cos(2 * np.pi * u) + np.cos(2 * np.pi * v)) / 4.0 + 0.5


def main(entrada, salida, ancho=420):
    im = Image.open(entrada).convert("RGBA")
    im = im.resize((ancho, int(im.height * ancho / im.width)), Image.LANCZOS)
    a = np.array(im)
    if a[..., 3].min() == 255:                      # sin transparencia: quitar fondo liso
        fondo = np.median(np.array([a[0, 0], a[0, -1], a[-1, 0], a[-1, -1]])[:, :3], axis=0)
        dist = np.abs(a[..., :3].astype(np.float32) - fondo).sum(axis=2)
        a[..., 3] = np.where(dist > 60, 255, 0)
    mascara = a[..., 3] > 128
    gris = np.array(Image.fromarray(a[..., :3]).convert("L")).astype(np.float32) / 255.0
    gris = np.clip((gris - 0.5) * 1.3 + 0.5, 0, 1)  # un poco más de contraste
    blanco = trama(gris, PERIODO)
    interior = np.array(Image.fromarray((mascara * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(13))) > 128
    v = np.where(blanco, 255, 0).astype(np.uint8)
    out = np.zeros(a.shape, dtype=np.uint8)
    out[..., 0] = out[..., 1] = out[..., 2] = np.where(interior, v, 0)
    out[..., 3] = mascara * 255
    Image.fromarray(out, "RGBA").save(salida)
    print("listo:", salida)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 420)
