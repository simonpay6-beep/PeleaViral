@echo off
title PeleaViral - Detector de camara
cd /d "%~dp0"
rem Usa Python 3.12, 3.11 o 3.10 si estan instalados (MediaPipe no funciona con versiones mas nuevas).
set PY=
for %%V in (3.12 3.11 3.10) do (
  if not defined PY ( py -%%V -c "import sys" >nul 2>&1 && set PY=py -%%V )
)
if not defined PY set PY=python
%PY% -c "import cv2, mediapipe" >nul 2>&1
if errorlevel 1 (
  echo Instalando las librerias de la camara ^(solo la primera vez^)...
  %PY% -m pip install -r requirements.txt
)
%PY% detector_peleaviral.py %*
if errorlevel 1 pause
