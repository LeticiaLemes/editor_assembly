; editor_sasm.asm - Editor de texto para SASM (Linux)
; Configuração: NASM, x64, -f elf64
; Linker: gcc -lc -dynamic-linker /lib64/ld-linux-x86-64.so.2

bits 64

section .data
    ; Mensagens com cores ANSI
    msg_title   db 0x1B, '[1;36m', "=== EDITOR SIMPLES (SASM) ===", 0x1B, '[0m', 10, 0
    msg_help    db 0x1B, '[33m', "ESC=Sair | Backspace=Apagar | Setas=Movimento | Ctrl+S=Salvar", 0x1B, '[0m', 10, 0
    msg_line    db "----------------------------------------", 10, 0
    msg_empty   db 0x1B, '[90m', "(vazio)", 0x1B, '[0m', 10, 0
    msg_quit    db 10, 0x1B, '[32m', "[INFO] Saindo...", 0x1B, '[0m', 10, 0
    msg_saved   db 10, 0x1B, '[32m', "[OK] Salvo como: texto.txt", 0x1B, '[0m', 10, 0
    msg_error   db 10, 0x1B, '[31m', "[ERRO] Falha ao salvar!", 0x1B, '[0m', 10, 0
    msg_stats   db 10, "Caracteres: ", 0
    msg_sep     db 10, "----------------------------------------", 10, 0
    msg_modified db 0x1B, '[33m', " [modificado]", 0x1B, '[0m', 10, 0
    msg_unmodified db 0x1B, '[32m', " [salvo]", 0x1B, '[0m', 10, 0
    
    ; Constantes
    BUFFER_SIZE equ 2048
    
    ; Nome do arquivo
    filename db "texto.txt", 0
    
    ; Termios
    ICANON equ 1 << 1
    ECHO   equ 1 << 3
    TCGETS equ 0x5401
    TCSETS equ 0x5402
    
    ; Sequência ANSI para limpar tela
    ansi_clear db 0x1B, '[2J', 0x1B, '[H', 0

section .bss
    ; Buffer do texto
    buffer      resb BUFFER_SIZE
    buffer_len  resq 1
    buffer_pos  resq 1
    
    ; Posição do cursor
    cursor_x    resd 1
    cursor_y    resd 1
    
    ; Terminal
    orig_termios resb 36
    new_termios  resb 36
    
    ; Entrada
    key_pressed  resb 1
    running      resb 1
    modified     resb 1
    
    ; Stats
    stats_buffer resb 32

section .text
    global main
    extern printf
    extern exit

main:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    call init_editor
    call clear_screen
    call show_welcome
    call refresh_display
    
editor_loop:
    cmp byte [running], 1
    jne exit_editor
    
    call read_key
    call process_key
    call refresh_display
    
    jmp editor_loop

exit_editor:
    call cleanup
    mov rdi, 0
    call exit

; ============================================================
; INICIALIZAÇÃO
; ============================================================
init_editor:
    push rbp
    mov rbp, rsp
    
    ; Zera buffer
    lea rdi, [buffer]
    xor rax, rax
    mov rcx, BUFFER_SIZE
    rep stosb
    
    ; Inicializa variáveis
    mov qword [buffer_len], 0
    mov qword [buffer_pos], 0
    mov dword [cursor_x], 0
    mov dword [cursor_y], 2
    mov byte [running], 1
    mov byte [modified], 0
    
    ; Configura terminal raw mode
    call enable_raw_mode
    
    pop rbp
    ret

; ============================================================
; HABILITA MODO RAW
; ============================================================
enable_raw_mode:
    push rbp
    mov rbp, rsp
    
    ; Pega configurações atuais
    mov rax, 16          ; ioctl
    mov rdi, 0           ; stdin
    mov rsi, TCGETS
    lea rdx, [orig_termios]
    syscall
    
    ; Copia para new_termios
    lea rsi, [orig_termios]
    lea rdi, [new_termios]
    mov rcx, 36
    rep movsb
    
    ; Modifica flags
    mov rax, [new_termios + 12]  ; c_lflag
    and rax, ~ICANON              ; Desativa modo canônico
    and rax, ~ECHO                ; Desativa echo
    mov [new_termios + 12], rax   ; c_lflag
    
    ; Aplica novas configurações
    mov rax, 16          ; ioctl
    mov rdi, 0           ; stdin
    mov rsi, TCSETS
    lea rdx, [new_termios]
    syscall
    
    pop rbp
    ret

