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

        ldr r0, =ifreq      @ Saves address of buffer ifreq into register r0
        add r0, r0, #16     @ Set location into ifreq buffer 16 bytes further 
        ldr r3, [r0]        @ Save IP address acquired in r0 register to the r3 register

        ldr r0, =ip_addr    @ Inserting address of ip_addr into r0 register
        str r3, [r0]
// R0 HOLDS THE BINARY VERSION OF eth0 IP ADDRESS.   




mov r0, #0
mov r3, #0
mov r4, #0
mov r6, #0
mov r7, #0
mov r8, #0
mov r9, #0
mov r10, #0
mov r11, #0
mov r12, #'.'

IP_TO_ASCII_CONVERSION:

    IP_NUM_CONVERSION:
        ldr r0, =ifreq
        add r0, r0, #20
        ldrb r3, [r0, r8]          @ r1 = oktet

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

                mov r7, #0
                b WRITE_UNITS
            WRITE_TENTHS_FINAL:
                cmp r7, #1
                blt WRITE_UNITS

                add r7, r7, #0x30
                strb r7, [r10, r11]
                add r11, r11, #1

                mov r7, #0    

            WRITE_UNITS:
                add r9, r9, #0x30
                strb r9, [r10, r11]
                add r11, r11, #1
                
                mov r9, #0
                mov r6, #0

            
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
    mov r2, r11         
    mov r7, #4
    svc #0

GET_DISCOVERY_ATTRIBUTES:
    ldr r0, =recv_buffer
    add r0, r0, #4  //Transaction ID

    ldr r2, [r0]

    ldr r0, =recv_buffer
    add r0, r0, #8  //secs

    ldr r3, [r0]

    ldr r0, =recv_buffer
    add r0, r0, #10 //flags

    ldr r5, [r0]

DHCP_OFFER:
    ldr r0, =dhcp_offer_packet

    mov r1, #2  // BOOT REPLY
    strb r1, [r0, #0]

    mov r1, #1
    strb r1, [r0, #1]

    mov r1, #6
    strb r1, [r0, #2]
    
    mov r1, #0
    strb r1, [r0, #3]

    mov r1, r2     // Transaction ID must be extracted from DHCP discover packet
    str r1, [r0, #4]

    mov r1, r3     // Secs - must be extracted from DHCP discover packet
    strb r1, [r0, #8]

    mov r1, r5          // flags  -  1 == broadcast(Client doesn't have IP address), 0 == unicast(Client does have IP address)
    strb r1, [r0, #10]  

    mov r1, #0          // ciaddr - Client IP address(none)
    strb r1, [r0, #12]  

    mov r1, #0          // yiaddr - By SERVER offered IP ADDRESS(none)
    strb r1, [r0, #16]  

    mov r1, r4
    str r1, [r0, #20]  // siaddr - IP address of the TFTP server

    mov r1, #0
    strb r1, [r0, #24]  // giaddr - IP address of relay agent

    ldr r1, =mac_buffer
    str r1, [r0, #28]  // chaddr - MAC address of a client

    mov r1, #0
    strb r1, [r0, #44]  // sname - Optional server host name

    ldr r1, =bootfile_name
    strb r1, [r0, #108]  // file - Boot file name
//Options are located at offset 236
    add r0, r0, #236
    @ ---- MAGIC COOKIE (0x63 0x82 0x53 0x63) ---- @ 
    movw r1, #0x8253    @ low 16 bits
    movt r1, #0x6382    @ high 16 bits
    str r1, [r0], #4

    //  ---- Option 66: TFTP server name
    
END:
    mov r7, #1
    svc #0
