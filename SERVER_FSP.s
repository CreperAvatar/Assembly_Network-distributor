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
    ip_to_ascii:   .skip 16
    ip_addr: .skip 16          @ Buffer for IP address
    ifreq: .skip 32            @ struct ifreq buffer

.section .text
.global _start

_start:
    // Create socket
    mov r0, #2
    mov r1, #2
    mov r2, #17
    mov r7, #281
    svc #0
    mov r6, r0

    // Bind socket
    mov r0, r6              //File descriptor of socket
    ldr r1, =sockaddr_in    //Pointer to address of structure sockaddr_in
    mov r2, #16             //Size of sockaddr_in structure (16 bytes)
    mov r7, #282            //Number of syscall
    svc #0

LISTEN_LOOP:
    // recvfrom
    mov r0, r6
    ldr r1, =recv_buffer
    mov r2, #1024
    mov r3, #0
    ldr r4, =src_addr
    ldr r5, =src_addr_len
    mov r7, #292
    svc #0
    
    ldr r0, =recv_buffer
    add r0, r0, #28
    ldr r1, =mac_buffer

    mov r2, #0          // Byte offset

COPY_MAC_LOOP:
    ldrb r3, [r0, r2]
    strb r3, [r1, r2]
    add r2, r2, #1      // Load first,second,etc byte from recv_buffer and then save it into mac_buffer 
    cmp r2, #6          // If we haven't done 6th byte then jump back to copy_mac_loop, otherwise continue.
    bne COPY_MAC_LOOP



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
        ldr r1, =ioctl_cmd             @ IOCTL command SIOCGIFADDR
        ldr r2, =ifreq              @ struct ifreq buffer
        mov r7, #54                 @ ioctl syscall
        svc #0      

        ldr r0, =ifreq      @ Saves address of buffer ifreq into register r0
        add r0, r0, #16     @ Set location into ifreq buffer 16 bytes further 
        add r0, r0, #2      @ Set location into ifreq buffer into another 2 bytes further
        ldr r3, [r0]        @ Save IP address acquired in r0 register to the r3 register

        ldr r0, =ip_addr    @ Inserting address of ip_addr into r0 register
// R0 HOLDS THE BINARY VERSION OF eth0 IP ADDRESS.                       

mov r8, #0
mov r12, #0
IP_OCTET_SIZE:
    mov r3, #100
    ldrb r1, [r0, r8]
    add r8, r8, #1
    udiv r2, r1, r3

    cmp r2, #1
    movhs r9, #3
    bhs STORE_HUNDREDS_OCTET_SIZE

    cmp r2, #0
    beq TENTH

    TENTH:
    mov r3, #10
    udiv r2, r1, r3

    cmp r2, #1
    movhs r10, #2

    cmp r2, #0
    movhs r11, #1       //Units
    //Potom uloz tie data(cisla) o octetoch do bufferov. Nemame dost registrov bro.
    ldr r4, =ip_octet

    STORE_HUNDREDS_OCTET_SIZE:
    strb r9, [r4, r12]
    add r12, r12, #1
    b IP_OCTET_SIZE

    STORE_TENTH_OCTET_SIZE:
    strb r10, [r4, r12]
    add r12, r12, #1
    b IP_OCTET_SIZE

    STORE_UNITS_OCTET_SIZE:
    strb r11, [r4, r12]
    add r12, r12, #1
    b IP_OCTET_SIZE




mov r8, #0
IP_TO_ASCII_CONVERSION:
    ldr r1, =ip_to_ascii

    GET_BYTE_LOOP:
        ldrb r2, [r0, r8]       // Load to the register r2 first, second, etc byte of IP address
        strb r2, [r1, r8]
        add r8, r8, #1
        cmp r8, #4
        bne GET_BYTE_LOOP

@ ---------------------------------------------------------
    mov r8, #0
    mov r11, #0
    mov r10, #0
    mov r12, #'.'
    ldr r10, =tftp_name
    IP_NUM_CONVERSION:

        ldrb r4, [r1, r8]     //tu som si neni isty aky to ma vyznam presne

	    
@----------------------------------------------------------------------------------UNITS-OCTET-WRITE------------------------------------------------------------------------------
 
        //ZAPIS JEDNOTIEK POKIAL V OCTETE NIESU STOVKY ANI DESIATKY
        cmp r4, #10

        movlo r9, r4 
        addlo r9, r9, #0x30 //UNITS
        strlo r9, [r10, r11]
        addlo r11, r11, #1 

        bhs JUMP   //toto je kvoli tomu ze ked je cislo viac ako 10 ale zaroven sme octet napr. 2, tak by sa zapisala bodka ktoru nechceme tam mat, tak to skipne ten CMP pod tym
    
        cmp r8, #3
        strlo r12, [r10, r11]
        addlo r11, r11, #1
        addlo r8, r8, #1
        blo IP_NUM_CONVERSION
        bhs FORWARD_CONTINUE

        JUMP:
