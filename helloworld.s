org 0x7C00
bits 16


start:
  cli
  xor ax, ax
  mov ds, ax
  mov es, ax



WRITE:
  cmp al, 0x0D
  je halt_program

  mov ah, 00h
  INT 16h

  mov ah, 0eh
  mov bh, 00h
  INT 10h

  jmp WRITE


halt_program:
  hlt
  jmp halt_program

times 510 - ($ - $$) db 0
dw 0xAA55
