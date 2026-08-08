org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A

;
; FAT12 header
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'FungosOS   '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes


;
; Code goes here ...
;

start:
    jmp main

;
; Prints a string to the screen
; Params:
;   - ds:si : points to the string
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

    ; Read something from floppy disk
    ; BIOS should set DL to drive num

    mov [ebr_drive_number], dl

    mov ax, 1                   ; Second sector from disk
    mov cl, 1                   ; read 1 sector
    mov bx, 0x7E00              ; data after bootloader
    call disk_read

    ; print message
    mov si, msg_hello
    call puts

    cli
    hlt


;
; Error handelers
;

floppy_error:

    mov si, msg_disk_op_fail
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:

    mov ah, 0
    int 16h                     ; Wait for keypress
    jmp 0FFFFh:0                ; Jump to begining of BIOS, should reboot


.halt:
    cli                         ; Disable interrupts
    jmp .halt

;
; Converts LBA to CHS
; Params:
;   - ax : LBA address
; Returns:
;   - cx [bits 0-5] : sector
;   - cx [bits 6-15] : cylinder
;   - dh : head
;
lba_to_chs:

    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack
    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop dx
    mov dl, al
    pop ax
    ret


;
; Reads sectors from a disk
; Params:
;   - ax : LBA
;   - cl : num of sectors to read
;   - dl : drive number
;   - es:bx : memory store pointer
;
disk_read:

    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax

    mov ah, 02h
    mov di, 3                           ; retry count

.retry:

    pusha                               ; push all regs, wakaranai what bios will change
    stc                                 ; set carry flag, some bios'es are not smart and dont do it for me

    int 13h                             ; carry == clear -> success
    jnc .done

    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:

    jmp floppy_error                    ; all attempts exhausted

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret


;
; Resets the disk controler
; Params:
;   - dl: drive number
;
disk_reset:

    pusha

    mov ah, 0
    stc
    int 13h
    jc floppy_error

    popa
    ret
    

msg_hello: db 'Hello world!', ENDL, 0
msg_disk_op_fail: db 'DISK-OP-FAIL', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
