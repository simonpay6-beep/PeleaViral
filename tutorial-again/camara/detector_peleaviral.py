"""Detector de movimientos de PeleaViral.

Abre la cámara, encuentra tu cuerpo con MediaPipe, reconoce tus golpes,
guardia y esquivas (gestos.py) y se los manda al juego por UDP:
  - puerto 4242: lo detectado, en JSON (unas 30 veces por segundo)
  - puerto 4243: una imagen pequeña de la cámara (limpia, sin dibujos),
                 que el juego muestra debajo del chat

Uso:  python detector_peleaviral.py [--camara 0] [--ventana]
  --camara N   número de la cámara si tienes varias (0 = la primera)
  --ventana    además abre una ventana con la imagen (para probar sin el juego)
Para salir: cierra esta ventana de consola (o Ctrl+C).
"""
import argparse
import json
import os
import socket
import sys
import time
import urllib.request

try:
    import cv2
    import mediapipe as mp
    from mediapipe.tasks.python import BaseOptions, vision
except ImportError:
    print("Faltan librerías. Instálalas con:  pip install -r requirements.txt")
    input("Presiona ENTER para cerrar...")
    sys.exit(1)

from gestos import Gestos, Punto

DESTINO = "127.0.0.1"
PUERTO_DATOS = 4242
PUERTO_VIDEO = 4243
ANCHO_VIDEO = 320            # tamaño de la imagen que se manda al juego
CALIDAD_JPEG = 65
VIDEO_CADA = 2               # se manda una imagen cada 2 cuadros (unas 15 por segundo)
# Modelo de MediaPipe que encuentra el cuerpo (viene en esta carpeta; si falta, se descarga).
MODELO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pose_landmarker_full.task")
URL_MODELO = ("https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
              "pose_landmarker_full/float16/latest/pose_landmarker_full.task")


def crear_detector_de_pose():
    """MediaPipe Tasks (PoseLandmarker): funciona con MediaPipe 0.10 y 1.x."""
    if not os.path.exists(MODELO):
        print("Descargando el modelo del cuerpo (solo la primera vez, unos 9 MB)...")
        urllib.request.urlretrieve(URL_MODELO, MODELO)
    with open(MODELO, "rb") as archivo:   # se lee en memoria: así no fallan rutas con tildes
        modelo = archivo.read()
    opciones = vision.PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_buffer=modelo),
        running_mode=vision.RunningMode.VIDEO, num_poses=1,
        min_pose_detection_confidence=0.5, min_pose_presence_confidence=0.5, min_tracking_confidence=0.5)
    return vision.PoseLandmarker.create_from_options(opciones)


def main():
    args = argparse.ArgumentParser(description="Detector de movimientos de PeleaViral")
    args.add_argument("--camara", type=int, default=0)
    args.add_argument("--ventana", action="store_true")
    opciones = args.parse_args()

    cap = cv2.VideoCapture(opciones.camara, cv2.CAP_DSHOW) if sys.platform == "win32" else cv2.VideoCapture(opciones.camara)
    if not cap.isOpened():
        print("No se pudo abrir la cámara %d. ¿Está conectada o la usa otro programa?" % opciones.camara)
        input("Presiona ENTER para cerrar...")
        return 1
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    gestos = Gestos()
    pose = crear_detector_de_pose()
    t_inicio, ultimo_ms = time.monotonic(), -1
    print("Detector de PeleaViral funcionando. Abre el juego y elige CÁMARA.")
    print("Ponte a 1,5 - 2 m de la cámara, con la cabeza y los hombros a la vista.")

    cuadro_n, ultimo_texto = 0, None
    try:
        while True:
            ok, imagen = cap.read()
            if not ok:
                time.sleep(0.01)
                continue
            t = time.monotonic()
            # Se detecta sobre la imagen ORIGINAL (así izquierda y derecha son las del cuerpo)
            # y después todo se pasa a espejo, como cuando te ves en un espejo.
            rgb = cv2.cvtColor(imagen, cv2.COLOR_BGR2RGB)
            ms = max(int((t - t_inicio) * 1000), ultimo_ms + 1)   # el tiempo siempre debe avanzar
            ultimo_ms = ms
            resultado = pose.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), ms)
            puntos = None
            if resultado.pose_landmarks:
                puntos = [Punto(1.0 - p.x, p.y, p.z, p.visibility if p.visibility is not None else 1.0)
                          for p in resultado.pose_landmarks[0]]
            datos = gestos.actualizar(puntos, t)
            udp.sendto(json.dumps(datos).encode("utf-8"), (DESTINO, PUERTO_DATOS))
            if datos["movimiento"] != ultimo_texto:
                ultimo_texto = datos["movimiento"]
                print("  ", ultimo_texto or "-")

            cuadro_n += 1
            if cuadro_n % VIDEO_CADA == 0 or opciones.ventana:
                espejo = cv2.flip(imagen, 1)   # la imagen va limpia: no se dibuja el esqueleto
                alto = int(espejo.shape[0] * ANCHO_VIDEO / espejo.shape[1])
                chica = cv2.resize(espejo, (ANCHO_VIDEO, alto), interpolation=cv2.INTER_AREA)
                if cuadro_n % VIDEO_CADA == 0:
                    ok, jpeg = cv2.imencode(".jpg", chica, [cv2.IMWRITE_JPEG_QUALITY, CALIDAD_JPEG])
                    if ok and len(jpeg) < 60000:          # un paquete UDP tiene un límite de tamaño
                        udp.sendto(jpeg.tobytes(), (DESTINO, PUERTO_VIDEO))
                if opciones.ventana:
                    cv2.putText(espejo, datos["movimiento"], (12, 32), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (40, 210, 255), 2)
                    cv2.imshow("PeleaViral - camara (ESC para salir)", espejo)
                    if cv2.waitKey(1) == 27:
                        break
    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        pose.close()
        if opciones.ventana:
            cv2.destroyAllWindows()
    return 0


if __name__ == "__main__":
    sys.exit(main())
