#!/bin/bash

echo "========================================"
echo "  COMPILANDO EDITOR DE TEXTO"
echo "========================================"
echo ""

# Verifica se o arquivo existe
if [ ! -f "editor.asm" ]; then
    echo "[ERRO] Arquivo editor.asm não encontrado!"
    echo "Certifique-se de que o arquivo está nesta pasta:"
    echo "$(pwd)"
    exit 1
fi

echo "[1/2] Compilando com NASM..."
nasm -f elf64 editor.asm -o editor.o
if [ $? -ne 0 ]; then
    echo "[ERRO] Falha na compilação!"
    exit 1
fi
echo "[OK] Compilação concluída!"

echo "[2/2] Linkando com GCC..."
gcc -no-pie -o editor editor.o -lc
if [ $? -ne 0 ]; then
    echo "[ERRO] Falha no link!"
    exit 1
fi
echo "[OK] Linkagem concluída!"

echo ""
echo "========================================"
echo "  EDITOR INICIADO"
echo "========================================"
echo ""
echo "Comandos:"
echo "  ESC       - Sair"
echo "  Backspace - Apagar"
echo "  Ctrl+S    - Salvar"
echo ""
echo "========================================"
echo ""

./editor

echo ""
echo "Editor finalizado."