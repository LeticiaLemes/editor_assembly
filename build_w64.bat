@echo off

REM compilador para Windows 64 bits

echo =========================================
echo Compilando para Windows 64 bits
echo =========================================
echo.

REM verifica NASM
nasm -v >nul 2>&1
if errorlevel 1 (
    echo [ERRO] NASM nao encontrado. Por favor, instale o NASM e adicione ao PATH.
    echo https://www.nasm.us/ >nul
    pause
    exit /b 1
)

REM verifica o GoLink
GoLink -v >nul 2>&1
if errorlevel 1 (
    echo [ERRO] GoLink nao encontrado. Por favor, instale o GoLink e adicione ao PATH.
    echo https://www.godevtool.com/ >nul
    pause
    exit /b 1
)

echo [OK] Ferramentas instaladas!
echo.

echo [1/2] Compilando assembly...
nasm -f win64 edutor.asm -o editor.obj
if errorlevel 1 goto erro

echo [2/2] Linkando executavel...
GoLink /entry main /console editor.obj kernel32.dll user32.dll gdi32.dll
if errorlevel 1 goto erro

echo.
echo [SUCESSO] Compilacao concluida! O executavel 'editor.exe' foi criado.
goto fim

:erro 
echo.
echo [ERRO] Ocorreu um erro durante a compilacao.
echo Verifique o código e tente novamente

:fim
pause