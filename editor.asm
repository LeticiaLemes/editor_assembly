; EDITOR.ASM - editor de texto para windows 64bits
; 
; Compilar: nasm -f win64 editor.asm -o editor.obj
; Linkar: link editor.obj -subsystem:windows -o editor.exe
; AUTOR: Letícia Pegorini - ra: 2699583
; AUTOR: Leonardo Pontes - ra:
; AUTOR: Luana Pereira - ra: 2699605

bits 64

; seção para dados inicializados (ctes e Strings)
Section .data

    ; handles e ctes windows 64
    STD_INPUT_HANDLE equ -10
    STD_OUTPUT_HANDLE equ -11
    NULL equ 0
    TRUE equ 1
    FALSE equ 0

    ; cores console
    FOREGROUND_BLUE equ 0x0001
    FOREGROUND_GREEN equ 0x0002
    FOREGROUND_RED equ 0x0004
    FOREGROUND_INTENSITY equ 0x0008

    ; mensagens do editor
    header_top db "========================================", 13, 16, 0
    header_title db "      EDITOR DE TEXTO (64 BITS)     ", 13, 16, 0
    header_bottom db "========================================", 13, 16, 0

    header_info db "Comandos: ", 13, 10, 0
    header_cmd1 db "ESC - Sair", 13, 10, 0
    header_cmd2 db "Backspace - Apagar caractere", 13, 10, 0
    header_cmd3 db "Setas - Mover cursor", 13, 10, 0
    header_cmd4 db "CTRL + S - Salvar", 13, 10, 0
    header_line2 db "========================================", 13, 16, 0
    header_prompt db "Digite seu texto abaixo:", 13, 10, 0
    header_line3 db "----------------------------------------", 13, 10, 0

    msg_saved db 13, 10, "[OK] Arquivo salvo com sucesso!", 13, 10, 0
    msg_error db 13, 10, "[ERRO] Falha ao salvar o arquivo!", 13, 10, 0
    msg_quit db 13, 10, "[INFO] Encerrando editor...", 13, 10, 0

    ; comandos do sistema 
    cls_cmd db "cls", 0     ; comando para limpar tela no windows
    filename_base db "meu_texto", 0     ; nome base do arquivo a ser salvo

    ; códigos das teclas
    VK_BACK         equ 0x08
    VK_RETURN       equ 0x0D
    VK_ESCAPE       equ 0x1B
    VK_LEFT         equ 0x25
    VK_RIGHT        equ 0x27
    VK_UP           equ 0x26
    VK_DOWN         equ 0x28
    VK_CONTROL      equ 0x11
    
    CTRL_S_SCANCODE equ 0x1F

    ; ctes buffer
    BUFFER_SIZE equ 4096
    MAX_LINE equ 80     ; largura máx linha de quebra

; SEÇAÕ BSS - para dados não inicializados (buffers)
Section .bss

    ; buffer do editor
    text_buffer resb BUFFER_SIZE
    buffer_len resq  1 

    ; posição do cursor
    cursor_x resqd 1
    cursor_y resqd 1
    buffer_pos resq 1

    ; handles do windows
    hStdIn resq 1       ; handle entrada padrão
    hStdOut resq 1      ; handle saída padrão

    ; buffers de entrada e saída
    input_record resb 24
    chars_read resd 1       ; quantidade de eventos lidos
    bytes_written resq 1     ; quantidade de bytes escritos

    output_buffer resb 8192     ; buffer para saída formatada

    ; variáveis de controle
    running resb 1      ; 1 = executando e 0 = sair
    modified resb 1     ; 1 = buffer modificado e 0 = sem modificações

; SEÇÃO . TEXT - código do programa
section .text

    ; declaração funções externas API do windows
    extern GetStdHandle     ; handles do console
    extern ReadConsoleInputA        ; lê entradas console
    extern WriteConsoleA        ; escreve no console
    extern ExitProcess        ; encerra processo
    extern system              ; executa comando do sistema
    extern CreateFileA           ; cria/abre arquivo
    extern WriteFile             ; escreve em arquivo
    extern CloseHandle            ; fecha handle

; ponto de entrada principal
global start

start:
    ; setup stack frame
    push rbp
    mov rbp, rsp
    sub rsp, 64     ; espaço para variáveis locais

    ; inicializa o editor (buffer, handles, etc)
    call init_editor

    ; limpa a tela
    call clear_screen

    ; mostra a tela inicial do editor
    call show_welcome_screen

    ; mostra o cursor na posição inicial
    call refresh_ display

