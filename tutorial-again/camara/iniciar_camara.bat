@echo off
title PeleaViral - Detector de camara
cd /d "%~dp0"

rem Busca un Python de verdad (el atajo de la Microsoft Store no sirve).
set "PYEXE="
set "PYARG="
py -3 -c "import sys" >nul 2>&1 && (set "PYEXE=py" & set "PYARG=-3")
if not defined PYEXE (python -c "import sys" >nul 2>&1 && set "PYEXE=python")
if not defined PYEXE for /d %%D in ("%LocalAppData%\Programs\Python\Python3*" "%ProgramFiles%\Python3*") do (
  if exist "%%~D\python.exe" set "PYEXE=%%~D\python.exe"
)
if not defined PYEXE goto sin_python

"%PYEXE%" %PYARG% -c "import cv2, mediapipe.tasks" >nul 2>&1
if errorlevel 1 (
  echo Instalando las librerias de la camara ^(solo la primera vez, necesita internet^)...
  "%PYEXE%" %PYARG% -m pip install -r requirements.txt
)
"%PYEXE%" %PYARG% detector_peleaviral.py %*
if errorlevel 1 pause
exit /b

:sin_python
echo.
echo  No se encontro Python en este computador.
echo.
echo  1. Instala Python desde la pagina que se va a abrir (boton "Download Python").
echo     IMPORTANTE: en la primera pantalla del instalador marca
echo     "Add python.exe to PATH" y luego "Install Now".
echo  2. Cierra esta ventana y vuelve a abrir iniciar_camara.bat.
echo.
echo  Si despues de instalarlo sigue saliendo "Python was not found":
echo  Configuracion ^> Aplicaciones ^> Configuracion avanzada de aplicaciones ^>
echo  Alias de ejecucion de aplicaciones, y apaga "python.exe" y "python3.exe".
echo.
start "" "https://www.python.org/downloads/windows/"
pause
exit /b 1