; ============================================================
; RESTAURA TERMINAL
; ============================================================
disable_raw_mode:
    push rbp
    mov rbp, rsp
    
    mov rax, 16          ; ioctl
    mov rdi, 0           ; stdin
    mov rsi, TCSETS
    lea rdx, [orig_termios]
    syscall
    
    pop rbp
    ret

; ============================================================
; LIMPA TELA
; ============================================================
clear_screen:
    push rbp
    mov rbp, rsp
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [ansi_clear]
    mov rdx, 6
    syscall
    
    pop rbp
    ret

; ============================================================
; ESCREVE STRING
; ============================================================
print_string:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rsi, rcx
    xor rdx, rdx
    
.count:
    cmp byte [rsi + rdx], 0
    je .done
    inc rdx
    jmp .count
    
.done:
    mov rax, 1
    mov rdi, 1
    syscall
    
    add rsp, 32
    pop rbp
    ret

; ============================================================
; ESCREVE CARACTERE
; ============================================================
print_char:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov [rsp + 8], cl
    mov rax, 1
    mov rdi, 1
    lea rsi, [rsp + 8]
    mov rdx, 1
    syscall
    
    add rsp, 32
    pop rbp
    ret

; ============================================================
; MOSTRA CABEÇALHO
; ============================================================
show_welcome:
    push rbp
    mov rbp, rsp
    
    lea rcx, [msg_title]
    call print_string
    
    lea rcx, [msg_help]
    call print_string
    
    lea rcx, [msg_line]
    call print_string
    
    pop rbp
    ret

; ============================================================
; LÊ TECLA
; ============================================================
read_key:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rax, 0
    mov rdi, 0
    lea rsi, [key_pressed]
    mov rdx, 1
    syscall
    
    mov al, [key_pressed]
    
    add rsp, 32
    pop rbp
    ret

; ============================================================
; PROCESSA TECLA
; ============================================================
process_key:
    ; ESC = 27
    cmp al, 27
    je .exit
    
    ; Backspace = 127
    cmp al, 127
    je .backspace
    
    ; Enter = 10
    cmp al, 10
    je .newline
    
    ; Ctrl+S = 19
    cmp al, 19
    je .save
    
    ; Seta (começa com ESC)
    cmp al, 27
    je .arrow_handler
    
    cmp al, 32
    jl .done
    
    call insert_char
    jmp .done

.exit:
    mov byte [running], 0
    jmp .done

.backspace:
    call delete_char
    jmp .done

.newline:
    mov al, 10
    call insert_char
    inc dword [cursor_y]
    mov dword [cursor_x], 0
    jmp .done

.save:
    call save_file
    jmp .done

.arrow_handler:
    call read_key
    cmp al, 91
    je .arrow_sequence
    jmp .done

.arrow_sequence:
    call read_key
    cmp al, 65
    je .up
    cmp al, 66
    je .down
    cmp al, 67
    je .right
    cmp al, 68
    je .left
    jmp .done

.left:
    call move_left
    jmp .done

.right:
    call move_right
    jmp .done

.up:
    call move_up
    jmp .done

.down:
    call move_down
    jmp .done

.done:
    ret

; ============================================================
; INSERE CARACTERE
; ============================================================
insert_char:
    push rbp
    mov rbp, rsp
    
    mov rbx, [buffer_pos]
    cmp rbx, BUFFER_SIZE - 1
    jge .full
    
    mov [buffer + rbx], al
    inc qword [buffer_pos]
    inc qword [buffer_len]
    inc dword [cursor_x]
    mov byte [modified], 1
    
