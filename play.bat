@echo off
rem Launches the game directly, skipping the Godot editor.
rem Double-click this file to play.

set "GODOT=C:\Users\Thiago\Desktop\CriarJogos\Godot_v4.6-stable_win64.exe"

rem Trailing "." keeps the project path's final backslash from escaping the
rem closing quote, which would swallow the argument after it.
set "PROJECT=%~dp0."

if not exist "%GODOT%" (
    echo Godot nao encontrado em:
    echo   %GODOT%
    echo.
    echo Edite a linha "set GODOT=" deste arquivo com o caminho correto.
    pause
    exit /b 1
)

"%GODOT%" --path "%PROJECT%"