; LOOP PRINCIPAL - processa eventos do teclado
editor_loop: 
    ; verifica tentativa de saída do usuário
    cmp byte [running], 0
    je exit_editor

    ; lê uma tecla do usuário
    call read_key

    ; processa a tecla lida
    call process_key

    ; atualiza a tela do editor
    call refresh_display

    ; volta para o loop de eventos
    jmp editor_loop

; SAÍDA DO PROGRAMA - limpa recursos e encerra processo
exit_editor:
    call cleanup_and_exit       ; mostra mensagem de saída

    mov, rcx, 0    ; código de saída 0 = sucesso
    call ExitProcess

; INICIALIZAÇÃO DO EDITOR - configura handles, buffer, etc
init_editor:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; obtém handle de entrada teclado
    mov rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov [hStdIn], rax

    ; obtém handle de saída console
    mov rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov [hStdOut], rax

    ; zera buffer (zera tudo)
    lea rdi, [text_buffer]
    xor rax, rax
    mov rcx, BUFFER_SIZE
    rep stosb       ; preenche buffer com zeros

    ; inicializa variáveis de controle
    mov qword [buffer_len], 0       ; texto vazio
    mov qword [buffer_pos], 0       ; posição inicial do cursor no buffer
    mov qword [cursor_x], 0     ; cursor começa na coluna 0 
    mov qword [cursor_y], 2    ; cursor começa na linha 0 após cabeçalho
    mov byte [running], TRUE   ; editor está rodando
    mov byte [modified], FALSE ; buffer não modificado

    add rsp, 32
    pop rbp
    ret

; LIMPA TELA - executa comando cls para limpar console


clear_screen:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    lea rcx, [cls_cmd]
    call system

    add rsp, 32
    pop rbp
    ret

; MOSTRA TELA INICIAL - exibe cabeçalho e instruções do editor
RCX = endereço da string
print_string_win:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov rsi, rcx
    xor rdx, rdx

.conta:
    cmp byte [rsi + rdx], 0
    je .fim_conta
    inc rdx
    jmp .conta

.fim_conta:

    mov rcx, [hStdOut]
    mov r8, rdx
    lea r9, [bytes_written]

    push 0
    sub rsp, 32
    call WriteConsoleA
    add rsp, 32
    pop rax

    add rsp, 64
    pop rbp
    ret

; IMPRIME TEXTO NA TELA - formata e exibe o conteúdo do buffer
   ;Entrada: RCX (& String)
   show_welcome_screen:

    lea rcx, [header_top]
    call print_string_win

    lea rcx, [header_title]
    call print_string_win

    lea rcx, [header_bottom]
    call print_string_win

    lea rcx, [header_info]
    call print_string_win

    lea rcx, [header_cmd1]
    call print_string_win

    lea rcx, [header_cmd2]
    call print_string_win

    lea rcx, [header_cmd3]
    call print_string_win

    lea rcx, [header_cmd4]
    call print_string_win

    lea rcx, [header_line2]
    call print_string_win

    lea rcx, [header_prompt]
    call print_string_win

    lea rcx, [header_line3]
    call print_string_win

    ret


; LÊ TECLA DO USUÁRIO - lê um evento de teclado e armazena na estrutura input_record
   ;Saída: AL = código da tecla lida
   read_key:

    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov rcx, [hStdIn]
    lea rdx, [input_record]
    mov r8, 1
    lea r9, [chars_read]

    sub rsp, 32
    call ReadConsoleInputA
    add rsp, 32

    mov al, [input_record + 14]

    add rsp, 32
    pop rbp
    ret


; PROCESSA TECLA - interpreta a tecla lida e atualiza buffer/estado do editor
process_key:

    cmp al, VK_ESCAPE
    je .sair

    cmp al, VK_BACK
    je .backspace

    cmp al, VK_LEFT
    je .esquerda

    cmp al, VK_RIGHT
    je .direita

    cmp al, VK_UP
    je .cima

    cmp al, VK_DOWN
    je .baixo

    cmp al, 32
    jl .fim

    call insert_char
    jmp .fim

.backspace:
    call delete_char
    jmp .fim

.esquerda:
    call move_cursor_left
    jmp .fim

.direita:
    call move_cursor_right
    jmp .fim

.cima:
    call move_cursor_up
    jmp .fim

.baixo:
    call move_cursor_down
    jmp .fim

.sair:
    mov byte [running], FALSE

.fim:
    ret

; INSERE CARACTERE - insere um caractere no buffer na posição atual do cursor
   ; Entrada: AL = caractere a inserir
   insert_char:

    push rbp
    mov rbp, rsp

    mov rbx, [buffer_pos]

    cmp rbx, BUFFER_SIZE-1
    jge .fim

    mov [text_buffer + rbx], al

    inc qword [buffer_pos]
    inc qword [buffer_len]

    inc dword [cursor_x]

    mov byte [modified], TRUE

