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
interface_name: .asciz "eth0"
ioctl_cmd: .word 0x8915  @ SIOCGIFADDR
src_addr_len: .word 16
.section .bss

    tftp_name: .skip 3 
    recv_buffer: .skip 300
    dhcp_offer_packet: .skip 300  // Reserve for the entire dhcp offer packet

    src_addr: .skip 16
    

    mac_buffer: .skip 6

    ip_octet: .skip 4
    ip_addr: .skip 4          @ Buffer for IP address
    ifreq: .skip 32            @ struct ifreq buffer

.section .text
.global _start

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


// R0 HOLDS THE BINARY VERSION OF eth0 IP ADDRESS.     



IP_TO_ASCII_CONVERSION:
    mov r5, #0
    mov r6, #0
    mov r7, #0
    mov r9, #0
    mov r8, #0
    ldr r0, =ifreq
    add r0, r0, #20
    ldr r10, =tftp_name
    mov r12, #'.'
    IP_NUM_CONVERSION:
        ldrb r4, [r0, r8]          @ r1 = oktet
        
        HUNDREDS:
            cmp r4, #100
            blt TENTHS 
            sub r4, r4, #100
            add r6, r6, #1

            b HUNDREDS

            TENTHS:
                cmp r4, #10  
                subhs r4, r4, #10
                addhs r7, r7, #1
                bhs TENTHS
                mov r9, r4
                add r8, r8, #1

                b NEXT

                NEXT: 
                    add r6, r6, #0x30
                    add r7, r7, #0x30
                    add r9, r9, #0x30
                   
                    strb r6, [r10, r5]
                    add r5, r5, #1
                    strb r7, [r10, r5]
                    add r5, r5, #1
                    strb r9, [r10, r5]
                    add r5, r5, #1

                    cmp r8, #3
                    blo IP_NUM_CONVERSION
                    strb r12, [r10, r5]
                    add r5, r5, #1











    mov r0, #1
    ldr r1, =tftp_name
    mov r2, #3            @ dĺžka (1-3)
    mov r7, #4
    svc #0
END:
    mov r7, #1
    svc #0
