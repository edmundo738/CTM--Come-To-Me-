@echo off
setlocal
title Come To Me - preparar e jogar
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\jogar-windows.ps1"
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar. Consulte a mensagem acima e README.md.
  pause
  exit /b 1
)