.fim:
    pop rbp
    ret




; DELETA CARACTERE - remove um caractere do buffer na posição atual do cursor
delete_char:
    push rbp       ; salva o endereço atual da pilha
    mov rbp, rsp   ; cria novo ponto de referencia
    push rbx       ; salva o registrador rbx (será usado)
    push rcx       ; salva o registrador rcx
    push rsi       ; salva o registrador rsi (fonte)
    push rdi       ; salva o registrador rdi (destino)

    ; verifica se está no início do buffer (não há caractere para deletar)
    mov rbx, [buffer_pos]       ; carrega posição atual do cursos em rbx
    cmp rbx, 0                  ; verifica se está na posição inicial (0)
    je .fim                     ; se sim, vai para o fim

    ; decrementa posição
    dec qword [buffer_pos]      ; cursor volta uma posição (-1)
    dec rbx                     ; atualiza rbx também (-1)

    ; desloca os caracteres para a esquerda (sobrescreve o caractere deletado)
    mov rsi, rbx                ; fonte = posição do caractere a ser deletado
    inc rsi                     ; fonte = próximo caractere (posição + 1)
    mov rdi, rbx                ; destino = posição atual (onde vai sobrescrever)

.desloca_loop:
    cmp rsi, [buffer_len]         ; verifica se chegou ao fim do buffer
    jge .atualiza               ; se sim, vai atualizar as variáveis

    mov al, [text_buffer + rsi]   ; carrega caractere da posição fonte
    mov [text_buffer + rdi], al   ; sobrescreve na posição destino (deslocando para a esquerda)
    inc rsi                       ; avança para o próximo caractere (+1)
    inc rdi                       ; avança para o próximo destino (+1)
    jmp .desloca_loop             ; repete até o fim do buffer

.atualiza:
    ;atualiza tamanho
    dec qword [buffer_len]      ; decrementa tamanho total do buffer

    ; atualiza posição do cursor
    cmp dword [cursor_x], 0     ; verifica coluna atual do cursor
    jg .decrementa              ; se for maior que 0, decrementa
.decrementa:
    dec dword [cursor_x]        ; move o cursos uma coluna para a esquerda
    mov byte [modified], 1      ; marca que o texto foi modificado (para salvar)

.fim:
    pop rdi       ; restaura o registrador rdi
    pop rsi       ; restaura o registrador rsi
    pop rcx       ; restaura o registrador rcx
    pop rbx       ; restaura o registrador rbx
    pop rbp       ; restaura o endereço da pilha
    ret           ; retorna da função

; MOVE CURSOR ESQUERDA
move_cursor_left:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência

    mov rbx, [buffer_pos]   ; carrega posição atual do cursor
    cmp rbx, 0              ; verifica se está na posição inicial (0)
    je .fim                 ; se sim, vai para o fim (não move)

    dec qword [buffer_pos]      ; decrementa posição no buffer

    cmp dword [cursor_x], 0     ; verifica coluna atual
    jg .decrementa              ; se for maior que 0, decrementa

.decrementa:
    dec dword [cursor_x]        ; move o cursor uma coluna para a esquerda  

.fim:
    pop rbp            ; restaura o endereço da pilha   
    ret                ; retorna da função

; MOVE CURSOR DIREITA
move_cursor_right:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência

    mov rbx, [buffer_pos]       ; carrega posição atual do cursor
    cmp rbx, [buffer_len]       ; compara com tamanho total do buffer
    jge .fim                    ; se estiver no fim, não move

    inc qword [buffer_pos]      ; incrementa posição no buffer
    inc dword [cursor_x]        ; move o cursor uma coluna para a direita

.fim:
    pop rbp            ; restaura o endereço da pilha   
    ret                ; retorna da função

; MOVE CURSOR CIMA
move_cursor_up:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência

    cmp dword [cursor_y], 2     ; verifica se está na linha 2
    jle .fim                    ; se for <=2, não move

    dec dword [cursor_y]        ; move o cursor uma linha para cima

.fim:
    pop rbp            ; restaura o endereço da pilha   
    ret                ; retorna da função

; MOVE CURSOR BAIXO
move_cursor_down:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência

    inc dword [cursor_y]        ; move o cursor uma linha para baixo

.fim:
    pop rbp            ; restaura o endereço da pilha   
    ret                ; retorna da função

