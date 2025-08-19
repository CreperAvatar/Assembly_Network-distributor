.section .data
sockaddr_in:
    .hword 2        // sin_family = AF_INET(IPv4)
    .hword 0x4300   // port number = 67
    .word 0         // sin_addr = INADDR_ANY, 0.0.0.0
    .skip 8         // 8 bytes padding

sockaddr_offer:
    .hword 2
    .hword 0x4400
    .word 0xFFFFFFFF 
    .skip 8



new_line: .asciz "\n"

bootfile_name: .asciz "pxelinux.0"

sprava: .asciz "Dosiel az na koniec"

interface_name: .asciz "eth0"

ioctl_cmd: .word 0x8915  @ SIOCGIFADDR

src_addr_len: .word 16
so_broadcast_value: .word 1

.section .bss

    tftp_name: .skip 16 
    recv_buffer: .skip 300
    dhcp_offer_packet: .skip 300  // Reserve for the entire dhcp offer packet

    src_addr: .skip 16
    

    mac_buffer: .skip 6
    ip_octet: .skip 4
    ip_addr: .skip 4          @ Buffer for IP address
    ifreq: .skip 32            @ struct ifreq buffer

.section .text
.global _start

HEAD:
    _start:
        // Create socket
        mov r0, #2
        mov r1, #2
        mov r2, #0
        mov r7, #281
        svc #0
        
        mov r6, r0



    GET_IP_ADDRESS:
        INICIALIZATION:
            ldr r1, =ifreq
            ldr r2, =interface_name
            mov r3, #5                  @ Copy 5 bytes ("eth0\0")
        LOOP_IP_GET:
            ldrb r5, [r2], #1           @ Load byte from interface_name
            strb r5, [r1], #1           @ Store in ifreq
            subs r3, r3, #1      
            cmp r3, #0       
            bne LOOP_IP_GET
        IP_SYSCALL:
            @ Perform ioctl (SIOCGIFADDR)
            mov r0, r6                  @ Socket file descriptor
            mov r1, #0x8915             @ IOCTL command SIOCGIFADDR
            ldr r2, =ifreq              @ struct ifreq buffer
            mov r7, #54                 @ ioctl syscall
            svc #0       


    LISTEN_LOOP:

        // Bind socket
        mov r0, r6              //File descriptor of socket
        ldr r1, =sockaddr_in    //Pointer to address of structure sockaddr_in
        mov r2, #16             //Size of sockaddr_in structure (16 bytes)
        mov r7, #282            //Number of syscall
        svc #0

mov r13, r6
    
BODY:
    IP_TO_ASCII_CONVERSION:

        mov r8, #0
        mov r12, #'.'
        IP_NUM_CONVERSION:
            mov r6, #0
            mov r7, #0
            mov r9, #0  

            ldr r0, =ifreq
            add r0, r0, #20
            ldrb r3, [r0, r8]          

            mov r4, r3
            HUNDREDS:
                cmp r4, #100
                blt TENTHS

                sub r4, r4, #100
                add r6, r6, #1

                b HUNDREDS

                TENTHS:
                    cmp r4, #10
                    blt UNITS

                    sub r4, r4, #10
                    add r7, r7, #1

                    b TENTHS

                    UNITS:
                        cmp r4, #10
                        movlo r9, r4
                        b WRITE

            WRITE:
                ldr r10, =tftp_name

                WRITE_HUNDREDS:
                    cmp r6, #1
                    blt WRITE_TENTHS_SECTION

                    add r6, r6, #0x30
                    strb r6, [r10, r11]
                    add r11, r11, #1

                WRITE_TENTHS_SECTION:
                    cmp r6, #1
                    bhs WRITE_TENTHS_SEMI
                    blt WRITE_TENTHS_FINAL

                WRITE_TENTHS_SEMI:
                    cmp r7, #0
                    beq WRITE_TENTH_ZERO_FINAL
                    bhi WRITE_TENTHS_FINAL
                WRITE_TENTH_ZERO_FINAL:
                    addeq r7, r7, #0x30
                    strb r7, [r10, r11]
                    add r11, r11, #1

                    b WRITE_UNITS
                WRITE_TENTHS_FINAL:
                    cmp r7, #1
                    blt WRITE_UNITS

                    add r7, r7, #0x30
                    strb r7, [r10, r11]
                    add r11, r11, #1
  

                WRITE_UNITS:
                    add r9, r9, #0x30
                    strb r9, [r10, r11]
                    add r11, r11, #1

            
                cmp r8, #3
                addlt r8, r8, #1
                bllt WRITE_DOT
                blt IP_NUM_CONVERSION
                b SKIP
        WRITE_DOT:
            ldr r10, =tftp_name

            strb r12, [r10, r11]
            add r11, r11, #1
            bx lr

SKIP:

mov r0, #1
ldr r1, =tftp_name
mov r2, #14
mov r7, #4
SVC #0

mov r0, r13
mov r7, #6
SVC #0


END:
    mov r7, #1
    svc #0