.full:
    pop rbp
    ret

; ============================================================
; DELETA CARACTERE
; ============================================================
delete_char:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    
    mov rbx, [buffer_pos]
    cmp rbx, 0
    je .done
    
    dec qword [buffer_pos]
    dec rbx
    
    mov rsi, rbx
    inc rsi
    mov rdi, rbx
    
.shift:
    cmp rsi, [buffer_len]
    jge .update
    
    mov al, [buffer + rsi]
    mov [buffer + rdi], al
    inc rsi
    inc rdi
    jmp .shift
    
.update:
    dec qword [buffer_len]
    cmp dword [cursor_x], 0
    jg .dec_cursor
.dec_cursor:
    dec dword [cursor_x]
    mov byte [modified], 1
    
.done:
    pop rdi
    pop rsi
    pop rbx
    pop rbp
    ret

; ============================================================
; MOVIMENTAÇÃO DO CURSOR
; ============================================================
move_left:
    mov rbx, [buffer_pos]
    cmp rbx, 0
    je .done
    dec qword [buffer_pos]
    dec dword [cursor_x]
.done:
    ret

move_right:
    mov rbx, [buffer_pos]
    cmp rbx, [buffer_len]
    jge .done
    inc qword [buffer_pos]
    inc dword [cursor_x]
.done:
    ret

move_up:
    cmp dword [cursor_y], 2
    jle .done
    dec dword [cursor_y]
.done:
    ret

move_down:
    inc dword [cursor_y]
.done:
    ret

; ============================================================
; SALVA ARQUIVO
; ============================================================
save_file:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Cria/abre arquivo
    mov rax, 2
    lea rdi, [filename]
    mov rsi, 0x441
    mov rdx, 0x1B4
    syscall
    
    cmp rax, 0
    jl .error
    mov rbx, rax
    
    ; Escreve no arquivo
    mov rax, 1
    mov rdi, rbx
    lea rsi, [buffer]
    mov rdx, [buffer_len]
    syscall
    
    ; Fecha arquivo
    mov rax, 3
    mov rdi, rbx
    syscall
    
    lea rcx, [msg_saved]
    call print_string
    mov byte [modified], 0
    jmp .done
    
.error:
    lea rcx, [msg_error]
    call print_string
    
.done:
    add rsp, 32
    pop rbp
    ret

; ============================================================
; ATUALIZA TELA
; ============================================================
refresh_display:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    call clear_screen
    call show_welcome
    
    mov rcx, [buffer_len]
    cmp rcx, 0
    je .empty
    
    lea rcx, [buffer]
    call print_string
    jmp .show_stats
    
.empty:
    lea rcx, [msg_empty]
    call print_string
    
.show_stats:
    lea rcx, [msg_sep]
    call print_string
    
    lea rcx, [msg_stats]
    call print_string
    
    mov rsi, stats_buffer
    mov rax, [buffer_len]
    call int_to_string
    
    lea rcx, [stats_buffer]
    call print_string
    
    cmp byte [modified], 1
    jne .not_modified
    
    lea rcx, [msg_modified]
    call print_string
    jmp .done
    
.not_modified:
    lea rcx, [msg_unmodified]
    call print_string
    
.done:
    add rsp, 32
    pop rbp
    ret

; ============================================================
; CONVERTE NÚMERO PARA STRING
; ============================================================
int_to_string:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    mov rbx, 10
    mov rcx, rsi
    add rcx, 20
    mov byte [rcx], 0
    
.converte:
    dec rcx
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rcx], dl
    test rax, rax
    jnz .converte
    
    mov rsi, rcx
    mov rdi, stats_buffer
    
.copia:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    cmp al, 0
    jnz .copia
    
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; ============================================================
; LIMPEZA FINAL
; ============================================================
cleanup:
    push rbp
    mov rbp, rsp
    
    call disable_raw_mode
    call clear_screen
    
    lea rcx, [msg_quit]
    call print_string
    
    pop rbp
    ret