@echo off
title Xiaoming Campus Net Toolkit
net session >nul 2>&1
if "%errorlevel%"=="0" goto run
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0src\XiaomingToolkit.ps1\"'"
exit /b
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\XiaomingToolkit.ps1"
pause
