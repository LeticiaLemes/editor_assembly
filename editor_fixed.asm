; editor_sasm.asm - Versão para SASM (Windows)
; Abrir no SASM e clicar em "Run" (F9)
; Ou compilar manualmente:
;   nasm -f win64 editor_sasm.asm -o editor_sasm.obj
;   golink /console /entry:start editor_sasm.obj kernel32.dll user32.dll

bits 64

section .data
    STD_INPUT_HANDLE equ -10
    STD_OUTPUT_HANDLE equ -11
    VK_ESC equ 0x1B
    VK_BACK equ 0x08
    VK_LEFT equ 0x25
    VK_RIGHT equ 0x27
    VK_UP equ 0x26
    VK_DOWN equ 0x28
    
    msg_title db "=== EDITOR SIMPLES (SASM) ===", 13, 10, 0
    msg_help db "ESC=Sair | Backspace=Apagar | Setas=Movimento", 13, 10, 0
    msg_line db "----------------------------------------", 13, 10, 0
    msg_empty db "(vazio)", 0
    msg_quit db 13, 10, "[INFO] Saindo...", 13, 10, 0
    
    BUFFER_SIZE equ 1024

section .bss
    buffer resb BUFFER_SIZE
    buffer_len resq 1
    buffer_pos resq 1
    cursor_x resd 1
    cursor_y resd 1
    
    hStdIn resq 1
    hStdOut resq 1
    input_rec resb 24
    bytes_writ resq 1
    chars_read resd 1
    running resb 1

section .text
    extern GetStdHandle
    extern ReadConsoleInputA
    extern WriteConsoleA
    extern ExitProcess

global start

start:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    call init_editor
    call clear_screen
    call show_header
    call refresh_screen

main_loop:
    cmp byte [running], 1
    jne exit
    
    call read_key
    call process_key
    call refresh_screen
    
    jmp main_loop

exit:
    call cleanup
    mov rcx, 0
    call ExitProcess

init_editor:
    mov rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov [hStdIn], rax
    
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov [hStdOut], rax
    
    lea rdi, [buffer]
    xor rax, rax
    mov rcx, BUFFER_SIZE
    rep stosb
    
    mov qword [buffer_len], 0
    mov qword [buffer_pos], 0
    mov dword [cursor_x], 0
    mov dword [cursor_y], 2
    mov byte [running], 1
    ret

clear_screen:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Sequência ANSI para limpar tela
    lea rcx, [ansi_clear]
    call print_string
    
    add rsp, 32
    pop rbp
    ret

ansi_clear db 0x1B, '[2J', 0x1B, '[H', 0

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
    mov rcx, [hStdOut]
    mov r8, rdx
    lea r9, [bytes_writ]
    push 0
    sub rsp, 32
    call WriteConsoleA
    add rsp, 32
    pop rax
    
    add rsp, 32
    pop rbp
    ret

show_header:
    lea rcx, [msg_title]
    call print_string
    lea rcx, [msg_help]
    call print_string
    lea rcx, [msg_line]
    call print_string
    ret

read_key:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rcx, [hStdIn]
    lea rdx, [input_rec]
    mov r8, 1
    lea r9, [chars_read]
    
    sub rsp, 32
    call ReadConsoleInputA
    add rsp, 32
    
    mov al, [input_rec + 14]
    
    add rsp, 32
    pop rbp
    ret

process_key:
    cmp al, VK_ESC
    je .exit
    
    cmp al, VK_BACK
    je .backspace
    
    cmp al, VK_LEFT
    je .left
    
    cmp al, VK_RIGHT
    je .right
    
    cmp al, VK_UP
    je .up
    
    cmp al, VK_DOWN
    je .down
    
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

insert_char:
    mov rbx, [buffer_pos]
    cmp rbx, BUFFER_SIZE - 1
    jge .full
    
    mov [buffer + rbx], al
    inc qword [buffer_pos]
    inc qword [buffer_len]
    inc dword [cursor_x]
.full:
    ret

delete_char:
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
    dec dword [cursor_x]
.done:
    ret

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

refresh_screen:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    call clear_screen
    call show_header
    
    mov rcx, [buffer_len]
    cmp rcx, 0
    je .empty
    
    lea rcx, [buffer]
    call print_string
    jmp .show_cursor

.empty:
    lea rcx, [msg_empty]
    call print_string

.show_cursor:
    mov rcx, 95
    call print_char
    
    add rsp, 32
    pop rbp
    ret

print_char:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov [rsp + 8], cl
    lea rcx, [rsp + 8]
    call print_string
    
    add rsp, 32
    pop rbp
    ret

cleanup:
    lea rcx, [msg_quit]
    call print_string
    ret