; SALVA ARQUIVO - salva o conteúdo do buffer em um arquivo de texto
save_to_file:
    push rbp           ; salva o endereço atual da pilha
    mov rbp, rsp       ; cria novo ponto de referência
    sub rsp, 64        ; reserva 64 bytes na pilha para variáeis locais

    ; CreateFileA: cria/abre arquivo
    ; Parâmetros (ordem na pilha e registradores):
    ; rcx = lpFileName
    ; rdx = dwDesiredAccess (GENERIC_WRITE = 0x40000000)
    ; r8  = dwShareMode (0 - compartilhamento exclusivo)
    ; r9  = lpSecurityAttributes (NULL - sem atributos de segurança)
    ; pilha: dwCreationDisposition (CREATE_ALWAYS = 2 - cria novo/sempre)
    ; pilha: dwFlagsAndAttributes (FILE_ATTRIBUTE_NORMAL = 0x80)
    ; pilha: hTemplateFile (NULL - sem template)

    lea rcx, [filename_base]      ; carrega nome do arquivo
    mov rdx, 0x40000000           ; permissão de escrita
    xor r8, r8                    ; compartilhamento exclusivo
    xor r9, r9                    ; sem atributos de segurança
    push 0                        ; hTemplateFile (NULL)
    push 0x80                     ; FILE_ATTRIBUTE_NORMAL (arquivo normal)
    push 2                        ; CREATE_ALWAYS (cria sempre, sobrescreve)

    sub rsp, 32                    ; ajusta pilha para chamada de API
    call CreateFileA               ; chama API para criar/abrir arquivo
    add rsp, 32                    ; restaura pilha após chamada
    add rsp, 24                    ; limpa os 3 parâmetros empilhados (3*8=24)

    ; verifica se abriu corretamente
    cmp rax, -1                    ; compara retorno com -1 (INVALID_HANDLE_VALUE)
    je .erro                       ; se sim, erro ao abrir arquivo

    mov [file_handle], rax             ; salva handle do arquivo aberto

    ; WriteFile: escreve buffer no arquivo
    ; rcx = hFile (handle do arquivo)
    ; rdx = lpBuffer (endereço dos dados)
    ; r8  = nNumberOfBytesToWrite (quantos bytes escrever)
    ; r9  = lpNumberOfBytesWritten (onde armazenar quantos foram escritos)
    ; pilha: lpOverlapped (NULL - operação síncrona)

    mov rcx, [file_handle]           ; carrega handle do arquivo
    lea rdx, [text_buffer]           ; carrega endereço do buffer de texto
    mov r8, [buffer_len]             ; carrega tamanho do buffer
    lea r9, [bytes_written]          ; carrega endereço para armazenar quantidade de bytes escritos
    push 0                           ; lpOverlapped (NULL)

    sub rsp, 32                       ; ajusta pilha para chamada de API
    call WriteFile                    ; chama API para escrever no arquivo
    add rsp, 32                       ; restaura pilha após chamada
    pop rcx                           ; limpa parâmetro empilhado (lpOverlapped)

    ; fecha o arquivo
    mov rcx, [file_handle]           ; carrega handle do arquivo
    call CloseHandle                 ; chama API para fechar arquivo

    ; mostra mensagem de sucesso
    lea rcx, [msg_saved]              ; carrega endereço da mensagem de sucesso
    call print_string_win                 ; chama função para imprimir mensagem
    jmp .fim                          ; pula para o fim

.erro:
    lea rcx, [msg_error]              ; carrega endereço da mensagem de erro
    call print_string_win                 ; chama função para imprimir mensagem

.fim:
    add rsp, 64        ; libera espaço da pilha
    pop rbp            ; restaura o endereço da pilha
    ret                ; retorna da função

; ATUALIZA TELA - limpa e redesenha o conteúdo do editor
refresh_display:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência
    sub rsp, 64         ; reserva 64 bytes na pilha para variáeis locais

    ; limpa a tela (mantém cursor no topo)
    call clear_screen       ; chama função para limpar a tela

    ; mostra o cabeçalho notamente
    call show_welcome_screen   ; chama função para mostrar cabeçalho e instruções

    ; mostra o conteúdo do buffer (texto digitado)
    lea rcx, [text_buffer]      ; carrega endereço do buffer de texto
    call print_string_win       ; chama função para imprimir o buffer

    ; mostra estatíticas do texto (linhas, palavras, caracteres)
    call show_stats       ; chama função para mostrar estatísticas

    add rsp, 64        ; libera espaço da pilha
    pop rbp            ; restaura o endereço da pilha
    ret                ; retorna da função

