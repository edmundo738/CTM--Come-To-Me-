@echo off
setlocal
set "PYTHON=C:\Python315\python.exe"
if exist "%PYTHON%" goto launch
for /f "delims=" %%P in ('where python.exe 2^>nul') do set "PYTHON=%%P"
if defined PYTHON if exist "%PYTHON%" goto launch
echo Python 3 nao foi encontrado. Instala Python 3 e tenta novamente.
pause
exit /b 1
:launch
"%PYTHON%" "%~dp0tools\oficina_web.py"
if errorlevel 1 pause
endlocal
