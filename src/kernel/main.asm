org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


start:
    jmp main

;
; Prints a string to the screen
; Params:
;   - ds:si points to the string
;
puts:
    ; save regs we modify
    push si
    push ax
    
.loop:
    lodsb                       ; Next char to al
    or al, al
    jz .done
    
    mov ah, 0x0e                ; Call bios interrupt
    mov bh, 0
    int 0x10
    
    jmp .loop
    
.done:
    pop ax
    pop si
    ret

main:

    ; Setup data segments
    mov ax, 0                   ; Cant write to ds/es directly
    mov ds, ax
    mov es, ax

    ; Setup stack
    mov ss, ax
    mov sp, 0x7C00              ; Grows downward

    ; print message
    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Hello world!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