; MOSTRA ESTATÍSTICAS - exibe informações sobre o texto (linhas, palavras, caracteres)
show_stats:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência
    sub rsp, 32         ; reserva 32 bytes na pilha

    ; mostra linha divisória
    push sep_line      ; coloca endereço da linha divisória na pilha
    call print_string_win    ; chama função para imprimir linha divisória
    add rsp, 8               ; limpa a pilha

    ; mostra total de caracteres
    push stats_total         ; coloca endereço do texto "Total de caracteres: " na pilha
    call print_string_win    ; chama função para imprimir texto
    add rsp, 8               ; limpa a pilha"

    ; mostra o número
    mov rsi, stats_buffer        ; carrega buffer para conversão
    mov rax, [buffer_len]        ; carrega tamanho atual do texto (número de caracteres)
    call int_to_string           ; converte número para string

    lea rcx, [stats_buffer]      ; carrega endereço do buffer com o número convertido
    call print_string_win        ; chama função para imprimir o número

    ; mostra quebra de linha
    push newline_str             ; coloca endereço da nova linha na pilha
    call print_string_win        ; chama função para imprimir quebra de linha
    add rsp, 8                   ; limpa a pilha

    ; mostra linha divisória final
    push sep_line                ; coloca endereço da linha divisória na pilha 
    call print_string_win        ; chama função para imprimir linha divisória
    add rsp, 8                   ; limpa a pilha

    add rsp, 32         ; libera espaço da pilha
    pop rbp             ; restaura o endereço da pilha   
    ret                 ; retorna da função

; CONVERTE TEXTO PARA STRING - formata o conteúdo do buffer para exibição
   ; Entrada: RAX = número, RSI = buffer de saída
int_to_string:
    push rbp            ; salva o endereço atual da pilha
    mov rbp, rsp        ; cria novo ponto de referência
    push rbx            ; salva o registrador rbx (divisor)
    push rcx            ; salva o registrador rcx
    push rdx            ; salva o registrador rdx (resto da divisão)

    mov rbx, 10         ; divisor para conversão decimal
    mov rcx, rsi        ; endereço do buffer
    add rcx, 20         ; vai para o fim do buffer (20 caracteres máximo)
    mov byte [rcx], 0   ; coloca terminador nulo no final da string

.converte:
    dec rcx             ; volta uma posição no buffer
    xor rdx, rdx        ; zera rdx para divisão
    div rbx             ; divide RAX por 10, quociente em RAX, resto em RDX
    add dl, '0'         ; converte resto para caractere ASCII
    mov [rcx], dl       ; armazena caractere no buffer
    test rax, rax       ; verifica se quociente é zero
    jnz .converte       ; se não for zero, continua convertendo

    ; move string para o início do buffer (ajusta posição)
    mov rsi, rcx             ; rsi = posição de início da string convertida
    mov rdi, stats_buffer    ; rdi = início do buffer de estatísticas

.copia:
    mov al, [rsi]      ; carrega caractere da posição atual (fonte)
    mov [rdi], al      ; copia para o buffer de estatísticas (destino)
    inc rsi            ; avança para o próximo caractere
    inc rdi            ; avança para o próximo destino
    cmp al, 0          ; verifica se chegou ao terminador nulo
    jnz .copia         ; se não, continua copiando

    pop rdx            ; restaura rdx
    pop rcx            ; restaura rcx
    pop rbx            ; restaura rbx
    pop rbp            ; restaura o endereço da pilha
    ret                ; retorna da função

; LIMPEZA ANTES DE SAIR - fecha handles e mostra mensagem de saída
cleanup_and_exit:
    push rbp           ; salva o endereço atual da pilha
    mov rbp, rsp       ; cria novo ponto de referência
    sub rsp, 32        ; reserva 32 bytes na pilha

    ; mostra mensagem de saída
    lea rcx, [msg_quit]              ; carrega endereço da mensagem de saída
    call print_string_win            ; chama função para imprimir mensagem

    add rsp, 32        ; libera espaço da pilha
    pop rbp            ; restaura o endereço da pilha
    ret                ; retorna da função

; DADOS ADICIONAIS - funções auxiliares para manipulação de strings, contagem, etc
section .data
    sep_line        db "----------------------------------------", 13, 10, 0
    ; linha divisória para separa estatísticas
    stats_total     db "Total de caracteres ", 0    ; rótulo para estatísticas
    newline_str     db 13, 10, 0     ; string para quebra de linha

section .bss
    key_code        resb 1      ; código da tecla pressionada (1 byte)
    is_ctrl_s       resb 1      ; flag para Ctrl+S(1 byte)
    file_handle     resq 1      ; handle do arquivo aberto (8 bytes - QWORD)
    stats_buffer    resb 32     ; buffer para converter números (32 bytes)
