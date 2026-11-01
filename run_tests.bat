@echo off
rem Runs every automated skill check without opening a game window.

setlocal enabledelayedexpansion

set "GODOT=C:\Users\Thiago\Desktop\CriarJogos\Godot_v4.6-stable_win64.exe"
set "PROJECT=%~dp0."

if not exist "%GODOT%" (
    echo Godot nao encontrado em:
    echo   %GODOT%
    pause
    exit /b 1
)

set "FAILED=0"
for %%T in ("%~dp0tests\test_*.tscn") do (
    echo.
    echo === %%~nT ===
    "%GODOT%" --headless --path "%PROJECT%" "res://tests/%%~nxT"
    if errorlevel 1 set "FAILED=1"
)

echo.
if "!FAILED!"=="1" (echo RESULTADO: algum teste FALHOU) else (echo RESULTADO: todos os testes passaram)
pause
