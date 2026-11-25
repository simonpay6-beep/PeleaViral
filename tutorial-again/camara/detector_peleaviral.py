"""Detector de movimientos de PeleaViral.

Abre la cámara, encuentra tu cuerpo con MediaPipe, reconoce tus golpes,
guardia y esquivas (gestos.py) y se los manda al juego por UDP:
  - puerto 4242: lo detectado, en JSON (unas 30 veces por segundo)
  - puerto 4243: una imagen pequeña de la cámara con tu esqueleto dibujado,
                 que el juego muestra debajo del chat

Uso:  python detector_peleaviral.py [--camara 0] [--ventana]
  --camara N   número de la cámara si tienes varias (0 = la primera)
  --ventana    además abre una ventana con la imagen (para probar sin el juego)
Para salir: cierra esta ventana de consola (o Ctrl+C).
"""
import argparse
import json
import socket
import sys
import time

try:
    import cv2
    import mediapipe as mp
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
VERDE = (140, 255, 80)       # BGR


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
    pose = mp.solutions.pose.Pose(model_complexity=1,  # modelo incluido: no necesita internet
                                   min_detection_confidence=0.5, min_tracking_confidence=0.5)
    conexiones = mp.solutions.pose.POSE_CONNECTIONS
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
            resultado = pose.process(cv2.cvtColor(imagen, cv2.COLOR_BGR2RGB))
            puntos = None
            if resultado.pose_landmarks:
                puntos = [Punto(1.0 - p.x, p.y, p.z, p.visibility) for p in resultado.pose_landmarks.landmark]
            datos = gestos.actualizar(puntos, t)
            udp.sendto(json.dumps(datos).encode("utf-8"), (DESTINO, PUERTO_DATOS))
            if datos["movimiento"] != ultimo_texto:
                ultimo_texto = datos["movimiento"]
                print("  ", ultimo_texto or "-")

            cuadro_n += 1
            if cuadro_n % VIDEO_CADA == 0 or opciones.ventana:
                espejo = cv2.flip(imagen, 1)
                if puntos:
                    _dibujar_esqueleto(espejo, puntos, conexiones)
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
        cv2.destroyAllWindows()
    return 0


def _dibujar_esqueleto(imagen, puntos, conexiones):
    alto, ancho = imagen.shape[:2]
    visibles = {i: (int(p.x * ancho), int(p.y * alto)) for i, p in enumerate(puntos) if p.visibilidad > 0.5 and i > 10}
    for a, b in conexiones:
        if a in visibles and b in visibles:
            cv2.line(imagen, visibles[a], visibles[b], VERDE, 3)
    for punto in visibles.values():
        cv2.circle(imagen, punto, 6, (255, 255, 255), -1)
        cv2.circle(imagen, punto, 6, VERDE, 2)


if __name__ == "__main__":
    sys.exit(main())
