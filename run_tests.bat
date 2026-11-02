@echo off
rem Runs the automated checks.
rem   run_tests.bat            quick: every check except the full
rem                            playthroughs (a bot playing a whole level), a
rem                            few minutes. For everyday changes.
rem   run_tests.bat completo   everything, playthroughs included (about 25
rem                            minutes). Before a big commit, or after
rem                            touching the stage generator or a level.
rem A test is a playthrough when its script uses one of the playthrough
rem bases (campaign_playthrough_test.gd, stage_playthrough_test.gd).
rem At the end a window opens and the mouse moves for a few seconds
rem (window_test_*): leave the mouse alone meanwhile.

setlocal enabledelayedexpansion

set "GODOT=C:\Users\Thiago\Desktop\CriarJogos\Godot_v4.6-stable_win64.exe"
set "PROJECT=%~dp0."
set "FULL=0"
if /i "%~1"=="completo" set "FULL=1"

if not exist "%GODOT%" (
    echo Godot nao encontrado em:
    echo   %GODOT%
    pause
    exit /b 1
)

set "FAILED=0"
set "SKIPPED=0"
for %%D in ("tests" "modes\roguelike\tests") do (
    for %%T in ("%~dp0%%~D\test_*.tscn") do (
        set "RUN=1"
        findstr /m /c:"playthrough_test" "%%~dpnT.gd" >nul 2>&1 && if "!FULL!"=="0" set "RUN=0"
        if "!RUN!"=="0" (
            set /a SKIPPED+=1
        ) else (
            echo.
            echo === %%~nT ===
            set "RES=%%~D\%%~nxT"
            "%GODOT%" --headless --path "%PROJECT%" "res://!RES:\=/!"
            if errorlevel 1 set "FAILED=1"
        )
    )
)

rem These need a real window and pointer (they move the mouse): no --headless.
for %%T in ("%~dp0tests\window_test_*.tscn") do (
    echo.
    echo === %%~nT ^(janela: nao mexa no mouse^) ===
    "%GODOT%" --path "%PROJECT%" "res://tests/%%~nxT"
    if errorlevel 1 set "FAILED=1"
)

echo.
if "!FULL!"=="0" echo Partidas inteiras puladas: !SKIPPED! ^(rode "run_tests.bat completo" para incluir^)
if "!FAILED!"=="1" (echo RESULTADO: algum teste FALHOU) else (echo RESULTADO: todos os testes passaram)
pause