@-----------------------------------------------------------------------------ALL-HUNDREDS-SCENERIOS-FINISHED----------------------------------------------------------------------------------------       
@---------------------------------------------------------------------------------HUNDREDS-OCTET-WRITE-----------------------------------------------------------------------------
        mov r2, #100
        udiv r3, r4, r2
        cmp r3, #1      //If there are hundreds, continue.
        movhs r6, r3    // HOLD HUNDRED (if there are actually hundreds. Otherwise, go fuck your self..SKIP) 
        movhs r6, r6, #0x30     //ASCII OFFSET
        strhs r6, [r10, r11]
        addhs r11, r11, #1            
        movhs r7, #0
        bhs IP_NUM_SUBS_LOOP_HUNDREDS



        cmp r3, #0 	//If there are tenths(with or without units, it will be decided later)
	    beq IP_NUM_SUBS_LOOP_TENTHS

	    IP_NUM_SUBS_LOOP_TENTHS:
	        mov r2, #10
	        udiv r3, r4, r2
	        mov r7, r3
            add r7, r7, #0x30
            str r7, [r10, r11]
            add r11, r11, #1

            SPLIT_TENTHS_UNITS:
                sub r3, r4, r2
                cmp r3, #10
                bhs SPLIT_TENTHS_UNITS
                mov r9, r3
                add r9, r9, #0x30
                str r9, [r10, r11]
                add r11, r11, #1
                cmp r8, #3
                strlo r12, [r10, r11]
                addlo r11, r11, #1
                addlo r8, r8, #1
                blo IP_NUM_CONVERSION
                bhs FORWARD_CONTINUE

        
        //BUDE TO KONTROLOVAT TO ZE KED NA STOVKACH JE NULA TAK BUDE KONTROLVAT ZE CI JE AJ NA DESIATKACH A JEDNOTKACH.
@---------------------------------------------------------------HUNDREDS-CONTROL-OF-OCTET
        IP_NUM_SUBS_LOOP_HUNDREDS:                              //If hundreds exist only
            sub r5, r4, r2      //Holds substracted value of value which is stored in  r4
            cmp r5, #100        
            bhs IP_NUM_SUBS_LOOP_HUNDREDS


            cmp r5, #0      //(100 - 100 | 200 - 100) loop = 0  --------------------  KONTROLA CI NA DESIATKACH JE NULA
            moveq r7, r5

            

            cmp r5, #10                    //ZAPIS JEDNOTIEK POKIAL NA DESIATKE JE NULA (TAKISTO SA ZAPISU DESIATKY = 0)
            addlo r7, r7, #0x30
            strlo r7, [r10, r11]
            addlo r11, r11, #1
            movlo r9, r5
            addlo r9, r9, #0x30
            strlo r9, [r10, r11]
            addlo r11, r11, #1
            bhs TAKE_OUT_TENTH
            cmp r8, #3
            strlo r12, [r10, r11]
            addlo r11, r11, #1
            addlo r8, r8, #1
            blo IP_NUM_CONVERSION
            bhs FORWARD_CONTINUE


            TAKE_OUT_TENTH:             //ZAPIS DESIATOK POKIAL TAM NIE JE NULA
                mov r2, #10
                udiv r3, r5, r2     //Holds second digit of byte
                mov r7, r3           //Holds tenth 
                str r7, [r10, r11]
                add r11, r11, #1       
            IP_NUM_SUBS_LOOP_TENTH:     //NASLEDNY ZAPIS JEDNOTIEK (POKIAL NA DESIATKACH NIE JE NULA)
                    sub r3, r5, r2
                    cmp r3, #10
                    bhs IP_NUM_SUBS_LOOP_TENTH
                    mov r9, r3
                    str r9, [r10, r11]
                    add r11, r11, #1
                    cmp r8, #3 
                    strlo r12, [r10, r11]
                    addlo r11, r11, #1
                    addlo r8, r8, #1
                    blo IP_NUM_CONVERSION
                    bhs FORWARD_CONTINUE
            FORWARD_CONTINUE:


       


              //ASCII_CONVERSION nie je potrebny momentalne ale neham ho tu zatial (vsetko sa teda zapisuje uz v tom IP_NUM_CONVERSION)
        ASCII_CONVERSION:
        ldr r0, =tftp_name       //ASCII VERSION OF IP ADDRESS
        mov r12, #'.'

        add r6, r6, #0x30   //HUNDREDS
        add r7, r7, #0x30   //TENTH
        add r9, r9, #0x30   //UNITS

        //cmp r10, #0


        strb r6, [r0, r11] // 0
        add r11, r11, #1        
        strb r7, [r0, r11] // 1       
        add r11, r11, #1        
        strb r9, [r0, r11] // 2        
        add r11, r11, #1
        
        strb r12, [r0, r11] //4
        add r11, r11, #1

@ --------------------------------------------------------



//                              DHCP OFFEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEER
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
