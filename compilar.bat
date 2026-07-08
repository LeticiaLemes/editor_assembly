@echo off
echo ========================================
echo   EDITOR SIMPLES - COMPILADOR
echo ========================================
echo.

echo [1/3] Compilando...
nasm -f win64 editor_simples.asm -o editor_simples.obj
if errorlevel 1 goto erro

echo [2/3] Linkando...
golink /console /entry:start editor_simples.obj kernel32.dll user32.dll
if errorlevel 1 goto erro

echo [3/3] Executando...
echo.
editor_simples.exe
goto fim

:erro
echo [ERRO] Falha na compilacao!
pause
exit /b 1

:fim
pause