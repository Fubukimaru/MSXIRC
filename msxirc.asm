; Modificado para compilar con pasmo
;
; MSX IRC Client v 1.0
;
; constante


;--- Macro for printing a $-finished string

print MACRO param 
    ld  de, param
    ld  c,_STROUT
    call    DOS
    endm

;--- DOS function calls


DOS equ #0005

_TERM0:     equ #00 ;Program terminate
_CONIN:     equ #01 ;Console input with echo
_CONOUT:    equ #02 ;Console output
_DIRIO:     equ #06 ;Direct console I/O
_INNO:      equ #07     ;
_INNOE:     equ #08 ;Console input without echo
_STROUT:    equ #09 ;String output
_BUFIN:     equ #0A ;Buffered line input
_CONST:     equ #0B ;Console status
_FOPEN:     equ #0F ;Open file
_FCLOSE:    equ #10 ;Close file
_SDMA:      equ #1A ;Set DMA address
_RBREAD:    equ #27 ;Random block read
_TERM:      equ #62 ;Terminate with error code
_DEFAB:     equ #63 ;Define abort exit routine
_DOSVER:    equ #6F ;Get DOS version
_GETDATE:   equ #2A ;Get Date 
_GETTIME:   equ #2C ;Get Time

;--- BIOS functions calls
bios MACRO param   
    rst #30     ; Inter slot call
    db  0       ; Slot number
    dw  param   ; Call address
    endm

RDSLT:      equ #0C
INITXT:     equ #006C
LINNL40:    equ #F3AE
LDIRVM:     equ #5C
RDVRM:      equ #4A
WRTVRM:     equ #4D
WRTVDP:     equ #47 ;C=R, B=Data
FILVRM:     equ #56
CHGET:      equ #9F
INLIN:      equ #B1
BREAKX:     equ #B7
BEEP:       equ #C0
CLS:        equ #C3
POSIT:      equ #C6
GTSTCK:     equ #D5


ENASLT:     equ #0024
TPASLOT1:   equ #F342
ARG:        equ #F847
EXTBIO:     equ #FFCA
TIMER:      equ #FC9E

;--- Scan code special buttons

ESC_:       equ 27
UP_:        equ 30
DOWN_:      equ 31
LEFT_:      equ 29
RIGHT_:     equ 28
TAB_:       equ 9
BS_:        equ 8
SELECT_:    equ 24
CLS_:       equ 11
INC_:       equ 18
DEL_:       equ 127



;--- TCP/IP UNAPI routines

TCPIP_GET_CAPAB:    equ 1
TCPIP_DNS_Q:        equ 6
TCPIP_DNS_S:        equ 7
TCPIP_TCP_OPEN:     equ 13
TCPIP_TCP_CLOSE:    equ 14
TCPIP_TCP_ABORT:    equ 15
TCPIP_TCP_STATE:    equ 16
TCPIP_TCP_SEND:     equ 17
TCPIP_TCP_RCV:      equ 18
TCPIP_WAIT:         equ 29

;--- TCP/IP UNAPI error codes

ERR_OK:             equ 0
ERR_NOT_IMP:        equ 1
ERR_NO_NETWORK:     equ 2
ERR_NO_DATA:        equ 3
ERR_INV_PARAM:      equ 4
ERR_QUERY_EXISTS:   equ 5
ERR_INV_IP:         equ 6
ERR_NO_DNS:         equ 7
ERR_DNS:            equ 8
ERR_NO_FREE_CONN:   equ 9
ERR_CONN_EXISTS:    equ 10
ERR_NO_CONN:        equ 11
ERR_CONN_STATE:     equ 12
ERR_BUFFER:         equ 13
ERR_LARGE_DGRAM:    equ 14
ERR_INV_OPER:       equ 15



;***   MAIN PROGRAM   ***
    ; MSX-DOS start's *.com files at #100
    org     #100
    ld      hl,(chsas)      ; chsas = 1255 
    ld      de,1255
    xor     a
    sbc     hl,de
    ret     nz              ; if chsas != 1255, exit. TODO: Why this?

    ;--- Checks the DOS version and establishes variable DOS2

    ld      c,_DOSVER
    call    DOS
    or      a
    jr      nz,NODOS2
    ld      a,b
    cp      2
    jr      c,NODOS2

    ld      a,#FF
    ld      (DOS2),a    ;#FF for DOS 2, 0 for DOS 1
    print   USEDOS2_S
NODOS2:     
    ;--- Prints the presentation
    print   PRESENT_S
    print   INFO_S

    ;--- Checks if there are command line parameters.
    ;    If not, prints information and finishes.

    ld      a,1
    ld      de,BUFFER
    call    EXTPAR
    jr      c,NOPARA
; convert filename.ext to FILENAMEEXT 8+3
    ld      hl,BUFFER
    ld      DE,FCB+1
    call    CFILENAME   
;   print   FCB+1

NOPARA:
    ;--- Open file .ini, set user parameters
    ld      de,FCB
    ld      c,_FOPEN
    call    DOS
    or      a
    ld      de,NOINIF_S
    jp      nz,PRINT_TERML
    ld      de,BUFFER
    ld      c,_SDMA
    call    DOS
    ld      hl,1    ; set recod = 1 byte
    ld      (FCB+14),hl
    ld      de,FCB
    ld      hl,512  ; read 512 recod  
    ld      c,_RBREAD
    call    DOS
    ld      (LBUFF),hl  
    ld      de,BUFFER
    add     hl,de
    xor     a
    ld      (hl),a      ; 0 -> end record's
    ld      de,FCB
    ld      c,_FCLOSE
    call    DOS
    ;--- Extract user parametr's
    ld      bc,(LBUFF)
    ld      a,b
    or      c
    jp      z,CHECKSL   ;not recod
    ld      hl,BUFFER
    ld      iy,WRDPA
    call    G_PA
    ld      a,(PA_ST)
;   or      %11100100
;   cp      %11111111
    and     %01000000
    call    nz,LOADFONT
; aplicate color and timestamp parameters
    call    APP_PA

;
; TODO: What is it doing here? Interrupts are doing something.
; B = 60 -> wait for interrupt and check value
; While not condition, wait here.
CHECKSL:
    ei
    ld  b,60
Lsw:    
    halt
    djnz    Lsw
; End wait


; SCREEN INIT
    call    INISCREEN


; 1st screen ( info )

;   clear screen
    call    CLS_G
    call    LOAD_S
; ini system windows
    ld      hl,WCB4
    ld      de,sWCB0
    ld      bc,24
    ldir
; ini select page windows
    ld      hl,WCB5
    ld      de,sWCB1
    ld      bc,24
    ldir
; posit BIOS cursor
    ld      hl,#0019 ;v-25
    bios    POSIT
; print system information
    ld      ix,sWCB0
    ld      bc,0    
    ld      (sWCB0+6),bc ;set cursor
    ld      hl,SYSMESS1
    call    PRINT_TW
    ld      a,(PA_ST)
    and     %01000000
    jr      z,Ls01
    ld      a,(fntsour)
    or      a
    jr      z,Ls02
    ld      hl,SM_fntLOAD
    call    PRINT_TW
    jp      LsSP1
Ls02:
    ld  hl,SM_fntLERR
    call    PRINT_TW
    ld      a,(fferr)
    add     a,"0"
    call    OUTC_TW
    ld      a,13
    call    OUTC_TW
    ld      a,10
    call    OUTC_TW
Ls01:   
    ld  hl,SM_fntBIOS
    call    PRINT_TW
; DEBUG:
; test 
   ld  b,8+13
   ld  hl,FCB+1
LsT1:  push    hl
   ld  a,(hl)
   call OUTC_TW
   pop hl
   inc hl
   djnz    LsT1
   ld  a,13
   call    OUTC_TW
   ld  a,10
   call    OUTC_TW

   ld  hl,PA_FONT
   call    PRINT_TW

   ld  de,(ttvar)
   ld  hl,BUFFER
   ld  b,5
   ld  c,0
   ld  a,%00001000
   call    NUMTOASC
   call    PRINT_TW

; end test


; Fubu: MAPPER STUFF

LsSP1:
    ld      a,(DOS2)
    or      a
    jp      nz,LsSPD2
    ;--- DOS1 not mapper support
    ld      hl,SM_DOS1MAP
    call    PRINT_TW
    call    INIMAPDOS1
    jr      MAPPER3

LsSPD2:
    ;--- Get mapper support routines in DOS 2
    ld      de,#0402
    xor     a
    call    EXTBIO
    ld      ix,sWCB0
    or      a
    jp      nz,MAPPER2
    ld      hl,SM_NOMAPPER
    call    PRINT_TW
    jp      NOMAPPER
MAPPER2:ld  (totmaps),a
    ld      a,c
    ld      (freemaps),a
    ld      de,ALL_SEG
    ld      bc,16*3
    ldir

    ld      hl,SM_D2MAPI
    call    PRINT_TW
MAPPER3:
    ld      hl,SM_D2M_TOT
    call    PRINT_TW
    ld      d,0
    ld      a,(totmaps)
    ld      e,a
    ld      hl,BUFFER
    ld      b,3
    ld      c," "
    ld      a,%00001000
    call    NUMTOASC
    call    PRINT_TW
    ld      a,13
    call    OUTC_TW
    ld      a,10
    call    OUTC_TW

    ld      hl,SM_D2M_FREE  
    call    PRINT_TW
    ld      d,0
    ld      a,(freemaps)
    ld      e,a
    ld      hl,BUFFER
    ld      b,3
    ld      c," "
    ld      a,%00001000
    call    NUMTOASC
    call    PRINT_TW
    ld      a,13
    call    OUTC_TW
    ld      a,10
    call    OUTC_TW
    
    call    GET_P2
    ld  (P2_sys),a

    ld  iy,EMAPTAB
    ld  a,16
MAPPER4:
;   push    af
;   ld  d,0
;   ld  e,(iy+1)
;   ld  hl,BUFFER
;   ld  b,9
;   ld  c,0
;   ld  a,%10001101
;   call    NUMTOASC
;   call    PRINT_TW
;   ld  d,0
;   ld  e,(iy+0)
;   ld  hl,BUFFER
;   ld  b,9
;   ld  c,0
;   ld  a,%10001101
;   call    NUMTOASC
;   call    PRINT_TW
;   ld  a,13
;   call    OUTC_TW
;   ld  a,10
;   call    OUTC_TW
;   pop af  
;   inc iy
;   inc iy
;   dec a
;   jr  nz,MAPPER4

    

    call    GET_P1      ; TCP/IP calls use  
    ld  (TPASEG1),a


NOMAPPER:   ; ****************************************** 
INITCP:
    call    GET_P1
    ld      (S_U),a     ; save work mapper
    ld      a,(#A8)
    rra
    rra
    or      %10000000
    and     %10000011
    ld      b,a
    ld      a,(#FFFF)
    xor     #FF
    and     %00001100
    or      b
    ld      (S_L),a


    ;> From this point we can call TERMINATE to return to DOS.

    ;--- Search a TCP/IP UNAPI implementation

    ld      hl,TCPIP_S  ; API specification identifier (TCP/IP)
    ld      de,ARG      ;
    ld      bc,15
    ldir
    
    xor     a       ; how many API (identifier) ?
    ld      b,a     ;
    ld      de,#2222    ;
    call    EXTBIO
    ld      a,b
    or      a       ; =0 ?
    ld      hl,NOTCPIP_S
    jp      z,IUNAPID

    ld      a,1     ; 1-st API (identifier = TCP/IP)
    ld      de,#2222
    call    EXTBIO      ;A=slot , B=segment (#FF=not RAM), HL=enter if #C000-FFFF
                        ; page - 3 tehn A,B register not use  
    ;--- Setup the UNAPI calling code

;   ld  (CALL_UNAPI+1),hl
    ld      (CALL_um+8),hl ;*
    ld      (CALL_U+17),hl ;*

    ld      c,a
    ld      a,h
    cp      #C0
    ld      a,c
    jr      c,NO_UNAPI_P3

;   ld      a,#C9
;   ld      (SET_UNAPI),a
    ld      a,#C3       ;*  
    ld      (CALL_U),a  ;* (JP XXXX (hl))
    ld      (CALL_U+1),hl   ;*

    ld      hl,SM_UNAPI3
    jr      OK_SET_UNAPI

NO_UNAPI_P3:

;   ld      (UNAPI_SLOT+1),a ; set slot UNAPI
    ld      (CALL_U+5),a    ; * slot UNAPI
    ld      a,(S_L)     ; *
    ld      (CALL_U+24),a   ; * slot work

    ld      a,b
    cp      #FF
    jr      nz,NO_UNAPI_ROM
    
;   ld      a,#C9
;   ld      (UNAPI_SEG),a

    ld      hl,SM_UNAPIR
    jr      OK_SET_UNAPI
NO_UNAPI_ROM:

;   ld      (UNAPI_SEG+1),a
    ld      (CALL_um+2),a   ; * UNAPI segment
    ld      a,(S_U)     ; *
    ld      (CALL_um+12),a  ; * work segment
    ld      hl,CALL_um  ; *
    ld      de,CALL_U   ; *
    ld      bc,18       ; *
    ldir                ; *


    ld      hl,SM_UNAPIM
    jp      OK_SET_UNAPI
IUNAPID:    
    ld      a,#C9 ;(RET)
    ld      (CALL_U),a
    ld      a,1
    ld      (notcpip),a
OK_SET_UNAPI:
    ld      ix,sWCB0
    call    PRINT_TW
; 


;***************************************************************
;   Root enter main programm
;   System info, select work segment's open/close segment,s
;***************************************************************
SYS_S:  
    ld      a,(segp)
    ld      (segsel),a
SYS_S1:
    ld      ix,sWCB0
    ld      a,(P2_sys)
    call    PUT_P2
    call    BFSegT
    call    BOSegT
    call    LOAD_S


; draw attribute cursor segment select (ix+10) 1..24 (0-off)
    ld      ix,sWCB1
    call    CLAT_C_N

    call    SETAT_S
    call    LOAD_SA

LsSPW:  

    call    TCPSEP
    call    CLOCK   
    ld      c,_CONST
    call    DOS
    or      a
    jr      z,LsSPW
    ld      c,_INNO
    call    DOS
    ld      b,a
;   ld      a,(S_C)
;   call    PUT_P2
    ld      ix,sWCB0
    ld      hl,#FBEB
    ld      a,b
    bit     5,(hl)
    jp      z,Ls_help
    cp      #0D
    jp      z,Ls_GoTo
    cp      LEFT_
    jp      z,LsDEC
    cp      UP_
    jp      z,LsDEC
    cp      DOWN_
    jp      z,LsINC
    cp      RIGHT_
    jp      z,LsINC
    cp      27
    jp      z,Ls_ESC
    and     %01011111
    cp      "S"
    jp      z,SERV_C
    cp      "Q"
    jp      z,EXIT

    jp      LsSPW
S_LEFT:
    ld      a,(segp)
    ld      b,a
S_L2:
    dec     b
    ld      a,#FF
    cp      b
    jr      nz,S_L3
    ld      b,79
S_L3:       ld  a,b     
    rla
    ld      e,a
    ld      d,0
    ld      hl,MAPTAB
    add     hl,DE
    ld      a,(hl)
    or      a
    jr      z,S_L2
S_L1:       ld  a,b
    ld      (segsel),a
    jp      Ls_GoTo

S_RIGHT:    
    ld      a,(segp)
    ld      b,a
S_R2:
    inc     b
    ld      a,79
    cp      b
    jr      nc,S_R3
    ld      b,0
S_R3:       ld  a,b     
    rla
    ld      e,a
    ld      d,0
    ld      hl,MAPTAB
    add     hl,DE
    ld      a,(hl)
    or      a
    jr      z,S_R2
S_R1:       ld  a,b
    ld      (segsel),a
;   jp      Ls_GoTo

; Go to on selected segment (channel/Query/Server/Help)

Ls_GoTo:    
    call    CLAT_C_N
    call    LOAD_SA
    xor     a
    ld      a,(segsel)
Ls_go1:     rla
    ld      e,a
    ld      d,0
    ld      hl,MAPTAB
    add     hl,DE
    ld      a,(hl)
    and     %01111111
    cp      "H"
    jp      z,LsEnSH
    cp      "C"
    jp      z,LsEnCS
    cp      "S"
    jp      z,LsEnSS
    cp      "Q"
    jp      z,LsEnQS
    ld      a,(P2_sys)
    call        PUT_P2
    ld      hl,SM_LostSeg
    call        PRINT_TW
    jp      LsSPW
LsDEC:
    ld      ix,sWCB1
    ld      a,(ix+10)   
    cp      1
    jr      z,LsD1
    dec     a
    ld      (ix+10),a
    jp      LsD2
LsD1:       ld  a,(ix+22)
    or      a
    jp      z,LsSPW
    dec     a
    ld      (ix+22),a
LsD2:       ld  a,(ix+10)   
    add     a,(ix+22)
;   inc     a
    ld      hl,#9000
    ld      de,50+4+1
LsD4:       dec a
    jr      z,LsD3
    add     hl,de
    jr      LsD4
LsD3:       ld  a,(hl)
    ld      (segsel),a

    jp      SYS_S1
LsINC:
    ld      ix,sWCB1
    ld      b,(ix+10)
    ld      c,(ix+22)
    ld      a,b
    add     a,c
    cp      (ix+16)
    jp      nc,LsSPW
    ld      a,b
    cp      (ix+5)
    jr      nc,LsI1
    inc     a
    ld      (ix+10),a
    jr      LsD2
LsI1:       inc c
    ld      (ix+22),c
    jr      LsD2

; Go to back segment
Ls_ESC:
    call    CLAT_C_N
    call    LOAD_SA
    xor     a
    ld      a,(segp)
    jp      Ls_go1



LsEnSH:
;************************************
; Enter Help Segment
;************************************
    inc     hl
    ld      a,(hl)
    ld      (S_C),a
    ld      a,(segsel)
    ld      (segp),a
    jp      Hmcw    

Ls_help:
;************************************
; Select Help Segment (Open if need)    
;************************************
; clear kbd buffer
    call    CLKB
    call    CLAT_C_N
; Find help segment
    ld      a,"H"
    ld      de,helpdes
    call    SrS
    jr      c,Ls_h_noh
    ld      (S_C),a
    jp      Hmcw

; Help segment not found, ini help segment
Ls_h_noh:
; get allocate record
    call    ALL_REC
    ld      a,b
    ld      (segp),a
    jp      c,NO_REC
    push    hl
    ld      a,0
    ld      b,0
    call    ALL_SEG
    pop     hl
    jp      c,NO_SEG
; set record to H status
    ld      (hl),"H"
    inc     hl
; set segment mapper
    ld      (hl),a
; ini Help Segment
    ld      (S_C),a
    call    PUT_P2
    call    CLS_G

    ld      a,(segp)
    ld      (segs),a

    ld      d,0
    ld      a,(segs)
    ld      e,a
    ld      hl,#8000
    ld      b,2
    ld      c,"0"
    ld      a,%00000000
    call    NUMTOASC

    ld      hl,#8000+3
    ld      (hl),"H"    ; Help segment status
    inc     hl
    inc     hl
    ld      de,helpdes  ; Help segment descriptor
    ex      de,hl
    ld      bc,4
    ldir

; test block
;   ex  hl,de
;   ld  d,0
;   ld  a,(S_C)
;   ld  e,a
;   ld  c,"0"
;   ld  b,3
;   ld  a,0
;   inc hl
;   call    NUMTOASC
; end test, block

;
    ld      hl,WCB0     ; help WCB template
    ld      de,sWCB0
    ld      bc,24
    ldir            ; set WCB to segment
    ld      ix,sWCB0
; load help file
    ld      hl,FCBhelp+1+8+3
    ld      b,28
    xor     a
LsHi2:  ld  (hl),a
    inc     hl
    djnz    LsHi2
    ld      a,(P2_sys)
    call    PUT_P2
    ld      de,FCBhelp
    ld      c,_FOPEN
    call    DOS 
    ld      de,#9000
    ld      c,_SDMA
    call    DOS
    ld      hl,1
    ld      (FCBhelp+14),hl
    ld      de,FCBhelp
    ld      hl,#BFFF-#9000
    ld      c,_RBREAD
    call    DOS
    ld      (var2),hl
    ld      de,FCBhelp
    ld      c,_FCLOSE
    call    DOS
;   ld      h,0 ;
;   ld      l,26    ;
; copy help buffer to help segment
    ld      hl,#9000;
LsHi1:
    ld      a,(P2_sys)
    call    PUT_P2
    ld      a,(hl)
    ld      b,a
    ld      a,(S_C)
    call    PUT_P2
    ld      a,b
    ld      (hl),a
    inc     hl
    ld      a,h
    cp      #C0
    jr      nz,LsHi1
; set size help bufer
    ld      ix,sWCB0
    ld      hl,(var2)
    ld      de,(sWCB0+12)   ;#9000 text buffer
    add     hl,de
    ld      (sWCB0+16),hl   ; end buffer 

    call    BFSegT  ; rebuld active segment tabl

    jp      Hmcw    ; Help screen operations

Hmcw:
; bufer[ix+18] -> screen[cur]   
    ld      a,(S_C)
    call    PUT_P2


; set segment information attributes
    call    SSIA

    ld      ix,sWCB0    ;WCB
    call    CLS_TW
    ld      hl,(sWCB0+18)
    xor     a
    ld      (ix+6),a
    ld      (ix+7),a
    ld      (ix+21),a
    inc     a
;   ld      (ix+11),a       ; test load
Hmcw2:   ld     a,(ix+7) ;v pos
    ld      c,(ix+5) ;v max
    cp      c
    jp      p,Hmcw1   ; y posit > max y (out of screen)
    ld      de,(sWCB0+16)
    ld      a,l
    sub     e
    ld      a,h
    sbc     a,d
    jr      nc,Hmcw3  ; out of buffer
    ld      a,(hl)
    inc     hl
    cp      #0A
    jr      nz,Hmcw0
    ld      (sWCB0+22),hl   
Hmcw0:  push    hl
    call    OUTC_TW
    pop     hl
    jp      Hmcw2
Hmcw3:
    ld      a,1
    ld      (ix+21),a   ; out of buffer
Hmcw1:
    call    LOAD_S
; operations 
;   bios    CHGET
HmwcG:
    call    CLOCK
    call    TCPSEP
    jp  SEL_RE
HLP_RE:
    call    L_SIA   
    ld      c,_CONST
    call    DOS
    or      a
    jr      z,HmwcG
    ld      c,_INNO
    call    DOS
    ld      b,a
    ld      a,(S_C)
    call    PUT_P2
    ld      a,b
    ld      hl,#FBEB

; control end

    ld      ix,sWCB0
    cp      ESC_
    jp      z,Hmcw_EX
    cp      UP_
    jr      z,HmcwUP
    cp      DOWN_
    jr      z,HmcwDOWN
    bit     1,(hl)
    jr      z,HmcWCTRL
    jp      Hmcw
HmcWCTRL:
    cp      LEFT_
    jp      z,S_LEFT
    cp      RIGHT_
    jp      z,S_RIGHT
    and     %01011111
;   cp      5 ; (CTRL-E); "E"
    cp      17  ; CPTL+Q
    jp      z,HmcwCLOSE
    jp      Hmcw
    
HmcwUP:
    ld      b,1
    ld      hl,#FBEB
    bit     0,(hl)
    jr      nz,Hmcw_UP2
    ld      b,(ix+5)        ; *
Hmcw_UP2:
    ld      hl,(sWCB0+18)
    ld      de,(sWCB0+12)       ; top buffer
    dec     hl
Hmcw_UP1:
    xor     a
    push    hl
    sbc     hl,de
    pop     hl
    jp      m,Hmcw_UP3
    dec     hl
    ld      a,(hl)
    cp      #0A
    jr      nz,Hmcw_UP1
    dec     b
    jr      nz,Hmcw_UP1
Hmcw_UP3:
    inc hl
    ld  (sWCB0+18),hl
    jp  Hmcw
HmcwDOWN:
    ld  a,(ix+21)

    or  a          ; out of buffer
    jp  nz,Hmcw
    ld  hl,#FBEB
    bit 0,(hl)
    jr  nz,Hmcw_DW0
    ld  a,(ix+22)
    ld  (ix+18),a
    ld  a,(ix+23)
    ld  (ix+19),a
    jp  Hmcw

Hmcw_DW0:
    ld  hl,(sWCB0+18)
Hmcw_DW1:
;   ld  a,(hl)
;   inc hl
;   cp  #0A
;   jr  nz,mcw_DW1
    ld  a,#0A
    ld  bc,0
Hmcw_DW2    cpir
    jp  nz,Hmcw_DW2

    ld  (sWCB0+18),hl
    jp  Hmcw
Hmcw_EX:
    ld  a,(segp)
    ld  (segsel),a
    jp  SYS_S
HmcwCLOSE:
    ld  a,(segp)
    call    FRE_RECS
    call    BFSegT
    ld  a,(ix+16)
    or  a
    jp  z,SYS_S
    jp  S_LEFT;

LsEnSS:
;*****************************************
; Enter Server Segment
;*****************************************
    inc hl
    ld  a,(hl)
    ld  (S_C),a
    ld  a,(segsel)
    ld  (segp),a
    jp  SRVC



;Create Server record (Server Console)
SERV_C:
;*****************************************
; Server control segment
;*****************************************
    call    CLKB            ; clear kbd buffer
    call    CLAT_C_N        ; clear attribute channel (server)
;
    ld  a,(serv1)       
    or  a
    jp  nz,NO_SERV      ; server record exist

    call    ALL_REC         
    ld  a,b
    ld  (segp),a
    jp  c,NO_REC
    push    hl
    ld  a,0
    ld  b,0
    call    ALL_SEG
    pop hl
    jp  c,NO_SEG
; set record to S status
    ld  (hl),"S"
    inc hl
; set segmet mapper
    ld  (hl),a
; Ini Server control segment
    ld  (S_C),a
    ld  (serv1s+1),a        ; mapper segment N save to sw
    call    PUT_P2
    call    CLS_G           ; global screen clear
    ld  a,1
    ld  (serv1),a       ; set exsist server record

    ld  a,(segp)
    ld  (segs),a    
    ld  (serv1s),a      ; save N record

    ld  d,0
    ld  a,(segs)    ; N segment record
    ld  e,a     
    ld  hl,#8000    
    ld  b,2
    ld  c,"0"
    ld  a,%00000000
    call    NUMTOASC
    ld  hl,#8000+3
    ld  (hl),"S"    ; S descriptor
    inc hl
    inc hl
    ld  iy,PA_SERVER    ; Server name -> name record
    ld  b,60    ; ***
SRVC2:  ld  a,(iy)
    or  a
    jr  z,SRVC1
    ld  (hl),a
    inc hl
    inc iy
    djnz    SRVC2
SRVC1:
; test block
;                   ; print # map segment
;        ld      d,0
;        ld      a,(S_C)
;        ld      e,a
;        ld      c,"0"
;        ld      b,3
;        ld      a,0
;       
;       inc     hl
;        call    NUMTOASC
;   not realise ?
; end test, block

    ld  hl,WCB01    ; server WCB template
    ld  de,sWCB0
    ld  bc,24
    ldir
    ld  ix,sWCB0
; Information block

    ld  hl,AA_SERVER
    call    PRINT_BF
    ld  hl,AA_CRLF
    call    PRINT_BF    
    ld  hl,AA_PORT
    call    PRINT_BF
    ld  hl,AA_CRLF
    call    PRINT_BF
    ld  hl,AA_SRVPASS
    call    PRINT_BF
    ld  hl,AA_CRLF
    call    PRINT_BF
    ld  hl,AA_NICK
    call    PRINT_BF
    ld  hl,AA_CRLF
    call    PRINT_BF
    ld  hl,AA_ANICK
    call    PRINT_BF
    ld  hl,AA_CRLF
    call    PRINT_BF
    ld  hl,AA_USER
    call    PRINT_BF
    ld  hl,AA_CRLF
    call    PRINT_BF
    ld  hl,SM_CONNS
    call    PRINT_BF
; 

;               ini windows enter string
    ld  hl,WCB3
    ld  de,sWCB2
    ld  bc,24
    ldir
    ld  ix,sWCB2
    call    CLS_TW  

; ini cursor
    xor a
    ld  (oldcur),a
    ld  (oldcur+1),a
;   inc a
    ld  (oldcur+2),a
; clear ct buffer
    ld  hl,#8A00
    ld  bc,270
Swi4:   xor a
    ld  (hl),a
    inc hl
    dec bc
    ld  a,b
    or  c
    jr  nz,Swi4

    call    LOAD_S
;   ini buffer for back loading

    ld  hl,#0019 ;v-25
    bios    POSIT
    call    CLKB
    call    BFSegT      ; rebuild active segmrnt tabl


SRVC:
    
SRVw:
    ld  a,(S_C)
    call    PUT_P2
    call    SSIA

    ld  ix,sWCB2

    ld  hl,(sWCB2+2)    ;*
    ld  d,0
    ld  e,(ix+6)
    add hl,de
    call    CURSOR
    call    LOAD_S

SRVC0:              ; macros auto
    ld  bc,(tsb)
    ld  a,b
    or  c
    jr  z,SRVCB
    dec bc
    ld  (tsb),bc
    ld  hl,(tsb+2)
    ld  a,(hl)
    inc hl
    ld  (tsb+2),hl
    jp  SRVCC
SRVCB:
    call    TCPSEP
    ld  a,(req)
    cp  1
    jp  z,CHANNEL_CREATE    ;CHANNEL_CREATE
    jp  SEL_RE
SRV_RE:
    call    L_SIA
;   ld  a,"s"
;   ld  (#8000+2),a

    call    newsload

    call    CLOCK
            ; keyboard input
    ld  c,_CONST
    call    DOS
    or  a
    jr  z,SRVC0
    ld  c,_INNO
    call    DOS
SRVCC:
    ld  b,a
    ld  a,(S_C)
    call    PUT_P2
    ld  ix,sWCB2
    ld  hl,#FBEB
    ld  a,b

    bit 7,(hl)
    jp  z,SRV_F3
    bit 6,(hl)
    jp  z,SRV_F2
    bit 5,(hl)
    jp  z,Ls_help ; JMP HELP
    cp  #0D
    jp  z,SRV_se
    cp  ESC_
    jp  z,SRV_EX
    cp  11  ; CLS/HOME cancel view buffer chancel
    jp  z,SRV_home
    cp  UP_
    jp  z,SRV_UP
    cp  DOWN_
    jp  z,SRV_DW
    cp  "&"
    jp  z,SRV_F4
    
;   cp  24  ; SELECT
;   jp  z,SRV_contr

; edit enter string
    cp  8 ; "BS" <-
    jp  z,SRV_bs
    cp  18 ; INS
    jp  z,SRV_ins
    cp  127 ; DEL
    jp  z,SRV_del   
    cp  LEFT_
    jp  z,SRV_left
    cp  RIGHT_
    jp  z,SRV_right

; regular char  
    ex  af,af'
    ld  a,(s_ins)
    or  a
    jr  z,SRV_r4    ; no insret option
;   ld  l,(ix+16)   ; b_end
;   ld  h,(ix+17)
    ld  hl,(sWCB2+16) ;*
    ld  e,l
    ld  d,h
    dec hl
;   ld  c,(ix+18)   ; b_cur
;   ld  b,(ix+19)
    ld  bc,(sWCB2+18)
    xor a
    sbc hl,bc
    jr  c,SRV_r4    ; no right part string
    inc hl
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    inc de
;   ld  (ix+16),e   ; b_end ++
;   ld  (ix+17),d
    ld  (sWCB2+16),de
    inc bc
    lddr                ; scroll 
SRV_r4: ex  af,af'
; save cahr to buff
;   ld  l,(ix+18)   ; b curs
;   ld  h,(ix+19)
    ld  hl,(sWCB2+18)
    ld  (hl),a
    inc hl
;   ld  (ix+18),l
;   ld  (ix+19),h
    ld  (sWCB2+18),hl
;   ld  e,(ix+16)   ; b end
;   ld  d,(ix+17)
    ld  de,(sWCB2+16)
    xor a
    sbc hl,de
    jr  c,SRV_r3
    inc de
;   ld  (ix+16),e   ; inc b_end
;   ld  (ix+17),d
    ld  (sWCB2+16),de
SRV_r3:
;
    ld  a,(ix+6)
    ld  b,(ix+4)
    dec b
    cp  b           ; screen cursor end positoin ?
    jr  nc,SRV_r1   ; y
    inc a           ; no, inc h-cur
    ld  (ix+6),a
    jr  SRV_r2
SRV_r1: 
;   ld  l,(ix+22)   ; inc star out buf
;   ld  h,(ix+23)
    ld  hl,(sWCB2+22)
    inc hl
;   ld  (ix+22),l
;   ld  (ix+23),h
    ld  (sWCB2+22),hl
SRV_r2:

    call    OUTSTRW
;   call    OUTC_TW
    jp  SRVw
SRV_ins
    ld  a,(s_ins)
    cpl 
    ld  (s_ins),a
    jp  SRVw
SRV_left:
    bit 1,(hl)
    jp  z,S_LEFT
;   ld  e,(ix+18)   ; b_cur
;   ld  d,(ix+19)
    ld  de,(sWCB2+18)
;   ld  l,(ix+12)   ; buff
;   ld  h,(ix+13)
    ld  hl,(sWCB2+12)
    xor a   
    sbc hl,de   ; |<- X
    jp  nc,SRVw ; no LEFT
    dec de
;   ld  (ix+18),e
;   ld  (ix+19),d
    ld  (sWCB2+18),de
; LEFT
        dec (ix+6)   ; c_cur --
    jp  p,SRVL1  ; > 0 norm
    inc (ix+6)   ; c_cur ++     
;   ld  (ix+22),e       ; then  (stout) := (cur)
;   ld  (ix+23),d
    ld  (sWCB2+22),de
SRVL1:  
    
    call    OUTSTRW
    jp  SRVw

SRV_right:
    bit 1,(hl)
    jp  z,S_RIGHT
;   ld  e,(ix+18) ; b_cur
;   ld  d,(ix+19)
    ld  de,(sWCB2+18)
;   ld  l,(ix+16) ; b_end
;   ld  h,(ix+17)
    ld  hl,(sWCB2+16)
;   dec hl
    inc de
    xor a
    sbc hl,de
    jp  c,SRVw    ; ->| X
;   ld  (ix+18),e
;   ld  (ix+19),d
    ld  (sWCB2+18),de
    ld  b,(ix+4)   ; H-size
    ld  a,(ix+6)   ; h_cur
    inc a
    cp  b
    jp  nc,SRV_R1
    ld  (ix+6),a
    jr  SRV_R2
SRV_R1:
;   ld  l,(ix+22)
;   ld  h,(ix+23)
    ld  hl,(sWCB2+22)
    inc hl
;   ld  (ix+22),l
;   ld  (ix+23),h
    ld  (sWCB2+22),hl

SRV_R2: call    OUTSTRW
    jp  SRVw
SRV_del:
;   ld  l,(ix+18) ; b_cur
;   ld  h,(ix+19)
    ld  hl,(sWCB2+18)
;   ld  e,(ix+16) ; b_end
;   ld  d,(ix+17) ; if b_cur > b_end -> exit ; if b_cur = b_end -> b_end-- ; if b_cur < b_end -> b_end--;scroll R 
    ld  de,(sWCB2+16)
;   inc hl
    dec de
    xor a
    sbc hl,de
    jr  c,SRV_del1   ; -1
    jp  nz,SRVw      ; 1
SRV_del1
;   ld  (ix+16),e ; dec b_end
;   ld  (ix+17),d
    ld  (sWCB2+16),de
    jr  z,SRV_del2   ; 0
; scroll right part string
    inc     de
    xor a
    add hl,de   
            ; hl = b_cur  de = b_end-1 old
    ex  de,hl   ; hl = b_end new de = B_cur
    sbc hl,de   ; 
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    dec hl
    inc bc
    ex	de,hl  ;
    ldir           


SRV_del2:
        call    OUTSTRW
    jp  SRVw
; "back space" delete last symlol hposit --
SRV_bs:
;   ld  l,(ix+12) ;buff 
;   ld  h,(ix+13)
    ld  hl,(sWCB2+12)
;   ld  e,(ix+18) ;cur
;   ld  d,(ix+19)
    ld  de,(sWCB2+18)
    xor a
    sbc hl,de     ; |<- X
    jp  nc,SRVw   ; no BS
    dec de
;   ld  (ix+18),e
;   ld  (ix+19),d
    ld  (sWCB2+18),de

; bs        
        dec (ix+6)   ; c_cur --
    jp  p,SRVbs1  ; > 0 norm
    inc (ix+6)   ; c_cur ++     
;   ld  (ix+22),e       ; then  (stout) := (cur)
;   ld  (ix+23),d
    ld  (sWCB2+23),de
SRVbs1: 
;scroll right part strint to left on 1 byte
;   ld  l,(ix+16)   ; end buff
;   ld  h,(ix+17)
    ld  hl,(sWCB2+16)
    dec hl              ; endbuff--
;   ld  (ix+16),l   
;   ld  (ix+17),h
    ld  (sWCB2+16),hl
    xor a
    sbc hl,de
    ld  a,h
    or  l
    jr  z,SRVbs2
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    inc hl
    ldir

SRVbs2: 
    call    OUTSTRW
    jp  SRVw

SRV_se:
;
    call    CLS_TW     ; clear enter string of screen
    xor a
    ld  (ix+6),a
    ld  (ix+7),a

    ld  hl,(sWCB2+16)
    ld  (hl),#0D
    inc hl
    ld  (hl),#0A
    inc hl     ; curs

    ld  de,(sWCB2+12) ;buff

    ld  (sWCB2+18),de ; curs

    ld  (sWCB2+22),de
    ld  (bbuf),de  ;
 
    xor a
    sbc hl,de
    ld  (lenb),hl  ;        

    ld  (sWCB2+16),de
;

    ld  a,(hl)
    cp  13
    jp  z,SRVw  ; epmty string not send
    
    call BuffOU
    jp  SRVw    

PRINT_BF:
    ld  bc,0    
    ld  (bbuf),hl
PR_BF2: ld  a,(hl)
    cp  "$"
    jr  z,PR_BF1
    or  a
    jr  z,PR_BF1
    inc hl
    inc bc
    jr  PR_BF2
PR_BF1: ld  (lenb),bc

    ld  a,(S_C)
    call    PUT_P2
    jr  BuffOU1


PRINT_BFT:
    ld  bc,0    
    ld  (bbuf),hl
PR_BFT2:
    ld  a,(hl)
    cp  "$"
    jr  z,PR_BFT1
    or  a
    jr  z,PR_BFT1
    inc hl
    inc bc
    jr  PR_BF2
PR_BFT1:
    ld  (lenb),bc
    
BuffOU:
    call    TCPSEND
;   string[bbuf,lenb] to buffer(ix)
    ld  hl,(bbuf)
    ld  (bbuf1),hl
    ld  hl,(lenb)
    ld  (lenb1),hl

    ld  hl,PA_NICK
    ld  (bbuf),hl
    ld  bc,32
    xor a
    cpir
    ld  bc,PA_NICK
    sbc hl,bc
    ld  (lenb),hl
    call    BuffOU1

    ld  hl,(bbuf1)
    ld  (bbuf),hl
    ld  hl,(lenb1)
    ld  (lenb),hl


BuffOU1:
    ld  bc,(lenb)
    ld  a,b
    or  c
    ret z
    ld  a,"*"
    ld  (w0new),a
    xor a
    ld  a,(segs)
    rla
    ld  c,a
    ld  b,0
    ld  hl,MAPTAB
    add hl,bc
    res 7,(hl)  

; time stump

    ld  a,(t_stmp)
    or  a
    jr  z,SRV_se00
    ld  ix,sWCB0
    ld  a,(ix+6)
    or  a
    jr  nz,SRV_se00
    call    CLOCK
    ld  hl,(bbuf)
    ld  (bbuf2),hl
    ld  hl,(lenb)
    ld  (lenb2),hl
    
    ld  hl,TABTS
    ld  a,(t_stmp)
    and #0F
    rla
    ld  c,a
    ld  b,0
    add hl,bc
    ld  e,(hl)
    inc hl
    ld  c,(hl)
    ld  d,#80
    ld  b,0
    ld  (bbuf),de
    ld  (lenb),bc
    call    SRV_se00
    ld  de,#8000+71
    ld  bc,1
    ld  (bbuf),de
    ld  (lenb),bc
    call    SRV_se00
    ld  hl,(bbuf2)
    ld  (bbuf),hl
    ld  hl,(lenb2)
    ld  (lenb),hl

SRV_se00:
;   ld  a,(S_C)
;   call    PUT_P2
    ld  ix,sWCB0
    ld  hl,(sWCB0+18)
    ld  bc,#C000
    xor a
    sbc hl,bc           ; if different
    jp  nz,SRV_se01 ; not out channel windows
; out chan windows
    ld  hl,(bbuf)
    ld  bc,(lenb)

SRV_se0:
    ld  a,(hl)
    push    hl
    push    bc
    call    OUTC_TW
    pop bc
    pop hl
    inc hl
    dec bc
    ld  a,b
    or  c
    jr  nz,SRV_se0

SRV_se01:

; cut buffer
    ld  bc,(lenb)
;   ld  l,(ix+12) ; start buff
;   ld  h,(ix+13) ;
    ld  hl,(sWCB0+12)
    ld  de,#9200  ; low line ********************************
    xor a
    sbc hl,bc   ; new buffer    hl = hl - (len)
    sbc hl,de   ; < #9000 ?
    jr  nc,SRV_se1 ; no overfull
    ld  hl,0    
SRV_se1 add hl,de   ; hl - dest adr
;   ld  (ix+12),l
;   ld  (ix+13),h   ; new buff
    ld  (sWCB0+12),hl
    push    hl      ; old
    add hl,bc   ; source
    ex  de, hl   
    ld  hl,#C000
    xor a
    sbc hl,de   ; hl=#C000 - source
    ld  c,l
    ld  b,h
    pop hl
    ex  de,hl   
; hl = new buf + (len) , de new buf , bc = #C000 - (new buf +(len))
    ldir

    ld  a,(T_S_C)
    ld  b,a
    ld  a,(S_C)
    cp  b
    call    z,LOAD_S
    ei

        
; load buffer
    xor a
    ld  hl,#C000
    ld  bc,(lenb)
    sbc hl,bc
    ex  de, hl
    ld  hl,(bbuf)
    ldir

;   call    LOAD_S
    ret
;-------------------------------------

SRV_contr:
    ld  ix,sWCB0
    call    CLS_TW
;   ld  l,(ix+12)
;   ld  h,(ix+13)
    ld  hl,(sWCB0+12)
SRV_ctr1:
    push    hl
    ld  a,(hl)
    call    OUTC_TW
    pop hl
    inc hl
    ld  a,h
    cp  #C0
    jr  nz,SRV_ctr1
    call    LOAD_S
    
    jp  SRVw
SRV_home:
    ld  ix,sWCB0
    ld  hl,#C000
;   ld  (ix+18),l
;   ld  (ix+19),h
    ld  (sWCB0+18),hl
    call    PPBC
    jp  SRVw
SRV_UP:
    ld  ix,sWCB0
    bit 0,(hl)  ; if 0 - SHIFT
    jp  z,SRVUPvPU ; View channel buffer UP 1 page
    bit 1,(hl)  ; if 0 - CTRL
    jp  z,SRVUPvU ; View channel buffer UP 1 string
; 
    jp  SRVw
    
SRV_DW:
    ld  ix,sWCB0
    bit 0,(hl)  ; if 0 - SHIFT
    jp  z,SRVDWvPD ; View channel buffer UP 1 page
    bit 1,(hl)  ; if 0 - CTRL
    jp  z,SRVDWvD ; View channel buffer UP 1 string
;
    jp  SRVw
SRVUPvPU:
    ld  d,(ix+5)
    jr  SRVU2
SRVUPvU:
; View channel buff UP 1 string
    ld  d,1
SRVU2:
;   ld  ix,sWCB0
;   ld  l,(ix+18)   ; buffer curs
;   ld  h,(ix+19)
    ld  hl,(sWCB0+18)
    dec hl
    dec hl
SRVU3:  ld  a,#0A
SRVU1:  cpdr
    jr  nz,SRVU1    ; 
;   ld  a,#80
;   cp  h
;       
    dec d
    jr  nz,SRVU3
    inc hl
    inc hl              ;
    ex  de,hl
;   ld  l,(ix+12)
;   ld  h,(ix+13)
    ld  hl,(sWCB0+12)
    xor a
    dec hl
    sbc hl,de   ;  hl-de=?
    jp  nc,SRVw
;   ld  (ix+18),e
;   ld  (ix+19),d
    ld  (sWCB0+18),de
    call    PPBC
    jp  SRVw

SRVDWvPD
    ld  d,(ix+5)
    jr  SRVD0
SRVDWvD:
; View channel buff Down 1 string
    ld  d,1
SRVD0:
;   ld  ix,sWCB0
;   ld  l,(ix+18)
;   ld  h,(ix+19)
    ld  hl,(sWCB0+18)
SRVD2:  ld  a,#0A
SRVD1:  cpir
    jp  nz,SRVD1
    ld  a,h
    cp  #C0
    jr  nc,SRVD3 ; out of buffer hl > #C000
    dec d
    jr  nz,SRVD2
SRVD4:
;   ld  (ix+18),l
;   ld  (ix+19),h
    ld  (sWCB0+18),hl
    call    PPBC
    jp  SRVw
SRVD3:  ld  hl,#C000 ; set cur end of buffer
    jp  SRVD4

SRV_EX:
    ld  a,(segp)
    ld  (segsel),a
    jp  SYS_S

SRV_F2:
    call    CLKB
    call    GET_P2
    ld  (segsRS),a
    ld  a,(notcpip) ; check for TCP/IP UNAPI implementation
    or  a
    jr  z,SRVF2_1
    ld  hl,NOTCPIP_S    
    call    PRINT_BF
    jp  SRVw
SRVF2_1:
                ; check for exist connect
    ld  a,(serv1c)
    or  a
    jr  z,SRVF2_2
    ld  hl,SM_CONNEXIST
    call    PRINT_BF
    jp  SRVw
SRVF2_2:            ; Attempt connect

    call    CONNECT_S


    jp  SRVw

SRV_F3:
    call    CLKB
    xor a
    call    TCP_ERROR2
    xor a
    ld  (serv1c),a
    jp  SRVw
SRV_F4:
    ld  de,tsb+4
    ld  (tsb+2),de
    ld  a,(PA_SRVPASS)
    or  a
    jr  z,SRVF4_1 ; no server password
    ld  a,"/"
    ld  (de),a
    inc de
    ld  hl,AA_SPAS
    call    COPYARG

    ld  hl,PA_SRVPASS
    call    COPYARG
    dec de
    ld  a,13
    ld  (de),a
    inc de

SRVF4_1:
    ld  a,"/"
    ld  (de),a
    inc de
    ld  hl,AA_NICK
    call    COPYARG
    
    ld  hl,PA_NICK
    call    COPYARG
    dec de
    ld  a,13
    ld  (de),a
    inc de

    ld  a,"/"
    ld  (de),a
    inc de
    ld  hl,AA_USER
    call    COPYARG

    ld  hl,PA_USER
SRVF4_3:
    ld  a,(hl)
    or  a
    jr  z,SRVF4_2
    ld  (de),a
    inc hl
    inc de
    jr  SRVF4_3

SRVF4_2:
    ld  a,13
    ld  (de),a
    inc de
    xor a
    ld  (de),a

    ld  hl,tsb+4
    ld  bc,512
    xor a
    cpir
    jp  nz,SRVw
    ld  de,tsb+4
    xor a
    dec hl
    sbc hl,de
    ld  (tsb),hl    
    jp  SRVw


LsEnCS:
;*****************************************
; Enter Server Segment
;*****************************************
        inc     hl
        ld      a,(hl)
        ld      (S_C),a
        ld      a,(segsel)
        ld      (segp),a
        jp      CHAN



;Create Channel records
;
;
CHANNEL_C:
    ld  a,"C"
    ld  de,C_CHAN
    call    SrS
    jr  c,CHANNEL_CREATE
    ret

newsload:
    ld  a,(w0new)
    or  a
    ret z
    call    LOAD_S
    xor a
    ld  (w0new),a
    ld  a,(segs)
    rla
    ld  c,a
    ld  b,0
    ld  hl,MAPTAB
    add hl,bc
    set 7,(hl)
    ret


CHANNEL_CREATE:
;***********************************************
; Channel control segment
;***********************************************
    CALL    CLAT_C_N
    xor a
    ld  (req),a

    call    ALL_REC
    ld  a,b
    ld  (segp),a
    jp  c,NO_REC
    push    hl
    ld  a,0
    ld  b,0
    call    ALL_SEG
    pop hl
    jp  c,NO_SEG
    ld  (hl),"C"
    inc hl
    ld  (hl),a
    ld  (S_C),a
    call    PUT_P2
    call    CLS_G

        ld      b,24
        ld      de,80
        ld      hl,#8000 + 80 * 2 - 16
        ld      a,22 ;134 ?     ;"!"
wi3:    ld      (hl),a
        add     hl,de
        djnz    wi3


    ld  a,(segp)
    ld  (segs),a

    ld  a,(segsRS)  ; segment parent
    ld  (segsR),a

    ld  d,0
    ld  a,(segs)
    ld  e,a
    ld  hl,#8000
    ld  b,2
    ld  c,"0"
    ld  a,0
    call    NUMTOASC
    ld  hl,#8000+3
    ld  (hl),"C"
    inc hl
    inc hl
    ld  iy,C_CHAN
    ld  b,50
CCr01:  ld  a,(iy)
    or  a
    jr  z,CCr02
    cp  " "
    jr  z,CCr02
    ld  (hl),a
    inc hl
    inc iy
    djnz    CCr01
CCr02:  ld  (hl)," "
; test block
;   ld  d,0
;   ld  a,(S_C)
;   ld  e,a
;   ld  c,"0"
;   ld  b,3
;   ld  a,0
;   inc hl
;   call    NUMTOASC

    ld  hl,WCB1     ; channel WCB template
    ld  de,sWCB0
    ld  bc,24
    ldir
    ld  ix,sWCB0
    call    CLS_TW
                ; ini windows nick's 
    ld  hl,WCB2
    ld  de,sWCB1
    ld  bc,24
    ldir
    ld  ix,sWCB1
    call    CLS_TW

                ; ini windows enter string
    ld  hl,WCB3
    ld  de,sWCB2
    ld  bc,24
    ldir
    ld  ix,sWCB2
    call    CLS_TW
                ; ini cursor
    xor a
    ld  (oldcur),a
    ld  (oldcur+1),a
;   inc a
    ld  (oldcur+2),a
                ; clear ct buffer
    ld  hl,#8A00
    ld  bc,270
wi4:    xor a
    ld  (hl),a
    inc hl
    dec bc
    ld  a,b
    or  c
    jr  nz,wi4

    call    LOAD_S
;   ini buffer for back loading

    ld  hl,#0019 ;v-25
    bios    POSIT
;   call    CLKB
    ld  a,1     ; need new nick list
    ld  (nlnew),a
    call    BFSegT      ; rebuild active segmrnt tabl
    ld  a,(S_C)
    call    PUT_P2
    or  a
    ret

;   jp  SRVw    
;======================================================================================
;   Channel control segment
;======================================================================================
CHAN:
tccw:   

    ld  bc,(tsb)
    ld  a,b
    or  c
    jr  z,tccwB
    dec bc
    ld  (tsb),bc
    ld  hl,(tsb+2)
    ld  a,(hl)
    inc hl
    ld  (tsb+2),hl
    jp  tccwC
tccwB:

    ld  a,(S_C)
    call    PUT_P2

    call    SSIA

    ld  ix,sWCB2

    ld  hl,(sWCB2+2)    ;*
    ld  d,0
    ld  e,(ix+6)
    add hl,de
    call    CURSOR
    call    LOAD_S


    

tccw0:
    call    CLOCK
    call    TCPSEP
    ld  a,(req)
    cp  1
    jp  z,CHANNEL_CREATE
    jp  SEL_RE
CHA_RE:
    call    L_SIA

;   ld  a,"c"
;   ld  (#8000+2),a
    ld  a,(w1new)
    or  a
    jr  z,CHA_RE1
    ld  ix,sWCB1
    call    NICKOS
    xor a
    ld  (w1new),a
    ld  (w0new),a
    call    LOAD_S
    jr  CHA_RE2
CHA_RE1:
    call    newsload

CHA_RE2:
    
    ld  c,_CONST
    call    DOS
    or  a
    jr  z,tccw0
    ld  c,_INNO
    call    DOS
tccwC:  ld  b,a
    ld  a,(S_C)
    call    PUT_P2
    ld  ix,sWCB2
    ld  hl,#FBEB
    ld  a,b

    bit 7,(hl)
    jp  z,tcc_F3
    bit 6,(hl)
    jp  z,tcc_F2
    bit 5,(hl)
    jp  z,Ls_help
    cp  #0D
    jp  z,tcc_se
    cp  ESC_
    jp  z,tcc_ESC
    cp  11  ; CLS/HOME cancel view buffer chancel
    jp  z,tcc_home
    cp  UP_
    jp  z,tcc_UP
    cp  DOWN_
    jp  z,tcc_DW
    
    cp  24  ; SELECT
    jp  z,tcc_F2
;   jp  z,tcc_contr
    bit 1,(hl)
    jr  nz,tccWNC
    cp  17  ;CTRL+Q
    jp  z,tcc_Q 
tccWNC:
; edit enter string
    cp  8 ; "BS" <-
    jp  z,tcc_bs
    cp  18 ; INS
    jp  z,tcc_ins
    cp  127 ; DEL
    jp  z,tcc_del   
    cp  LEFT_
    jp  z,tcc_left
    cp  RIGHT_
    jp  z,tcc_right

; regular char
    ex  af,af'
    ld  a,(s_ins)
    or  a
    jr  z,tcc_r4    ; no insret option
    ld  hl,(sWCB2+16) ;*
    ld  e,l
    ld  d,h
    dec hl
    ld  bc,(sWCB2+18)
    xor a
    sbc hl,bc
    jr  c,tcc_r4    ; no right part string
    inc hl
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    inc de
    ld  (sWCB2+16),de
    inc bc
    lddr                ; scroll 
tcc_r4: ex  af,af'
; save cahr to buff
    ld  hl,(sWCB2+18)
    ld  (hl),a
    inc hl
    ld  (sWCB2+18),hl
    ld  de,(sWCB2+16)
    xor a
    sbc hl,de
    jr  c,tcc_r3
    inc de
    ld  (sWCB2+16),de

tcc_r3:
;
    ld  a,(ix+6)
    ld  b,(ix+4)
    dec b
    cp  b           ; screen cursor end positoin ?
    jr  nc,tcc_r1   ; y
    inc a           ; no, inc h-cur
    ld  (ix+6),a
    jr  tcc_r2
tcc_r1: 
    ld  hl,(sWCB2+22)
    inc hl
    ld  (sWCB2+22),hl
tcc_r2:

    call    OUTSTRW
;   call    OUTC_TW
    jp  tccw
tcc_ins
    ld  a,(s_ins)
    cpl 
    ld  (s_ins),a
    jp  tccw
tcc_left:
    bit 1,(hl)
    jp  z,S_LEFT
    ld  de,(sWCB2+18)
    ld  hl,(sWCB2+12)
    xor a   
    sbc hl,de   ; |<- X
    jp  nc,tccw ; no LEFT
    dec de
    ld  (sWCB2+18),de
; LEFT
        dec (ix+6)   ; c_cur --
    jp  p,tccL1  ; > 0 norm
    inc (ix+6)   ; c_cur ++     
    ld  (sWCB2+22),de
tccL1:  
    
    call    OUTSTRW
    jp  tccw

tcc_right:
    bit 1,(hl)
    jp  z,S_RIGHT
    ld  de,(sWCB2+18)
    ld  hl,(sWCB2+16)
    inc de
    xor a
    sbc hl,de
    jp  c,tccw    ; ->| X
    ld  (sWCB2+18),de
    ld  b,(ix+4)   ; H-size
    ld  a,(ix+6)   ; h_cur
    inc a
    cp  b
    jp  nc,tcc_R1
    ld  (ix+6),a
    jr  tcc_R2
tcc_R1:
    ld  hl,(sWCB2+22)
    inc hl
    ld  (sWCB2+22),hl

tcc_R2: call    OUTSTRW
    jp  tccw
tcc_del:
    ld  hl,(sWCB2+18) ; b_cur
    ld  de,(sWCB2+16)

    dec de
    xor a
    sbc hl,de
    jr  c,tcc_del1   ; -1
    jp  nz,tccw      ; 1
tcc_del1
    ld  (sWCB2+16),de
    jr  z,tcc_del2   ; 0
; scroll right part string
    inc     de
    xor a
    add hl,de   
            ; hl = b_cur  de = b_end-1 old
    ex  de,hl   ; hl = b_end new de = B_cur
    sbc hl,de   ; 
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    dec hl
    inc bc
    ex  de,hl  ;
    ldir           


tcc_del2:
        call    OUTSTRW
    jp  tccw
; "back space" delete last symlol hposit --
tcc_bs:
    ld  hl,(sWCB2+12)
    ld  de,(sWCB2+18) ;cur
    xor a
    sbc hl,de     ; |<- X
    jp  nc,tccw   ; no BS
    dec de
    ld  (sWCB2+18),de
; bs        
        dec (ix+6)   ; c_cur --
    jp  p,tccbs1  ; > 0 norm
    inc (ix+6)   ; c_cur ++     
    ld  (sWCB2+23),de   ; then  (stout) := (cur)
tccbs1: 
;scroll right part strint to left on 1 byte
    ld  hl,(sWCB2+16)   ; end buff
    dec hl              ; endbuff--
    ld  (sWCB2+16),hl
    xor a
    sbc hl,de
    ld  a,h
    or  l
    jr  z,tccbs2
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    inc hl
    ldir

tccbs2: 
    call    OUTSTRW
    jp  tccw

tcc_se:
;
    call    CLS_TW     ; clear enter string of screen
    xor a
    ld  (ix+6),a
    ld  (ix+7),a
    ld  hl,(sWCB2+16)
    ld  (hl),#0D
    inc hl
    ld  (hl),#0A
    inc hl     ; curs
    ld  de,(sWCB2+12) ; buff
    ld  (sWCB2+18),de ; curs
    ld  (sWCB2+22),de
    ld  (bbuf),de  ;
    xor a
    sbc hl,de
    ld  (lenb),hl  ;        
    ld  (sWCB2+16),de ; buffe
    call    BuffOU
    jp  tccw    
; 
; 
;
tcc_contr:
    ld  ix,sWCB0
    call    CLS_TW
;   ld  l,(ix+12)
;   ld  h,(ix+13)
    ld  hl,(sWCB0+12)
tcc_ctr1:
    push    hl
    ld  a,(hl)
    call    OUTC_TW
    pop hl
    inc hl
    ld  a,h
    cp  #C0
    jr  nz,tcc_ctr1
    call    LOAD_S
    
    jp  tccw
tcc_home:
    ld  ix,sWCB0
    ld  hl,#C000
;   ld  (ix+18),l
;   ld  (ix+19),h
    ld  (sWCB0+18),hl
    call    PPBC
    jp  tccw
tcc_UP:
    ld  ix,sWCB0
    bit 0,(hl)  ; if 0 - SHIFT
    jp  z,tccUPvPU ; View channel buffer UP 1 page
    bit 1,(hl)  ; if 0 - CTRL
    jp  z,tccUPvU ; View channel buffer UP 1 string
; 
    jp  tccw
    
tcc_DW:
    ld  ix,sWCB0
    bit 0,(hl)  ; if 0 - SHIFT
    jp  z,tccDWvPD ; View channel buffer UP 1 page
    bit 1,(hl)  ; if 0 - CTRL
    jp  z,tccDWvD ; View channel buffer UP 1 string
;
    jp  tccw
tccUPvPU:
    ld  d,(ix+5)
    jr  tccU2
tccUPvU:
; View channel buff UP 1 string
    ld  d,1
tccU2:
;   ld  ix,sWCB0
;   ld  l,(ix+18)   ; buffer curs
;   ld  h,(ix+19)
    ld  hl,(sWCB0+18)
    dec hl
    dec hl
tccU3:  ld  a,#0A
tccU1:  cpdr
    jr  nz,tccU1    ; 
;   ld  a,#80
;   cp  h
;       
    dec d
    jr  nz,tccU3
    inc hl
    inc hl              ;
    ex  de,hl
;   ld  l,(ix+12)
;   ld  h,(ix+13)
    ld  hl,(sWCB0+12)
    xor a
    dec hl
    sbc hl,de   ;  hl-de=?
    jp  nc,tccw
;   ld  (ix+18),e
;   ld  (ix+19),d
    ld  (sWCB0+18),de
    call    PPBC
    jp  tccw

tccDWvPD
    ld  d,(ix+5)
    jr  tccD0
tccDWvD:
; View channel buff Down 1 string
    ld  d,1
tccD0:
;   ld  ix,sWCB0
;   ld  l,(ix+18)
;   ld  h,(ix+19)
    ld  hl,(sWCB0+18)
tccD2:  ld  a,#0A
tccD1:  cpir
    jp  nz,tccD1
    ld  a,h
    cp  #C0
    jr  nc,tccD3 ; out of buffer hl > #C000
    dec d
    jr  nz,tccD2
tccD4:
;   ld  (ix+18),l
;   ld  (ix+19),h
    ld  (sWCB0+18),hl
    call    PPBC
    jp  tccw
tccD3:  ld  hl,#C000 ; set cur end of buffer
    jp  tccD4

tcc_ESC:
    ld  a,(segp)
    ld  (segsel),a
    jp  SYS_S

tcc_F2:
;   Select Nick -> Select Nick operation
;
    call    CLKB
    ld  a,(S_C)
    call    PUT_P2
    ld      ix,sWCB1    ;nicks windows

; test for nicks empty
    ld  a,(ix+23)
    or  a
    jp  z,tccw

;   stop chanel out on screen
    xor a
    ld  (stopC),a
; cursor on
    ld  a,(ix+10)
    or  a
    jr  nz,nks0
    ld  b,(ix+5)
    cp  b
    jr  c,nks0
    ld  a,1
    ld  (ix+10),a ; n_cur =1
nks0:


; *
; 

nicks1:


; draw nick's box on channel win
    ld  hl,29+80+#8000
    ld  (hl),24
    inc hl
    ld  b,32
    ld  a,23
nks1    ld  (hl),a
    inc hl
    djnz    nks1
;   inc hl
    ld  (hl),25
    ld  hl,29+80*2+#8000
    ld  (hl),22
    ld  hl,62+80*2+#8000
    ld  (hl),22
    ld  hl,29+80*3+#8000
    ld  (hl),26
    inc hl
    ld  b,32
nks2    ld  (hl),a
    inc hl
    djnz    nks2
;   inc hl
    ld  (hl),27

nks_f:      
; clear atribytes
    call    CLAT_C_N
; 
    call    NICKOS  

nks4:
; draw nick cursor (atrib)
    call    SETAT_N 
    call    LOAD_SA ; ***************************** ubr
;   call    LOAD_S  ; ***
; out full nickname to nickname box
    ld  a,(ix+22)
    add a,(ix+10)   ; a - npos nick in buffer
    or  a
    jr  z,nks8  ; no curs
;   inc a
    ld  d,a
    ld  bc,#300 ; **
    ld  a," "
;   ld  l,(ix+12)
;   ld  h,(ix+13)
    ld  hl,(sWCB1+12)
nks6_:  dec d
    jr  z,nks5
    cpir
    jr  nks6_
nks5:   ; hl - fineded nick in buff
    dec hl
    ld  de,30+80*2+#8000 ; 
    ld  b,32         ; max nick lenght
    ld  c," "
nks6:   inc hl
    ld  a,(hl)
    cp  "@"
    jr  z,nks6
    cp  "%"
    jr  z,nks6
    cp  "+"
    jr  z,nks6
    cp  c   ; " "
    jr  z,nks7
    cp  0
    jr  z,nks7
    ex  de,hl
    ld  (hl),a
    inc hl
    ex  de,hl
    dec b
    jr  z,nks8
    jr  nks6
nks7:   ex  de,hl
nks9:   ld  (hl),c
    inc hl
    djnz    nks9
nks8:   ; transfer nick complete

    call    LOAD_S
;


nks10:
; input block
    call    CLOCK   
    call    TCPSEP
    ld  c,_CONST
    call    DOS
    or  a
    jp  z,nks10
    ld  c,_INNO
    call    DOS
    ld  b,a
    ld  a,(S_C)
    call    PUT_P2
    ld  ix,sWCB1    ; nick WCB
    ld  hl,#FBEB
    ld  a,b
;   bit 7,(hl)

    cp  UP_
    jp  z,nks_UP
    cp  DOWN_
    jp  z,nks_DW
    cp  LEFT_
    
    cp  RIGHT_

    cp  #0D
    jp  z,nks_ent
    
    cp  27
    jp  z,nks_end

    jp  nks10 ; **

nks_end:
    call    CLAT_C_N
    call    PPBC
    jp  tccw
; enter select nickname to channel send buffer
nks_ent:
    ld  hl,30+80*2+#8000 ; full nick name of screen
    ld  b,32         ; max nickname length
    ld  de,tsb+4         ; send buffer pointer
    ld  (tsb+2),de
    ld  iy,0         ; counter ini
nksent1:
    ld  a,(hl)  
    cp  " "
    jp  z,nks_end
    dec b
    jp  z,nks_end
    inc iy

    ld  (tsb),iy
    ex  de,hl
    ld  (hl),a
    ex  de,hl
    inc de
    inc hl
    jp  nksent1

nks_UP:
    ld  a,(ix+10)
    or  a       ; curs off
    jp  z,nks10 ; **
    dec a
    jp  z,nksUP1    ; top screen
    ld  (ix+10),a
    jp  nks_f
nksUP1: ld  a,(ix+22)
    or  a       ; top n_buff
    jp  z,nks10 ; **
    dec a       ; scroll 
    ld  (ix+22),a
    jp  nks_f
nks_DW:
    ld  a,(ix+10)   ; curs
    ld  d,a
    ld  c,(ix+22)   ; shift 
    ld  b,(ix+23)   ; nick count
    add a,c
    cp  b
    jp  nc,nks10 ; **
    ld  a,d
    or  a       ; curs off
    jp  z,nks10 ; ** 
    ld  b,(ix+5)    ; v size
    cp  b
    jp  nc,nksDW1
    inc a
    ld  (ix+10),a
    jp  nks_f
nksDW1: inc     c   
    ld  (ix+22),c
    jp  nks_f
    

tcc_F3:
; Test F3 load nick windows
;tnicks 

    ld      ix,sWCB1    ;nicks windows
    ld  hl,tnicks
    ld  bc,200
    xor a
    otir            ; Search #00
;   inc hl
    ld  de,tnicks
    xor a
    sbc hl,de
    ld  c,l
    ld  b,h

    ld  bc,tnickse-tnicks   ;******
    ex  de,hl
    ld  e,(ix+12)
    ld  d,(ix+13)
    ldir            ; load nick buffer- de, from hl, bc- length
    ld  (ix+16),e   ; save end buffer
    ld  (ix+17),d

;   jp  clcn2   ; *********************
    
; calc Nicks counter
;
    ld  e,(ix+12) ; buff
    ld  d,(ix+13)
    ld  l,(ix+16) ; b_end
    ld  h,(ix+17)
    xor a
    sbc hl,de
    ld  c,l
    ld  b,h
    ex  de,hl
    ld  d,a ;0
    ld  a," "
clcn1_: cpir
    jp  po,clcn2 ; ************************* jp pe ???
;   inc hl ****
    inc d
    jr  clcn1_
clcn2:  ; d - nick's is counted

;   ld  d,12 ****
    ld  (ix+23),d
    xor a
    ld  (ix+22),0
    inc a
    ld  (ix+10),a
    call    NICKOS
    call    LOAD_S  ; *****


;tccF3_0:
;   ld  a,(hl)
;   cp  0
;   jr  z,tccF3_1
;   
;   cp  " "
;   jr  z,tccF3n
;   push    hl
;tccF3_2    call    OUTC_TW
;   pop hl
;   inc hl
;   jr  tccF3_0
;tccF3n:
;   push    hl
;   ld  a,#0D
;   call    OUTC_TW
;   ld  a,#0A
;   jr  tccF3_2 
;
    call    LOAD_S
    ei
;   clear kbd_buffer


    call    CLKB
    jp  tccw
; quit channel - part #channel , close channel
tcc_Q:
; part
    call    TCP_PARTC

; close
    ld  a,(segp)
    call    FRE_RECS
    call    BFSegT
;   ld  a,(ix+16)
;   or  a
;   jp  z,SYS_S
    jp  S_LEFT;

;
; nick out of screen
; sWCB1 (nick windows) IX+22 - begin out 
; ix+22 start nick N
; ix+23 - counter nick
NICKOS:
    call    CLS_TW
    xor a
    ld  (ix+6),a
    ld  (ix+7),a
;   ld  e,(ix+12) ; buff
;   ld  d,(ix+13)
    ld  de,(sWCB1+12)
;   ld  l,(ix+16) ; b_end
;   ld  h,(ix+17)
    ld  hl,(sWCB1+16)
    xor a
    sbc hl,de
    ld  c,l
    ld  b,h
    ex  de,hl
    ld  d,(ix+22) ; n - nick
    inc d
    ld  a," "
niko01: dec d
    jr  z,niko02
    cpir
    ret     po
    jr  niko01
niko02:
;   ld  ix,sWCB1
nicko1: ld  a,(hl)
    or  a
    ret z
    cp  " "
    jr  z,nicko3
    push    hl
nicko2: call    OUTC_TW
    pop hl
    inc hl
    jr  nicko1
nicko3: push    hl
    ld  a,#0D
    call    OUTC_TW
    ld  a,#0A
    jr  nicko2  
;**************************************************************************
LsEnQS:
;*******************************************
; Enter Query Segment
;*******************************************
    inc hl
    ld  a,(hl)
    ld  (S_C),a
    ld  a,(segsel)
    ld  (segp),a
    jp  QUEC

; Create Query record (Query segment)
QUERY_C:
; test on exist some query
; Find query segment
    ld  a,"Q"
    ld  de,PA_QNICK
    call    SrS
    jr  c,QUE_NOq
;   ld  (S_C),a
    ret 
QUE_NOq:
    call    CLAT_C_N
;
    call    ALL_REC
    ld  a,b
    ld  (segp),a
    jp  c,NO_REC_M
    push    hl
    ld  a,0
    ld  b,0
    call    ALL_SEG
    pop hl
    jp  c,NO_SEG_M
; set record Q status
    ld  (hl),"Q"
    inc hl
; set segment mapper
    ld  (hl),a
; INI Query control segment
    ld  (S_C),a
    call    PUT_P2
    call    CLS_G
    ld  a,(segp)
    ld  (segs),a
    ld  d,0
    ld  a,(segs)
    ld  e,a
    ld  hl,#8000
    ld  b,2
    ld  c,"0"
    ld  a,0
    call    NUMTOASC
    ld  hl,#8000+3
    ld  (hl),"Q"    ; "Q" descriptor
    inc hl
    inc hl
; query nickname    
    ld  de,PA_QNICK
    ld  b,30
QUE_2:  ld  a,(de)
    or  a
    jr  z,QUE_1
    cp  " "
    jr  z,QUE_1
    ld  (hl),a
    inc hl
    inc de
    djnz    QUE_2
QUE_1:  ld  (hl)," "

; test block
;                        ; print # map segment
;        ld      d,0
;        ld      a,(S_C)
;        ld      e,a
;        ld      c,"0"
;        ld      b,3
;        ld      a,0
;        inc     hl
;        call    NUMTOASC
;       not realise ?
; end test, block


        ld      hl,WCB01        ; server WCB template
        ld      de,sWCB0
        ld      bc,24
        ldir
        ld      ix,sWCB0
        call    CLS_TW
;                               ini windows enter string
        ld      hl,WCB3
        ld      de,sWCB2
        ld      bc,24
        ldir
        ld      ix,sWCB2
        call    CLS_TW
    
; ini cursor
        xor     a
        ld      (oldcur),a
        ld      (oldcur+1),a
;       inc     a
        ld      (oldcur+2),a
; clear ct buffer
        ld      hl,#8A00
        ld      bc,270
QUE_4:   xor     a
        ld      (hl),a
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,QUE_4

        call    LOAD_S
    ei
;       ini buffer for back loading

        ld      hl,#0019 ;v-25
        bios    POSIT
        call    CLKB
        call    BFSegT          ; rebuild active segmrnt tabl
    ld  a,(S_C)
    call    PUT_P2
    or  a
    ret
;**************************************************************************
QUEC:
QUEw:
        ld      a,(S_C)
        call    PUT_P2
        call    SSIA

        ld      ix,sWCB2

        ld      hl,(sWCB2+2)    ;*
        ld      d,0
        ld      e,(ix+6)
        add     hl,de
        call    CURSOR
        call    LOAD_S

QUEC0:              ; macros auto
    ld  bc,(tsb)
    ld  a,b
    or  c
    jr  z,QUECB
    dec bc
    ld  (tsb),bc
    ld  hl,(tsb+2)
    ld  a,(hl)
    inc hl
    ld  (tsb+2),hl
    jp  QUECC
QUECB:
    call    CLOCK
    call    TCPSEP
    ld  a,(req)
    cp  1
    jp  z,CHANNEL_CREATE    ;CHANNEL_CREATE

    jp  SEL_RE
QUE_RE:
    call    L_SIA
;   ld  a,"q"
;   ld  (#8000+2),a
    
    call    newsload

;   ld  a,(w0new)
;   or  a
;   call    nz,LOAD_S
;   xor a
;   ld  (w0new),a

            ; keyboard input
    ld  c,_CONST
    call    DOS
    or  a
    jr  z,QUEC0
    ld  c,_INNO
    call    DOS
QUECC:
    ld  b,a
    ld  a,(S_C)
    call    PUT_P2
    ld  ix,sWCB2
    ld  hl,#FBEB
    ld  a,b

    bit 7,(hl)
;   jp  z,QUE_F3
    bit 6,(hl)
;   jp  z,QUE_F2
    bit 5,(hl)
    jp  z,Ls_help
    cp  #0D
    jp  z,QUE_se
    cp  ESC_
    jp  z,QUE_EX
    cp  11  ; CLS/HOME cancel view buffer chancel
    jp  z,QUE_home
    cp  UP_
    jp  z,QUE_UP
    cp  DOWN_
    jp  z,QUE_DW
    cp  17  ;CTRL+Q
    jp  z,QUE_Q
    
;   cp  24  ; SELECT
;   jp  z,QUE_contr

; edit enter string
    cp  8 ; "BS" <-
    jp  z,QUE_bs
    cp  18 ; INS
    jp  z,QUE_ins
    cp  127 ; DEL
    jp  z,QUE_del   
    cp  LEFT_
    jp  z,QUE_left
    cp  RIGHT_
    jp  z,QUE_right

; regular char  
    ex  af,af'
    ld  a,(s_ins)
    or  a
    jr  z,QUE_r4    ; no insret option
    ld  hl,(sWCB2+16) ;*
    ld  e,l
    ld  d,h
    dec hl
    ld  bc,(sWCB2+18)
    xor a
    sbc hl,bc
    jr  c,QUE_r4    ; no right part string
    inc hl
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    inc de
    ld  (sWCB2+16),de
    inc bc
    lddr                ; scroll 
QUE_r4: ex  af,af'
; save cahr to buff
    ld  hl,(sWCB2+18)
    ld  (hl),a
    inc hl
    ld  (sWCB2+18),hl
    ld  de,(sWCB2+16)
    xor a
    sbc hl,de
    jr  c,QUE_r3
    inc de
    ld  (sWCB2+16),de
QUE_r3: ld  a,(ix+6)
    ld  b,(ix+4)
    dec b
    cp  b           ; screen cursor end positoin ?
    jr  nc,QUE_r1   ; y
    inc a           ; no, inc h-cur
    ld  (ix+6),a
    jr  QUE_r2
QUE_r1: 
    ld  hl,(sWCB2+22)
    inc hl
    ld  (sWCB2+22),hl
QUE_r2:

    call    OUTSTRW
    jp  QUEw
QUE_ins
    ld  a,(s_ins)
    cpl 
    ld  (s_ins),a
    jp  QUEw
QUE_left:
    bit 1,(hl)
    jp  z,S_LEFT
    ld  de,(sWCB2+18)
    ld  hl,(sWCB2+12)
    xor a   
    sbc hl,de   ; |<- X
    jp  nc,QUEw ; no LEFT
    dec de
    ld  (sWCB2+18),de
; LEFT
        dec (ix+6)   ; c_cur --
    jp  p,QUEL1  ; > 0 norm
    inc (ix+6)   ; c_cur ++     
    ld  (sWCB2+22),de
QUEL1:  
    
    call    OUTSTRW
    jp  QUEw

QUE_right:
    bit 1,(hl)
    jp  z,S_RIGHT
    ld  de,(sWCB2+18)
    ld  hl,(sWCB2+16)
    inc de
    xor a
    sbc hl,de
    jp  c,QUEw    ; ->| X
    ld  (sWCB2+18),de
    ld  b,(ix+4)   ; H-size
    ld  a,(ix+6)   ; h_cur
    inc a
    cp  b
    jp  nc,QUE_R1
    ld  (ix+6),a
    jr  QUE_R2
QUE_R1: ld  hl,(sWCB2+22)
    inc hl
    ld  (sWCB2+22),hl

QUE_R2: call    OUTSTRW
    jp  QUEw
QUE_del:
    ld  hl,(sWCB2+18)
    ld  de,(sWCB2+16)
    dec de
    xor a
    sbc hl,de
    jr  c,QUE_del1   ; -1
    jp  nz,QUEw      ; 1
QUE_del1:
    ld  (sWCB2+16),de
    jr  z,QUE_del2   ; 0
; scroll right part string
    inc     de
    xor a
    add hl,de   
            ; hl = b_cur  de = b_end-1 old
    ex  de,hl   ; hl = b_end new de = B_cur
    sbc hl,de   ; 
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    dec hl
    inc bc
    ex  de,hl  ;
    ldir           
QUE_del2:
        call    OUTSTRW
    jp  QUEw
; "back space" delete last symlol hposit --
QUE_bs:
    ld  hl,(sWCB2+12)
    ld  de,(sWCB2+18)
    xor a
    sbc hl,de     ; |<- X
    jp  nc,QUEw   ; no BS
    dec de
    ld  (sWCB2+18),de

; bs        
        dec (ix+6)   ; c_cur --
    jp  p,QUEbs1  ; > 0 norm
    inc (ix+6)   ; c_cur ++     
    ld  (sWCB2+23),de
QUEbs1: 
;scroll right part strint to left on 1 byte
    ld  hl,(sWCB2+16)
    dec hl              ; endbuff--
    ld  (sWCB2+16),hl
    xor a
    sbc hl,de
    ld  a,h
    or  l
    jr  z,QUEbs2
    ld  c,l
    ld  b,h
    ld  l,e
    ld  h,d
    inc hl
    ldir

QUEbs2: 
    call    OUTSTRW
    jp  QUEw

QUE_se:
;
    call    CLS_TW     ; clear enter string of screen
    xor a
    ld  (ix+6),a
    ld  (ix+7),a
    ld  hl,(sWCB2+16)
    ld  (hl),#0D
    inc hl
    ld  (hl),#0A
    inc hl     ; curs
    ld  de,(sWCB2+12)
    ld  (sWCB2+18),de
    ld  (sWCB2+22),de
    ld  (bbuf),de  ;
    xor a
    sbc hl,de
    ld  (lenb),hl  ;        
    ld  (sWCB2+16),de
    call BuffOU
    jp  QUEw    

QUE_contr:
    ld  ix,sWCB0
    call    CLS_TW
    ld  hl,(sWCB0+12)
QUE_ctr1:
    push    hl
    ld  a,(hl)
    call    OUTC_TW
    pop hl
    inc hl
    ld  a,h
    cp  #C0
    jr  nz,QUE_ctr1
    call    LOAD_S
    
    jp  QUEw
QUE_home:
    ld  ix,sWCB0
    ld  hl,#C000
    ld  (sWCB0+18),hl
    call    PPBC
    jp  QUEw
QUE_UP:
    ld  ix,sWCB0
    bit 0,(hl)  ; if 0 - SHIFT
    jp  z,QUEUPvPU ; View channel buffer UP 1 page
    bit 1,(hl)  ; if 0 - CTRL
    jp  z,QUEUPvU ; View channel buffer UP 1 string
; 
    jp  QUEw
    
QUE_DW:
    ld  ix,sWCB0
    bit 0,(hl)  ; if 0 - SHIFT
    jp  z,QUEDWvPD ; View channel buffer UP 1 page
    bit 1,(hl)  ; if 0 - CTRL
    jp  z,QUEDWvD ; View channel buffer UP 1 string
;
    jp  QUEw
QUEUPvPU:
    ld  d,(ix+5)
    jr  QUEU2
QUEUPvU:
; View channel buff UP 1 string
    ld  d,1
QUEU2:
    ld  hl,(sWCB0+18)
    dec hl
    dec hl
QUEU3:  ld  a,#0A
QUEU1:  cpdr
    jr  nz,QUEU1    ; 
    dec d
    jr  nz,QUEU3
    inc hl
    inc hl              ;
    ex  de,hl
    ld  hl,(sWCB0+12)
    xor a
    dec hl
    sbc hl,de   ;  hl-de=?
    jp  nc,QUEw
    ld  (sWCB0+18),de
    call    PPBC
    jp  QUEw

QUEDWvPD
    ld  d,(ix+5)
    jr  QUED0
QUEDWvD:
; View channel buff Down 1 string
    ld  d,1
QUED0:
    ld  hl,(sWCB0+18)
QUED2:  ld  a,#0A
QUED1:  cpir
    jp  nz,QUED1
    ld  a,h
    cp  #C0
    jr  nc,QUED3 ; out of buffer hl > #C000
    dec d
    jr  nz,QUED2
QUED4:
    ld  (sWCB0+18),hl
    call    PPBC
    jp  QUEw
QUED3:  ld  hl,#C000 ; set cur end of buffer
    jp  QUED4

QUE_EX:
    ld  a,(segp)
    ld  (segsel),a
    jp  SYS_S
QUE_Q:  ;close record
    ld  a,(segp)
    call    FRE_RECS
    call    BFSegT
;   ld  a,(ix+16)
;   or  a
;   jp  z,SYS_S
    jp  S_LEFT;
SEL_RE:
    ld  a,(#8000+3)
    cp  "Q"
    JP  Z,QUE_RE
    cp  "C"
    jp  z,CHA_RE
    cp  "S"
    jp  z,SRV_RE
    cp  "H"
    jp  z,HLP_RE
    jp  SYS_S


;**************************************************************************
FRE_RECS:
; Freeing record & freeing segment 
; a - num record
    ld  c,a
    ld  a,79
    cp  c
    ret c
    rl  c
    ld  b,0
    ld  hl,MAPTAB
    add hl,bc
    xor a
    ld  (hl),a
    inc hl
    ld  a,(hl)
    jp  FRE_SEG


; Allocaton recod segment
; input - none
; output B - recod, HL - enter recod Table (HL) - status (HL+1) - segment (data empty!)
ALL_REC:
    ld  hl,MAPTAB
    ld  b,0
ALL_r1: ld  a,(hl)
    or  a
    ret z
    inc b
    inc hl
    inc hl
    ld  a,79
    cp  b   
    ret c
    jr  ALL_r1

NO_REC:
    ld  hl,SM_NOREC
    call    PRINT_TW
    jp  SYS_S
NO_SEG:
    ld  hl,SM_NOSEG
    call    PRINT_TW
    jp  SYS_S
NO_SERV:
    ld  hl,SM_NOSERV
    call    PRINT_TW
    jp  SYS_S
NO_REC_M:
    ld  hl,SM_NOREC
    jp  PRINT_TW

NO_SEG_M:
    ld  hl,SM_NOSEG
    jp  PRINT_TW

; Find segment
; input   a  - descriptor ("H"/"S"/"C"/"Q")
;     de - string name "..."
; output  a  - mapper segment
;     (hl) - mapper segment
;     CF - set if not found 
;     set P2 page to find segment
SrS:    ld  c,a
    ld  hl,MAPTAB
    ld  b,80
SrS2:   ld  a,(hl)
    and %01111111   
    cp  c
    jr  z,SrS1
    inc hl
    inc hl
    dec b
    jr  nz,SrS2
    scf
    ret
SrS1:   
;   ld  c,a 
    call    GET_P2
    ld  (tsegt),a
    inc hl
    ld  a,(hl)
    call    PUT_P2
    push    hl
    push    de
    ld  hl,#8005
    call    STRCMPSP
    pop de
    pop hl
    jr  z,SrS3
    ld  a,(tsegt)
    call    PUT_P2
    inc hl
    ld  a,c
    jr  SrS2
SrS3:
;   ld  a,(tsegt)
;   call    PUT_P2
    ld  a,(hl)
    ret





;--- STRCMPSP: Compares two strings
;    Input: HL, DE = Strings
;    Output: Z if strings are equal

STRCMPSP:
    ld  a,(de)
    cp  (hl)
    ret nz
    or  a
    ret z
    cp  " "
    ret z
    inc hl
    inc de
    jr  STRCMPSP







EXIT:
    bios    INITXT
    ld  c,_TERM0
    jp  DOS


TERMINFO:
    print   INFO_S
    ld  c,_TERM0
    jp  DOS

    ret

; TCP/IP subroutine
;******************************
;* Main TCP/IP Routines
;******************************

CONNECT_S:
; Attemp to connect server

    ;--- Obtains server name 

;---
;   jr  EE5
    ld  a,1
    ld  de,HOST_NAME
    call    EXTPAR
;---
    jp      nc,EE6
    ld  hl,PA_SERVER
    ld  de,HOST_NAME
EE7:    ld  a,(hl)
    ld  (de),a
    inc hl
    inc de
    or  a
    jr  nz,EE7  
EE6:
;   ld  de,HOST_NAME
;   call    CONOUTS
    ld  hl,HOST_NAME
    call    PRINT_BF

    ;--- Obtains remote port 

;   ld  a,2
;   ld  de,BUFFER
;   call    EXTPAR
;   jp  c,MISSPAR   ;Error if the parameter is missing
;       jr  nc,EE9
    ld  hl,PA_PORT
    ld  de,BUFFER
EE8:    ld  a,(hl)
    ld  (de),a
    inc hl
    inc de
    or  a
    jr  nz,EE8  
EE9:
;   ld  de,BUFFER
;   call    CONOUTS
    ld  hl,BUFFER
    call    PRINT_BF

EE5:
;   ld  hl,HOST_PORT ;BUFFER
    ld  hl,BUFFER
    call    EXTNUM16
    jp  c,INVPAR    ;Error if not a valid number

    ld  (PORT_REMOTE),bc

    ;--- Obtains other parameters, if any
    ;    (local port and passive connection)

;   ld  a,3 ;Param number to be extracted
;LASTPARAMS:    ld  ixh,a
;   ld  de,BUFFER
;   call    EXTPAR
;   jr  c,NOMOREPARS    ;The parameter is present?
;
;   ld  a,(BUFFER)  ;If the first character of the parameter
;   or  %00100000   ;is "P" or "p", set passive open...
;   cp  "p"
;   jr  nz,NO_PASSIVE
;   ld  a,1
;   ld  (PASSIVE_OPEN),a
;   jr  LASTPAR_NEXT
;NO_PASSIVE:
;
;   ld  hl,BUFFER   ;...otherwise, if it is a number, set
;   call    EXTNUM16    ;local port; otherwise, it is an
;   jp  c,INVPAR    ;invalid parameter.
;   ld  (PORT_LOCAL),bc
;
;LASTPAR_NEXT   ld  a,ixh
;   inc a
;   cp  5   ;Extracts params 3 and 4 only
;   jr  c,LASTPARAMS
NOMOREPARS: ;

    ;--- If we are in DOS 2, set the abort exit routine

;   ld  a,(DOS2)
;   or  a
;   ld  de,CLOSE_END    ;From now on, pressing CTRL-C
;   ld  c,_DEFAB    ;has te same effect of pressing CTRL-ESC
;   call    nz,DOS      ;(aborts the TCP connection and terminates program)


    ;------------------------------------------------------------
    ;---  Host name resolution and TCP connection initiation  ---
    ;------------------------------------------------------------

    ;>>> Resolve host name

;   print   RESOLVING_S
    ld  hl,RESOLVING_S
    call    PRINT_BF

;   call    SET_UNAPI
    ld  hl,HOST_NAME
    ld  b,0
    ld  a,TCPIP_DNS_Q
    call    CALL_U  ;Query the resolver...
    
    ld  b,a ;...and check for an error
    ld  ix,DNSQERRS_T
    or  a
    jr  nz,DNSQR_ERR

    ;* Wait for the query to finish

DNSQ_WAIT:
    ld  a,TCPIP_WAIT
    call    CALL_U
    call    CHECK_KEY   ;To allow process abort with CTRL-C
;   call    SET_UNAPI
    ld  b,1
    ld  a,TCPIP_DNS_S
    call    CALL_U

    ;* Error?

    or  a
    ld  ix,DNSRERRS_T
    jr  nz,DNSQR_ERR

    ;* The request continues? Then go back to the waiting loop

    ld  a,b
    cp  2
    jr  nz,DNSQ_WAIT    ;The request has not finished yet?

    ;* Request finished? Store and display result, and continue

    ld  (IP_REMOTE),hl  ;Stores the returned result (L.H.E.D)
    ld  (IP_REMOTE+2),de

    ld  ix,RESOLVIP_S   ;Displays the result
    ld  a,"$"
    call    IP_STRING
;   print   RESOLVOK_S
;   print   TWO_NL_S
    ld  hl,RESOLVOK_S
    call    PRINT_BF
    ld  hl,TWO_NL_S
    call    PRINT_BF

    jp  RESOLV_OK   ;Continues

    ;- Error routine for DNS_Q and DNS_S
    ;  Input: B=Error code, IX=Errors table

DNSQR_ERR:  push    ix
        push    bc

    ;* Prints "ERROR <code>: "

    ld  ix,RESOLVERRC_S
    ld  a,b
    call    BYTE2ASC
    ld  (ix),":"
    ld  (ix+1)," "
    ld  (ix+2),"$"
;   print   RESOLVERR_S
    ld  hl,RESOLVERR_S
    call    PRINT_BF

    ;* Obtains the error code, display it and finish

    pop bc
    pop de
    call    GET_STRING
;   ld  c,_STROUT
;   call    DOS
    ex  de,hl
    call    PRINT_BF

;   jp  TERMINATE
    ret 

RESOLV_OK:  ;
;--------------------------------------------------------------------------------
    ;>>> Close all transient TCP connections

;   call    SET_UNAPI
    ld  a,TCPIP_TCP_ABORT
    ld  b,0
    call    CALL_U

    ;>>> Open the TCP connection

    ld  hl,TCP_PARAMS
    ld  a,TCPIP_TCP_OPEN
    call    CALL_U
    or  a
    jr  z,OPEN_OK

    ;* If error is "not implemented", show the appropriate message
    ;  depending on the type of connection requested

    cp  ERR_NOT_IMP
    jr  nz,NO_NOT_IMP

    ld  a,(PASSIVE_OPEN)
    or  a
    ld  de,NOTCPA_S ;Active TCP open
    jp  z,PRINT_TERM

    ld  hl,(IP_REMOTE)
    ld  de,(IP_REMOTE+2)
    ld  a,h
    or  l
    or  d
    or  e
    ld  de,NOTCPPU_S    ;Passive TCP open with socket unespecified
    jp  z,PRINT_TERM

    ld  de,NOTCPPS_S    ;Passive TCP open with socket specified
    jp  PRINT_TERM

NO_NOT_IMP:

    ;* If error is other, get its message from the errors table

    push    af
;   print   ERROR_S
    ld  hl,ERROR_S
    call    PRINT_BF
    pop af
    ld  b,a ;Error: Show the cause and terminate
    ld  de,TCPOPERRS_T
    call    GET_STRING
    jp  PRINT_TERM

OPEN_OK:
    ld  a,b
    ld  (CON_NUM),a ;No error: saves connection handle
;   print   OPENING_S
    ld  hl,OPENING_S
    call    PRINT_BF
;   call    SET_UNAPI

    ;--- Wait until the connection is established.
    ;    If ESC is pressed meanwhile, the connection is closed
    ;    and the program finishes.

WAIT_OPEN:
    ld  a,TCPIP_WAIT
    call    CALL_U

;   ld  a,(#FBEC)   ;Bit 2 of #FBEC is 0
;   bit 2,a ;when ESC is being pressed
;;  jp  z,CLOSE_END
;   ret z
    
    ld  a,(CON_NUM)
    ld  b,a
    ld  hl,0
    ld  a,TCPIP_TCP_STATE
    call    CALL_U
    or  a
    jr  z,WAIT_OPEN2

    push    bc
;   print   ONE_NL_S
    ld  hl,ONE_NL_S
    call    PRINT_BF
    pop bc
    ld  de,TCPCLOSED_T  ;If the connection has reverted to CLOSED,
    ld  b,c
    set 7,b
    call    GET_STRING  ;show the reason and terminate
    jp  PRINT_TERM

WAIT_OPEN2:
    ld  a,b
    cp  4   ;4 = code for ESTABLISHED state
    jr  nz,WAIT_OPEN

;   print   OPENED_S
    ld  hl,OPENED_S
    call    PRINT_BF
    ld  hl,NB_BU
    ld  (B_BU),hl
    ld  (E_BU),hl
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;--- Auto NICK, USER
;   call    SET_UNAPI

;--- 0.5 sec pause
;   ld  b,30
;   ei
;AN_3_: halt
;   djnz    AN_3_
;
;   ld  a,TCPIP_WAIT
;   call    CALL_U

    ld  hl,#FFFF
    ld  de,AA_NICK-1
AN_1:   inc hl
    inc de
    ld  a,(de)
    or  a
    jr  nz,AN_1
;           hl  - length string
    ld  a,(CON_NUM)
    ld  b,a
    ld  de,AA_NICK
    ld  c,1     ;"Push" is specified
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR

;   ld  a,TCPIP_WAIT
;   call    CALL_U

;   call    SET_UNAPI

    ld  hl,2
    ld  de,AA_CRLF
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
;--- 0.5 sec pause
;   ld  b,30
;AN_3:  halt
;   djnz    AN_3
;
;   call    SET_UNAPI

;   ld  a,TCPIP_WAIT
;   call    CALL_U

    ld  hl,#FFFF
    ld  de,AA_USER-1
AN_2:   inc hl
    inc de
    ld  a,(de)
    or  a
    jr  nz,AN_2
;           hl  - length string
    ld  a,(CON_NUM)
    ld  b,a
    ld  de,AA_USER
    ld  c,1     ;"Push" is specified
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR

;   ld  a,TCPIP_WAIT
;   call    CALL_U

;   call    SET_UNAPI
    ld  hl,2
    ld  de,AA_CRLF
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR

    ld  a,1
    ld  (serv1c),a
    ld  hl,(TIMER)
    ld  (tcptim),hl
    ret
;========================================================================
TCPSEP:
    ld  a,(serv1c)
    or  a
    ret z
    xor a
    ld  hl,(TIMER)
    ld  de,(tcptim)
    sbc hl,de
    ret z

;   call    END_RCV

;
;   ld  a,(serv1s+1)
;   call    PUT_P2
;   ld  ix,sWCB0
;
    ld  a,(CON_NUM)
    ld  b,a
;   ld  de,BUFFER 
    ld  de,(E_BU)
    ld  hl,1024
    ld  a,TCPIP_TCP_RCV
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR    ;Error?
    ld  hl,(TIMER)
    ld  (tcptim),hl
    ld  a,b
    or  c
    jp  z,END_RCV   ;No data available?
TCP_RCVOK:
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++   
;   ld  (LBUFF),bc
    ld  hl,(E_BU)
    add hl,bc
    ld  (E_BU),hl

;   call    END_RCV
;""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
; 
;   ld  de,(timtim)
;   inc de
;   ld  (timtim),de
;   ld  hl,BUFFER1
;   ld  (bbuf),hl
;   ld  b,4
;   ld  c,"0"
;   ld  a,%10000001
;   call    NUMTOASC
;   ld  bc,4
;   ld  (lenb),bc
;   call    BuffOU1
;""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
; NB_BU ...........................................
; #C100 |               |       
; B_BU --               |
; E_BU _________________
    ld  a,(S_C)
    ld  (T_S_C),a
;;  call    PUT_P2
;;  ld  hl,BUFFER
;   ld  hl,(E_BU)
;   ld  de,NB_BU
;   ld  (bbuf),de
;   xor a
;   sbc hl,de
;;  ld  hl,(LBUFF)
;   ld  (lenb),hl
;   call    BuffOU1
;   ld  hl,NB_BU
;   ld  (E_BU),hl
;   ret 


;   
TCP_RCV1:
    ld  hl,(E_BU)
    ld  bc,NB_BU
    xor a       
    sbc hl,bc   
    ret z       ; buffer empty
    ld  b,h
    ld  c,l     ; length receive packet
    ld  hl,NB_BU
    ld  a,#0A       
    cpir            ; find end string  [0D][0A]|[x]
    ret nz      ; end of string not found ( wait for next TCP packet)
    ld  (B_BU),hl   ; point the remaining part of the packet
    ld  de,NB_BU
    ld  (bbuf),de   ; begin budder
;   ex  hl,de
    xor a
    sbc hl,de
    ld  (lenb),hl   ; lengt buffer
;
    call    RECIV_SEP
;
    ld  de,(B_BU)
    ld  hl,(E_BU)
    xor a       
    sbc hl,de
    ld  b,h
    ld  c,l 
    jp  z,tcprc1        ; no rough lines
;   jp  c,0
    ; delete processed string
    
    push    bc
    ld  hl,(B_BU)
    ld  de,NB_BU
    ldir
    pop bc
tcprc1:
    ld  hl,NB_BU
    ld  (B_BU),hl
    add hl,bc
    ld  (E_BU),hl

    jp  TCP_RCV1


; receive string processing
RECIV_SEP:
;   jp  BuffOU1     ; off



;   ld  de,(timtim)
;   inc de
;   ld  (timtim),de
;   ld  hl,BUFFER1
;   ld  (bbuf),hl
;   ld  b,4
;   ld  c,"0"
;   ld  a,%10000001
;   call    NUMTOASC
;   ld  bc,4
;   ld  (lenb),bc
;   call    BuffOU1






; --- PING ?
    ld  hl,NB_BU
    ld  de,AA_PING
    ld  b,5
    call    STR_CP
    jr  nz,DE1
; --- PING detected
DE2:    ld  a,(hl)
    inc hl
    cp  " "
    jr  z,DE2
    cp  ":"
    jr  z,DE2
    cp  #0D
    jr  z,DE2
    or  a
    jr  z,DE2
    ld  (POINT),hl     ; server name
; --- send PONG
;   call    SET_UNAPI
    ld  de,AA_PONG
    ld  hl,5
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
; --- send server name
;   call    SET_UNAPI
    ld  de,(POINT)
    ld  hl,0
    push    de
DE3:    ld  a,(de)
    inc de
    inc hl
    cp  " "
    jr  z,DE3
    cp  ":"
    jr  z,DE3
    cp  0
    jr  z,DE3
    cp  #0D 
    jr  z,DE3
    cp  #0A
    jr  z,DE3   
    pop de
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
; --- send CRLF
;   call    SET_UNAPI
    ld  de,AA_CRLF
    ld  hl,2
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
    jp  END_KEY
DE1:
; --- detect join (:[nick]!xxxxxxx JOIN :[#channel])
    ld  hl,NB_BU-1
DE4:    inc hl
    ld  a,(hl)
    cp  ":"
    jr  z,DE4
    ld  de,PA_NICK
    ld  b,32
    call    STR_CP
    jr  nz,DE_0 ;invalid nick
;   inc hl
    ld  a,(hl)
    cp  "!"
    jr  nz,DE_0 ;different length nick
DE5:    inc hl
    ld  a,(hl)
    or  a
    jr  z,DE_0
    cp  #0D
    jr  z,DE_0
    cp  " "
    jr  nz,DE5
    inc hl
    ld  de,AA_JOIN
    ld  b,5
    call    STR_CP
    jr  nz,DE_0 ;not "JOIN MESSAGE"
    dec hl
DE6:    inc hl
    ld  a,(hl)
    cp  ":"
    jr  z,DE6
    cp  " "
    jr  z,DE6
;--- copy channel name to parametr C_CHAN
    ld  de,C_CHAN
    ld  b,16
DE7:    ld  a,(hl)
    cp  " "
    jr  z,DE_8
    cp  ","
    jr  z,DE_8
    cp  #0D
    jr  z,DE_8
    or  a
    jr  z,DE_8
    ld  (de),a  
    inc hl
    inc de
    djnz    DE7
DE_8:   ld  a," "
    ld  (de),a
    inc de
    ld  a,":"
    ld  (de),a
    inc de
    xor a
    ld  (de),a
; control
;   ld  de,C_CHAN
;   call    CONOUTS        
    ld  hl,C_CHAN
    call    PRINT_BF
; set request create channel record 
;   ld  a,1
;   ld  (req),a
    call    CHANNEL_C
;   jp  DEDSC1

;**************************************************************************
;**************************************************************************
DE_0:

;   jp  DEDSC       ; TEST
; string analise procedure
;
; 1 - save addres part
    ld  hl,NB_BU
    ld  de,ADDRES
DED1:   ld  a,(hl)
    cp  ":"
    jr  nz,DED2
    inc hl
    jr  DED1        ; 1st ":" not save
DED2:               ; address part save
    ld  a,(hl)
    ld  (de),a
    inc hl
    inc de
    cp  " "
    jr  nz,DED2
    xor a
    ld  (de),a
; 2 - command part decoder
;
; text command decoder
;               ; hl pointer word of command        
    call    DET_MSG     ; 

    ld  bc,(LBUFF)
    jr  c,DED3      ; not word
    cp  1       ; NICK
    jp  z,DE_NICK
    cp  2       ; PRIVMSG
    jp  z,DE_PRIV
    cp  3       ; NOTICE
    cp  4       ; JOIN
    jp  z,DE_JOIN
    cp  5       ; PART
    jp  z,DE_PART
    cp  6       ; mode
    jp  z,DE_MODE
    cp  7       ; kick
    jp  z,DE_KICK
    cp  8       ; quit
    jp  z,DE_QUIT
    cp  9       ; 353 nicklist
    jp  z,DE_NL
    cp  10      ; 366 end nicklist
    jp  z,DE_ENL
DED3:
; numeric command
 ;  call    EXTNUM      ; bc - num
;   jr  c,DED4      ; 17 bits
;   or  a
;   jr  nz,DED4     ; >5 digit
;   xor a
;   cp  d
;   jr  z,DED4      ; 0 digit
;   xor a
;   ld  hl,333
;   sbc hl,bc
;   jr  z,...

;next arg
DED4:
;   call    NEXTarg

; all not detect message goto server console
DEDSC:
;   ld  hl,BUFFER
;   ld  bc,(LBUFF)
;   ld  (bbuf),hl
;   ld  (lenb),bc
    ld  de,NB_BU
    ld  (bbuf),de
    ld  hl,(B_BU)
    xor a
    sbc hl,de
    ld  (lenb),hl

    ld  a,(serv1s+1)
    ld  (T_S_C),a
    call    PUT_P2

DEDSC1: call    BuffOU1
    ld  a,(S_C)
    call    PUT_P2

    ret
;   jp  STATUS_OK
DE_PART:
DE_MODE:
DE_KICK:
DE_QUIT:
DE_JOIN:
DE_JC:

    call    NEXTarg
    ld  a,":"
DE_J2:  cp  (hl)
    jr  nz,DE_J1
    inc hl
    jr  DE_J2
DE_J1:  ld  de,C_CHAN
    call    COPYARG
    ld  a,"C"
    ld  de,C_CHAN
    call    SrS
    jp  c,DEDSC

DEDSCE: ld  de,NB_BU
    ld  (bbuf),de
    ld  hl,(B_BU)
    xor a
    sbc hl,de
    ld  (lenb),hl
    jp  DEDSC1

    
DE_PRIV:
    call    NEXTarg
;   hl pointer on argument

;   test on own nick
    push    hl
    ld  de,PA_NICK
DE_P1   ld  a,(de)
    cp  (hl)
    jr  nz,DE_P2
    inc hl
    inc de
    jr  DE_P1
DE_P2:  or  a
    jr  nz,DE_P3
    ld  a,(hl)  
    cp  " "
DE_P3:  pop hl
; if Z then Nick own detect
    jp  z,DE_QUE
; Not nick -> channelname
; Find record 
    push    hl
    ld  a,"C" ; Channel record find
    ex  de,hl
    call    SrS
    pop hl
    jp  c,DEDSC ; non time Not find Create ?
; Record finded, segment channel active
DE_CC1: ld  (T_S_C),a
    call    NEXTarg
DE_C2:  ld  a,(hl)
    cp  ":"
    jr  nz,DE_C1
    inc hl
    jr  DE_C2
DE_C1:  ld  (bbuf1),hl
    ld  bc,0
    ld  a,13
DE_C3:  cp  (hl)
    inc hl
    inc bc
    jr  nz,DE_C3
;   ld  (hl),10
    inc bc
    ld  (lenb1),bc
; out dest addres (nick)
    ld  hl,ADDRES
    ld  (bbuf),hl
    ld  bc,0
DE_C5:  inc hl
    inc bc
    ld  a,(hl)
    cp  "!"
    jr  z,DE_C4
    cp  " "
    jr  z,DE_C4
    or  a
    jr  z,DE_C4
    jr  DE_C5
DE_C4:  ld  (hl)," "
    inc bc
    ld  (lenb),bc
    call    BuffOU1
    ld  hl,(lenb1)
    ld  (lenb),hl
    ld  hl,(bbuf1)
    ld  (bbuf),hl
    jp  DEDSC1  
DE_QUE:
    push     hl
    ld  hl,ADDRES
    ld  de,PA_QNICK
DE_Q2:  ld  a,(hl)
    cp  "!"
    jr  z,DE_Q1
    cp  " "
    jr  z,DE_Q1
    or  a
    jr  z,DE_Q1
    ld  (de),a
    inc hl
    inc de
    jr  DE_Q2   
DE_Q1:
    ld  a," "
    ld  (de),a
    inc de
    xor a
    ld  (de),a
    call    QUERY_C 
    pop hl
; Find query record ? itc query_C
    jp  DE_CC1
COPYARG:
COPA1:  ld  a,(hl)
    cp  " "
    jr  z,COPA2
    cp  ","
    jr  z,COPA2
    cp  #0D
    jr  z,COPA2
    or  a
    jr  z,COPA2
    ld  (de),a  
    inc hl
    inc de
    jr  COPA1
COPA2:  ld  a," "
    ld  (de),a
    inc de
    xor a
    ld  (de),a
    ret
COPYARG0:
COPA_1: ld  a,(hl)
    cp  " "
    jr  z,COPA_2
    cp  ","
    jr  z,COPA_2
    cp  #0D
    jr  z,COPA_2
    or  a
    jr  z,COPA_2
    ld  (de),a  
    inc hl
    inc de
    jr  COPA_1
COPA_2: xor a
    ld  (de),a
    ret

DE_NL:
    call    DE_NLF
    jp  c,DEDSC

    ld  a,":"
    cp  (hl)
    jr  nz,DE_NL2
    inc hl
DE_NL2: ex  de,hl 
;   
    ld  a,1
    ld  (w1new),a
    ld  ix,sWCB1    ;nicklist windows
    ld  a,(nlnew)
    or  a
    jr  z,DE_NL3
;clear nicklist
    ld  hl,(sWCB1+12)
    ld  (sWCB1+16),hl
    xor a
    ld  (ix+23),a
    ld  (ix+24),a
    inc a
    ld  (ix+10),a
;
DE_NL3: 
    ld  hl,(sWCB1+16)
DE_NL6: ld  a,(de)
    cp  13
    jr  z,DE_NL5
    or  a
    jr  z,DE_NL5
    ld  (hl),a
    cp  " "
    jr  nz,DE_NL4
    inc (ix+23)
DE_NL4: inc hl
    inc de
    jr  DE_NL6
DE_NL5: ld  a," "
    ld  (hl),a
    inc (ix+23)
    inc hl
    ld  (sWCB1+16),hl
    xor a
    ld  (hl),a
    ld  (nlnew),a
;
    inc a
    ld  (w1new),a
    jp  DEDSCE  

DE_ENL:
    call    DE_NLF
    jp  c,DEDSC
    ld  a,1
    ld  (nlnew),a
    jp  DEDSCE      ; * ret

DE_NLF:
    call    NEXTarg
    call    NEXTarg
    ld  a,"#"
    cp  (hl)
    jr  z,DE_NL1
    call    NEXTarg
DE_NL1: ld  de,C_CHAN
    call    COPYARG
    inc hl
    push    hl
    ld  a,"C"
    ld  de,C_CHAN
    call    SrS
    pop     hl
    ret
DE_NICK:
    ld  hl,NB_BU-1
DE_NI4: inc hl
    ld  a,(hl)
    cp  ":"
    jr  z,DE_NI4
    ld  de,PA_NICK
    ld  b,32
    call    STR_CP
    jp  nz,DEDSC ;invalid nick
;   inc hl
    ld  a,(hl)
    cp  "!"
    jp  nz,DEDSC ;different length nick
    ld  hl,NB_BU
    call    NEXTarg
    call    NEXTarg
    ld  a,":"
    cp  (hl)
    jr  nz,DE_NI5
    inc hl
DE_NI5: ld  de,PA_NICK
    call    COPYARG0

    jp  DEDSC


PRNTLOOP:



;;  ld  a,(#FBEC)   ;If ESC is pressed, terminate
;;  bit 2,a
;;
;;  jp  z,CLOSE_END
;; blocked
;
;
;;  (hl) - start str
;;  bc - legh
;
;   push    bc  ;Print out data character by character.
;   ld  a,(hl)  ;We can't use _STROUT function call,
;   inc hl  ;since we don't know if any "$" character
;   push    hl  ;is contained in the string.
;;  ld  e,a
;;  ld  c,_CONOUT
;;  call    DOS
;   call    OUTC_TW;
;   pop hl
;   pop bc
;   dec bc
;   ld  a,b
;   or  c
;   jr  nz,PRNTLOOP
;   jr  STATUS_OK
END_RCV:    ;

    ;--- Check if the connection has lost the ESTABLISHED
    ;    state. If so, close the connection and terminate.

;   call    SET_UNAPI
    ld  a,(CON_NUM)
    ld  b,a
    ld  hl,0
    ld  a,TCPIP_TCP_STATE
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
    ld  a,b
    cp  4   ;ESTABLISHED state
    jr  z,STATUS_OK

    ld  a,(CON_NUM) ;Otherwise, close and print
    ld  b,a     ;"Closed by remote peer" before terminating
    ld  a,TCPIP_TCP_CLOSE
    call    CALL_U
;   print   TWO_NL_S
    ld  hl,TWO_NL_S
    call    PRINT_BF
;   print   PEERCLOSE_S+1
    ld  hl,PEERCLOSE_S+1
    call    PRINT_BF

    ld  a,0
    ld  (serv1c),a
    ret

;   jp  TERMINATE

STATUS_OK:


END_KEY:    ;

    ;--- End of the main loop step:
    ;    Give the INL code an opportunity to excute,
    ;    then repeat the loop.

;   call    SET_UNAPI
    ld  a,TCPIP_WAIT
    call    CALL_U
;   jp  MAIN_LOOP
    ret
NEXTarg:
    inc hl
    ld  a,(hl)
    cp  " "
    jr  nz,NEXTarg
    inc hl
    ret
;========================================================================
TCPSEND:
    ld  a,(serv1c)
    or  a
    ret z

;--- insert module irc adapting string
    xor a
    ld  (ME_STATUS),a
;   ld  a,(BUFFER+1)
;   or  a
    ld  iy,(bbuf)
    ld  bc,(lenb)
    ld  a,b
    or  c
;   jp  z,GI_E1     ; empty string
    ret z
;   ld  a,(BUFFER+2)    
    ld  a,(iy)
    cp  "/"
    jr  nz,GI_C1    ; regular msg string
    ld  a,(#FBEB)
    and #00000010   ;ctrl
    jr  z,GI_C1

; new command detector
    ld  de,D_COMM
    ld  hl,(bbuf)
    inc hl
    call    DET     ; 1-nick, 2-join, 3-query, 4-part
    jr  c,GII_OLD
    cp  5
    jp  z,G_query
    cp  6
    jp  z,G_query

GII_OLD:
;--- command line (/command parametrs)
;   ld  a,(BUFFER+3)    ;
    ld  a,(iy+1)
    and %11011111
        cp  "M"             ; detect /me
        jr  nz,GI_C4
;   ld  a,(BUFFER+4)
    ld  a,(iy+2)
    and %11011111
    cp  "E"
    jr  nz,GI_C4
;   ld  a,(BUFFER+5)
    ld  a,(iy+3)
    cp  " "
    jr  nz,GI_C4
;--- /ME detected 

    ld  bc,(lenb)
    dec bc      ; [/ME_] X
;   dec bc
    dec bc
    dec bc
    ld  (lenb),bc
    inc iy
    inc iy
    inc iy
    inc iy
    ld  (bbuf),iy



;
;   ld  a,(BUFFER+1)    ;Adds a #01 Before CR
;   ld  c,a
;   ld  b,0
;   dec bc
;   ld  hl,BUFFER+2
    ld  bc,(lenb)
    dec bc
    dec bc
    dec bc
    ld  hl,(bbuf)
    add hl,bc
    ld  (hl),#01
    inc hl
    ld  (hl),#0D
    inc hl
    ld  (hl),#0A

    ld  a,1
    ld  (ME_STATUS),a
;---    goto send   message string
    jr  GI_C1

GI_C4:              ; command name  
;   ld  a,(BUFFER+1)
;   dec a
;   ld  (BUFFER+1),a
;   inc     a
;   ld  c,a
;   ld  b,0
;   ld  hl,BUFFER+3
;   ld  de,BUFFER+2
;   ldir
    ld  bc,(lenb)
    dec bc
    ld  (lenb),bc
    inc iy
    ld  (bbuf),iy
    jr  GI_E1
GI_C1:
;--- regular string message for current channel
; 
; check channel status
;   ld  a,(C_CHAN)
;   or  a
;   jr  nz,GI_C2    ;status ok
;   ld  de,CHNOT_S
;   ld  c,_STROUT
;   call    DOS
;   jp  END_KEY


GI_C2:
;
;test server consol
    ld  a,(serv1s+1)
    ld  b,a
    ld  a,(S_C)
    cp  b
    jp  z,GI_NO_Chann   ; Not channel - send msg stop


;    1p - send "PRIVMSG "
;   call    SET_UNAPI
    ld  de,AA_PRIVMSG
    ld  hl,8
    ld  c,1
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
;   ld  a,TCPIP_WAIT
;   call    CALL_U
;    1p - send name current channel and ":"
;   call    SET_UNAPI
;   ld  hl,#FFFF
;   ld  de,C_CHAN-1
;GI_C3: inc hl
;   inc de
;   ld  a,(de)
;   cp  ":"
;   jr  nz,GI_C3
;   inc hl
;   get channel name lenght
    ld  de,0
    ld  hl,#8000+5
    ld  a," "
GI_C3:  cp  (hl)
    inc hl
    inc de
    jr  nz,GI_C3
    ex  de,hl   
;           hl  - lenght string
    ld  a,(CON_NUM)
    ld  b,a
    ld  de,#8000+5
    ld  c,1     ;"Push" is specified
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
;   ld  a,TCPIP_WAIT
;   call    CALL_U
; send ":"
;   call    SET_UNAPI   
    ld  de,PA_DP
    ld  hl,1
    ld  c,1
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR

;---
    ld  a,(ME_STATUS)
    or  a
    jr  z,GI_E1

;--- send prefix #01,"ACTION "
;   call    SET_UNAPI
    ld  de,PA_ME
    ld  hl,8
    ld  c,1
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR

GI_E1:

;
;   ld  a,(BUFFER+1)    ;Adds a LF at the end of the line
;   ld  c,a
;   ld  b,0
;   inc bc
;   ld  hl,BUFFER+2
;   add hl,bc
;   ld  (hl),10
;   inc bc
;   push    bc
;   call    SET_UNAPI
;   pop hl

    ld  hl,(lenb)

    ld  a,(CON_NUM) ;Sends the line to the connection
    ld  b,a
;   ld  de,BUFFER+2
    ld  de,(bbuf)
    ld  c,1     ;"Push" is specified
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
; 
;   ld  a,(ME_STATUS)
;   or  a
;   jr  z,END_KEY
;
;--- send sufix #01
;   call    SET_UNAPI
;   ld  de,PA_ME
;   ld  hl,1
;   ld  c,1
;   ld  a,(CON_NUM)
;   ld  b,a
;   ld  a,TCPIP_TCP_SEND
;   call    CALL_U
;   or  a
;   jp  nz,TCP_ERROR


    jp  END_KEY1
;
GI_NO_Chann:    
    ld  hl,YANCH_S
    call    PRINT_BF
    jp  END_KEY1


    ;* Character mode: gets the character with or without echo,
    ;  and sends it to the connection

;GET_INPUT_C:   ld  a,(GETCHAR_FUN)
;   ld  c,a
;   push    bc
;   call    DOS
;   ld  (BUFFER),a
;
;   pop hl  ;If character is CR, sends also
;   cp  13  ;a LF
;   ld  hl,1
;   jr  nz,GET_INPUT_C2
;
;   ld  a,10
;   ld  (BUFFER+1),a
;   ld  a,l ;If local echo is ON, the LF
;   cp  _CONIN  ;must be explicitly printed
;   call    z,LF
;   ld  hl,2
;
;GET_INPUT_C2:
;   push    hl
;   call    SET_UNAPI
;   pop hl
;   ld  a,(CON_NUM) ;Sends the character(s)
;   ld  b,a
;   ld  de,BUFFER
;   ld  c,1 ;"PUSH" is specified
;   ld  a,TCPIP_TCP_SEND
;   call    CALL_UNAPI
;   or  a
;   jp  nz,TCP_ERROR

END_KEY1:   ;

    ;--- End of the main loop step:
    ;    Give the INL code an opportunity to excute,
    ;    then repeat the loop.

;   call    SET_UNAPI
    ld  hl,(TIMER)
    ld  (tcptim),hl
    ld  a,TCPIP_WAIT
    call    CALL_U


    ret
;
TCP_PARTC:
; part channel
    ld  a,(serv1c)
    or  a
    ret z   

    ld  hl,AA_PART
    ld  DE,BUFFER
    ld  bc,5
    ldir
    ld  de,BUFFER+5
    ld  hl,#8000+5
    call    COPYARG0
    ld  a,13
    ld  (de),a
    inc de
    ld  a,10
    ld  (de),a
    inc de
    ld  hl,BUFFER
    ex  de,hl
    xor a
    sbc hl,de
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
    ret

;========================================================================

    ;--- Jump here in case a call to TCP_SEND or TCP_RCV return an error.
    ;    Input: A=Error code

    ;* If the error is "Output buffer overflow",
    ;  print the error, close the connection and finish

TCP_ERROR:
    cp  ERR_NO_CONN
    jr  z,TCP_ERROR2

    ;* The error is not "Connection is closed"

    ld  de,TCPERROR_T
    ld  b,a
    call    GET_STRING
;   ld  c,_STROUT
;   call    5
    ex  de,hl
    call    PRINT_BF

;   call    SET_UNAPI
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_CLOSE
    call    CALL_U
    xor a
    ld  (serv1c),a
;   jp  TERMINATE
    ret

TCP_ERROR2:

    ;* The error is "Connection is closed"
    ;  (cannot be ERR_CONN_STATE, since the
    ;  connection is either CLOSED, ESTABLISHED or CLOSE-WAIT;
    ;  and we assume that it is not ERR_INV_PARAM nor ERR_NOT_IMP):
    ;  Print the cause and finish

;   print   TWO_NL_S
    ld  hl,TWO_NL_S
    call    PRINT_BF
;   call    SET_UNAPI
    xor a
    ld  (serv1c),a
    ld  a,(CON_NUM)
    ld  b,a
    ld  hl,0
    ld  a,TCPIP_TCP_STATE
    call    CALL_U
    ld  b,c
    set 7,b
    ld  de,TCPCLOSED_T
    call    GET_STRING
    jp  PRINT_TERM

G_query:
    call    NEXTarg
G_Q0:   ld  a,(hl)
    cp  " "
    jr  nz,G_Q1
    inc hl
    jr  G_Q0 
G_Q1:   ld  de,PA_QNICK
    ld  b,0 ;if 0 insufficient parameters
G_Q3:   ld  a,(hl)      
    or  a
    jr  z,G_Q2
    cp  " "
    jr  z,G_Q2
    cp  13
    jr  z,G_Q2
    ld  (de),a
    inc hl
    inc de
    inc b
    jr  G_Q3
G_Q2:   ld  a," "
    ld  (de),a
    inc de  
    xor a
    ld  (de),a
    ld  a,b
    or  a
    jr  z,G_Q_NA
    call    QUERY_C
    ret
G_Q_NA:
    ld  hl,SM_QNA
    call    PRINT_TW
    ret


;******************************
;***                        ***
;***   AUXILIARY ROUTINES   ***
;***                        ***
;******************************

;--- STRCMP: Compares two strings
;    Input: HL, DE = Strings
;    Output: Z if strings are equal

STRCMP:
    ld  a,(de)
    cp  (hl)
    ret nz
    or  a
    ret z
    inc hl
    inc de
    jr  STRCMP


;--- NAME: COMP
;      Compares HL and DE (16 bits unsigned)
;    INPUT:    HL, DE = numbers to compare
;    OUTPUT:    C, NZ if HL > DE
;               C,  Z if HL = DE
;              NC, NZ if HL < DE

COMP:   call    _COMP
    ccf
    ret

_COMP:  ld  a,h
    sub d
    ret nz
    ld  a,l
    sub e
    ret


;--- NAME: EXTPAR
;      Extracts a parameter from the command line
;    INPUT:   A  = Parameter to extract (the first one is 1)
;             DE = Buffer to put the extracted parameter
;    OUTPUT:  A  = Total number of parameters in the command line
;             CY = 1 -> The specified parameter does not exist
;                       B undefined, buffer unmodified
;             CY = 0 -> B = Parameter length, not including the tailing 0
;                       Parameter extracted to DE, finished with a 0 byte
;                       DE preserved

EXTPAR: or  a   ;Terminates with error if A = 0
    scf
    ret z

    ld  b,a
    ld  a,(#80) ;Terminates with error if
    or  a   ;there are no parameters
    scf
    ret z
    ld  a,b

    push    af
    push hl
    ld  a,(#80)
    ld  c,a ;Adds 0 at the end
    ld  b,0 ;(required under DOS 1)
    ld  hl,#81
    add hl,bc
    ld  (hl),0
    pop hl
    pop af

    push    hl
    push   de
    push ix
    ld  ix,0    ;IXl: Number of parameter
    ld  ixh,a   ;IXh: Parameter to be extracted
    ld  hl,#81

    ;* Scans the command line and counts parameters

PASASPC:    ld  a,(hl)  ;Skips spaces until a parameter
    or  a   ;is found
    jr  z,ENDPNUM
    cp  " "
    inc hl
    jr  z,PASASPC

    inc ix  ;Increases number of parameters
PASAPAR:    ld  a,(hl)  ;Walks through the parameter
    or  a
    jr  z,ENDPNUM
    cp  " "
    inc hl
    jr  z,PASASPC
    jr  PASAPAR

    ;* Here we know already how many parameters are available

ENDPNUM:    ld  a,ixl   ;Error if the parameter to extract
    cp  ixh ;is greater than the total number of
    jr  c,EXTPERR   ;parameters available

    ld  hl,#81
    ld  b,1 ;B = current parameter
PASAP2: ld  a,(hl)  ;Skips spaces until the next
    cp  " " ;parameter is found
    inc hl
    jr  z,PASAP2

    ld  a,ixh   ;If it is the parameter we are
    cp  b   ;searching for, we extract it,
    jr  z,PUTINDE0  ;else...

    inc B
PASAP3: ld  a,(hl)  ;...we skip it and return to PASAP2
    cp  " "
    inc hl
    jr  nz,PASAP3
    jr  PASAP2

    ;* Parameter is located, now copy it to the user buffer

PUTINDE0:   ld  b,0
    dec hl
PUTINDE:    inc b
    ld  a,(hl)
    cp  " "
    jr  z,ENDPUT
    or  a
    jr  z,ENDPUT
    ld  (de),a  ;Paramete is copied to (DE)
    inc de
    inc hl
    jr  PUTINDE

ENDPUT: xor a
    ld  (de),a
    dec b

    ld  a,ixl
    or  a
    jr  FINEXTP
EXTPERR:    scf
FINEXTP:    pop ix
        pop     de
        pop hl
    ret


;--- Termination due to ESC or CTRL-C pressing
;    Connection is closed, or aborted if CTRL is pressed,
;    and program finishes

CLOSE_END:  ld  a,(CON_NUM)
    cp  #FF
    jr  z,TERMINATE
    push    af
;   call    SET_UNAPI
    pop bc

    ld  a,(#FBEB)   ;Checks CTRL key status
    bit 1,a ;in order to decide whether
    ld  a,TCPIP_TCP_CLOSE   ;CLOSE or ABORT must be executed
    ld  de,USERCLOS_S   ;(always ABORT in case of CTRL-C)
    jr  nz,CLOSE_END2   ;and which message to show
    ld  a,TCPIP_TCP_ABORT   ;("user closed" or "user aborted")
    ld  de,USERAB_S
CLOSE_END2: push    de

    call    CALL_U

CLOSE_END3: pop de
    jp  PRINT_TERM


;--- Program terminations

    ;* Print string at DE and terminate

PRINT_TERM:
    ex  de,hl
    call    PRINT_BF
    ret
PRINT_TERML:
    ld  c,_STROUT
    call    DOS
    jr  TERMINATE

    ;* Invalid parameter

;INVPAR:    print   INVPAR_S

INVPAR: ld  de,INVPAR_S
    ld  c,_STROUT
    call    DOS


    jr  TERMINATE

    ;* Missing parameter

;MISSPAR:   print   MISSPAR_S
MISSPAR:    ld  de,MISSPAR_S
    ld  c,_STROUT
    call    DOS

    jr  TERMINATE

MISSHNM:        ld  de,MISSHNM_S
    ld  c,_STROUT
    call    DOS

    ;* Generic termination routine

TERMINATE:
    ld  a,(TPASLOT1)
    ld  h,#40
    call    ENASLT

    ret ;****************   

    ld  a,(TPASEG1) ;Restores TPA on page 1
    call    PUT_P1

    ld  a,(DOS2)    ;Under DOS 2, the CTRL-C
    or  a   ;control routine has to be cancelled first
    ld  de,0
    ld  c,_DEFAB
    call    nz,DOS

    ld  c,_TERM0
    jp  DOS


;--- Prints LF

LF: ld  e,10
    ld  c,_CONOUT
    jp  DOS


;--- Segment switching routines for page 1,
;    these are overwritten with calls to
;    mapper support routines on DOS 2
;
;PUT_P1:    out (#FD),a
;   ret
;GET_P1:    in  a,(#FD);
;   ret
;
TPASEG1:    db  2   ;TPA segment on page 1


;--- IP_STRING: Converts an IP address to a string
;    Input: L.H.E.D = IP address
;           A = Termination character
;           IX = Address for the string

IP_STRING:
    push    af
    ld  a,l
    call    BYTE2ASC
    ld  (ix),"."
    inc ix
    ld  a,h
    call    BYTE2ASC
    ld  (ix),"."
    inc ix
    ld  a,e
    call    BYTE2ASC
    ld  (ix),"."
    inc ix
    ld  a,d
    call    BYTE2ASC

    pop af
    ld  (ix),a  ;Termination character
    ret





;--- CHECK_KEY: Calls a DOS routine so the CTRL-C pressing
;    can be detected by DOS and the program can be aborted.
;    Also, returns A<>0 if a key has been pressed.

CHECK_KEY:  ld  e,#FF
    ld  c,_DIRIO
    jp  DOS


;--- BYTE2ASC: Converts the number A into a string without termination
;    Puts the string in (IX), and modifies IX so it points after the string
;    Modifies: C

BYTE2ASC:   cp  10
    jr  c,B2A_1D
    cp  100
    jr  c,B2A_2D
    cp  200
    jr  c,B2A_1XX
    jr  B2A_2XX

    ;--- One digit

B2A_1D: 
    add a, "0"
    ld  (ix),a
    inc ix
    ret

    ;--- Two digits

B2A_2D: ld  c,"0"
B2A_2D2:    inc c
    sub 10
    cp  10
    jr  nc,B2A_2D2

    ld  (ix),c
    inc ix
    jr  B2A_1D

    ;--- Between 100 and 199

B2A_1XX:    ld  (ix),"1"
    sub 100
B2A_XXX:    inc ix
    cp  10
    jr  nc,B2A_2D   ;If ti is 1XY with X>0
    ld  (ix),"0"    ;If it is 10Y
    inc ix
    jr  B2A_1D

    ;--- Between 200 and 255

B2A_2XX:    ld  (ix),"2"
    sub 200
    jr  B2A_XXX


;--- GET_STRING: Returns the string associated to a number, or "Unknown".
;    Input:  DE = Pointer to a table of numbers and strings, with the format:
;                 db num,"String$"
;                 db num2,"String2$"
;                 ...
;                 db 0
;            B = Associated number
;    Output: DE = Pointer to the string

GET_STRING: ld  a,(de)
    inc de
    or  a   ;String not found: return "Unknown"
    jr  nz,LOOP_GETS2

    ld  ix,UNKCODE_S
    ld  a,b
    call    BYTE2ASC
    ld  (ix),")"
    ld  (ix+1),"$"

    ld  de,STRUNK_S
    ret

LOOP_GETS2: cp  b   ;The number matches?
    ret z

LOOP_GETS3: ld  a,(de)  ;No: pass to the next one
    inc de
    cp  "$"
    jr  nz,LOOP_GETS3
    jr  GET_STRING

STRUNK_S:   db  "*** Unknown error ("
UNKCODE_S:  db  "000)$"

;--- Code to switch TCP/IP implementation on page 1, if necessary

;SET_UNAPI:
;UNAPI_SLOT:    ld  a,0
;   ld  h,#40
;   call    ENASLT
;   ei
;UNAPI_SEG: ld  a,0
;   jp  PUT_P1
;
;CALL_U_:
;   push    af
;   push    hl
;   push    de
;   push    bc
;   call    SET_UNAPI
;   pop bc
;   pop de
;   pop hl
;   pop af
;
;CALL_UNAPI:    call    0
;   nop
;RES_UNAPI:
;   push    af
;
;       ld  a,(S_U)
;       call    PUT_P1
;   pop af
;       ret
;   nop
;
CALL_um:        ;[18] +2, +8, +12
    push    af
    ld  a,0
    call    PUT_P1
    pop af
    call    0
    push    af
    ld  a,0
    call    PUT_P1
    pop af  
    ret

CALL_U:         ; +5, +17, +24
    push    af
    push    hl
    push    de
    push    bc
    ld  a,0
    ld  h,40
    call    ENASLT
    ei
    pop bc
    pop de
    pop hl
    pop af
    call    0
    push    af
    push    hl
    push    de
    push    bc
    ld  a,0
    ld  h,40
    call    ENASLT
    ei
    pop bc
    pop de
    pop hl
    pop af  
    ret











;--- Extract parametr's on buffer
;   HL - buffer
;   IY N# Word
G_PA:
    XOR A
    ld  (PA_ST),a   
    dec hl
G_PA1:  
    inc hl
    ld  a,(hl)
    cp  0   ; end of file
    ret z
    cp  #1A
    ret z       ; end of file
    cp  #0D
    jr  z,G_PA1 ; end of string
    cp  #0A
    jr  z,G_PA1 ;
    
    push    iy
    call    G_PA_N
    pop iy
        jr  G_PA1

;--- Extract parametr on string
; IY - N# Word
; HL - buffer
G_PA_N:
    ld  a,(iy)    ; index on name parametr
    or  a         ; if = 0 to finish
    ret z
    ld  e,a
    inc iy
    ld  d,(iy)
    inc     iy
    ld  a,(de)    ; len
    inc de        ; de - (name parametr)
    ld  b,a
    push    hl
    call    STR_CP
    jr  z,G_PA_1    ; Ok, go to extract
    pop hl
    inc iy
    inc iy
    jr  G_PA_N          ; next search word of parametr
G_PA_1:             ; Extract parametr to (parametr)
                ; (hl) -> (de) util 0, #0D, #0A, #1A (EOF), ";"
    ld  a,(de)      ; bit mask parametr
    ld  b,a
    ld  a,(PA_ST)
    or  b
    ld  (PA_ST),a
    ld  e,(iy)
    inc iy
    ld  d,(iy)
    inc iy
G_PA_3  ld  a,(hl)
    cp  0
    jr  z,G_PA_2    
    cp  #0D
    jr  z,G_PA_2
    cp  #1A
    jr  z,G_PA_2
    cp  ";"
    jr  z,G_PA_2
    ld  (de),a
    inc hl
    inc de
    jr  G_PA_3

G_PA_2: xor a
    ld  (de),a      ; 0 -> end of parametr
    scf
    pop bc      ; correction stack
    ret

;--- String compare
; HL - 1st string
; DE - 2nd string
; B  - length
; output NZ - false, Z - true
STR_CP:
    ld  a,(de)
    or  a
    ret z
    cp  (hl)
    ret nz
    inc hl
    inc de
    djnz    STR_CP
    ret
;--- Console string out until 0 char
CONOUTS:
    ld  a,(de)
    cp  0
    ret z
    push    de
    ld  e,a
    ld  c,_CONOUT
    call    DOS
    pop de
    inc de
    jr  CONOUTS





; Templates and Variable Set 1 (< #4000) (for TCP/IP routines)


;--- TCP parameters block for the connection, it is filled in with the command line parameters

TCP_PARAMS:
IP_REMOTE:      db  0,0,0,0
PORT_REMOTE:    dw  0
PORT_LOCAL:     dw  #FFFF   ;Random port if none is specified
USER_TOUT:      dw  0
PASSIVE_OPEN:   db  0

;--- Variables

CON_NUM:        db  #FF ;Connection handle
INPUT_MODE:     db  0   ;0 for line mode, #FF for character mode
GETCHAR_FUN:    db  _CONIN  ;_CONIN for echo ON, _INNOE for echo OFF
DOS2:           db  0   ;0 for DOS 1, #FF for DOS 2

;--- Text strings
USEDOS2_S:
    db  "* USE DOS2 ",13,10,"$"


PRESENT_S:
    db  "IRC client for MSX. TCP/IP Engine base on:",13,10
    db  "TCP Console for the TCP/IP UNAPI 1.0 By Konamiman, 4/2010",13,10
    db  "User interface from Pasha Zakharov 2:5001/3 HiHi :)",13,10,10,"$"

INFO_S:         db  "Usage: MSXIRC [inifile.ini]",13,10,10,"$"
NOINIF_S:       db  "*** Error load INI File",13,10,"$"
NOINS_S:        db  "*** InterNestor Lite is not installed",13,10,"$"
INVPAR_S:       db  "*** Invalid parameter(s)",13,10,"$"
MISSPAR_S:      db  "*** Missing parameter(s)",13,10,"$"
MISSHNM_S:      db  "*** Missing hostname",13,10,"$"
ERROR_S:        db  "*** ERROR: $"
CHNOT_S:        db  "*** Channel not open",13,10,"$"
OPENING_S:      db  "Opening connection (press ESC to cancel)... $"
RESOLVING_S:    db  "Resolving host name... $"
OPENED_S:       db  "OK!",13,10,10
                db  "*** Press F1 for help",13,10,10,"$"
HELP_S:         db  13,10,"*** F1: Show this help",13,10
                db  "*** F2: Toggle line/character mode",13,10
                db  "        Current mode is: "
LINCHAR_S:      db  "line     ",13,10
                db  "*** F3: Toggle local echo ON/OFF (only on character mode)",13,10
                db  "        Currently local echo is: "
ECHONOFF_S:     db  "ON ",13,10
                db  "*** ESC: Close connection and exit",13,10
                db  "*** CTRL+ESC: Abort connection and exit",13,10
                db  "*** Type the text to be sent to the other side.",13,10
                db  "    In line mode, the line text will be sent when pressing ENTER.",13,10
                db  "    In character mode, each typed character will be sent immediately.",13,10
                db  "    Incoming data will be printed out to the screen.",13,10,10,"$"
INPTOG0_S:      db  13,10,"*** Input mode toggled to line mode",13,10,"$"
INPTOG1_S:      db  13,10,"*** Input mode toggled to character mode",13,10,"$"
ECHOTOG0_S:     db  13,10,"*** Local echo toggled ON",13,10,"$"
ECHOTOG1_S:     db  13,10,"*** Local echo toggled OFF",13,10,"$"
USERCLOS_S:     db  13,10,"*** Connection closed by user",13,10,"$"
USERAB_S:       db  13,10,"*** Connection aborted by user",13,10,"$"
LINE_S:         db  "line     "
CHAR_S:         db  "character"
ON_S:           db  "ON "
OFF_S:          db  "OFF"
ASTERISK_S:     db  "*** $"


;* Host name resolution

RESOLVERR_S:    db  13,10,"ERROR "
RESOLVERRC_S:   ds  6   ;Leave space for "<code>: $"
RESOLVOK_S:     db  "OK: "
RESOLVIP_S:     ds  16  ;Space for "xxx.xxx.xxx.xxx$"
TWO_NL_S:       db  13,10
ONE_NL_S:       db  13,10,"$"


;* DNS_Q errors

DNSQERRS_T: db  ERR_NO_NETWORK,"No network connection$"
            db  ERR_NO_DNS,"No DNS servers available$"
            db  ERR_NOT_IMP,"This TCP/IP UNAPI implementation does not support name resolution.",13,10
            db  "An IP address must be specified instead.$"
            db  0


;* DNS_S errors

DNSRERRS_T: db  1,"Query format error$"
            db  2,"Server failure$"
            db  3,"Name error (this host name does not exist)$"
            db  4,"Query type not implemented by the server$"
            db  5,"Query refused by the server$"
            db  6,"DNS error 6$"
            db  7,"DNS error 7$"
            db  8,"DNS error 8$"
            db  9,"DNS error 9$"
            db  10,"DNS error 10$"
            db  11,"DNS error 11$"
            db  12,"DNS error 12$"
            db  13,"DNS error 13$"
            db  14,"DNS error 14$"
            db  15,"DNS error 15$"
            db  16,"Server(s) not responding to queries$"
            db  17,"Total operation timeout expired$"
            db  19,"Internet connection lost$"
            db  20,"Dead-end reply (not containing answers nor redirections)$"
            db  21,"Answer is truncated$"
            db  0

;* TCP_OPEN errors

TCPOPERRS_T:    db  ERR_NO_FREE_CONN,"Too many TCP connections opened$"
                db  ERR_NO_NETWORK,"No network connection found$"
                db  ERR_CONN_EXISTS,"Connection already exists, try another local port number$"
                db  ERR_INV_PARAM,"Unespecified remote socket is not allowed on active connections$"
                db  0

    ;* TCP close reasons

TCPCLOSED_T:
    db  128+0,"*** Connection closed$"
    db  128+1,"*** Connection never used$"
PEERCLOSE_S:
    db  128+2,"*** Connection closed by peer$"  ;Actually local CLOSE, but we close only when the peer closes
    db  128+3,"*** Connection locally aborted$"
    db  128+4,"*** Connection refused (RST received)$"
    db  128+5,"*** Data sending timeout expired$"
    db  128+6,"*** Connection timeout expired$"
    db  128+7,"*** Internet connection lost$"
    db  128+8,"*** Destination host is unreachable$"
    db  0

;* TCP RCV/SEND errors

TCPERROR_T:
    db  ERR_CONN_STATE,"*** The connection state does not allow sending data$"
    db  ERR_BUFFER,"*** Output buffer overflow$"
    db  ERR_INV_PARAM,"*** Invalid parameter$"
    db  0

;* Other errors

NOTCPIP_S:  db  "*** No TCP/IP UNAPI implementation found.",13,10,"$"
NOTCPA_S:   db  "*** This TCP/IP UNAPI implementation does not support",13,10
            db  "    opening active TCP connections.",13,10,"$"
NOTCPPS_S:  db  "*** This TCP/IP UNAPI implementation does not support",13,10
            db  "    opening passive TCP connections with remote socket specified.",13,10,"$"
NOTCPPU_S:  db  "*** This TCP/IP UNAPI implementation does not support",13,10
            db  "    opening passive TCP connections with remote socket unespecified.",13,10,"$"
YANCH_S:    db  "* You are not on a channel",13,10,"$"

;HST_PORT:  db  "6667",0



;--- UNAPI related

TCPIP_S:    db  "TCP/IP",0,0,0,0,0,0,0,0,0,0


;--- Segment switching routines for page 1,2
;    these are overwritten with calls to
;    mapper support routines on DOS 2

ALL_SEG: jp  D1ALLS
FRE_SEG jp  D1FRES
RD_SEG  ret
    ds  2   
WR_SEG  ret
    ds  2   
CALL_SEG: ret
    ds  2
CALLS:  ret
        ds  2
PUT_PH  ret
    ds  2
GET_PH  ret
    ds  2
PUT_P0  out (#FC),a
    ret
GET_P0  in  a,(#FC)
    ret
PUT_P1: out (#FD),a
    ret
GET_P1: in  a,(#FD)
    ret
PUT_P2: out (#FE),a
    ret
GET_P2: in  a,(#FE)
    ret
PUT_P3: out (#FF),a
    ret
GET_P3: in  a,(#FF)
    ret

D1ALLS:
    ld  hl,EMAPTAB
    xor a
    ld  e,a
    ld  d,32
    dec a
D2als2: cp  (hl)
    jr  nz,D2als1   
    inc hl
    inc e
    dec d
    jr  nz,D2als2
    scf
    ret
D2als1: xor a
    rl  e
    rl  e
    rl  e
    ld  d,a
    ld  b,1
D2als4: ld  a,b
    and (hl)
    jr  z,D2als3
    xor a
    rl  b
    inc d
    jr  D2als4
D2als3: ld  a,b
    or  (hl)
    ld  (hl),a
    ld  a,d
    add a,e
    ret
D1FRES: 
    ld  e,a
    and %00000111
    ld  b,a
    xor a
    ld  d,a
    ld  a,e
    rra 
    rra 
    rra 
    and %00011111
    ld  e,a
    ld  hl,EMAPTAB
    add hl,de   
    ld  a,#FF
    inc b
D1frs1  rla
    djnz    D1frs1
    and (hl)
    ld  (hl),a

;   scf
    ret

INIMAPDOS1:
    ; Get Free mapper segmet between 1st 4seg and last segment #FF (<- use TSP/IP UNAPI)
    in  a,(#FC)
Imds1   inc a
    push    af
    call    D1FRES
    pop af
    cp  #FE
    jr  nz,Imds1
    in  a,(#FF)
    ld  b,a
    xor a
    sub b
    ld  (totmaps),a
    sub 5   
    ld  (freemaps),a
    ret

DET_MSG:
;   scf
;   ret
;  input  hl - "word ....." 
;  output a - N find template word, CF- not find 
    ld  de,D_MSG
DET:    ld  b,0
DEMS0:  ld  c,0
    push    hl
DEMS1:  ld  a,(de)
    cp  (hl)
;   and %11011111
    jr  z,DEMS2
    ld  c,1
DEMS2:  cp  " "
    jr  z,DEMS3
    or  a
    jr  z,DEMS5
    inc hl
    inc de
    jr  DEMS1   
DEMS3:  pop hl
    inc b
    ld  a,c
    or  a
    ld  a,b
    ret z
    inc de
    jr  DEMS0       
DEMS5:  pop hl
    scf
    ret
tcptim: dw  0
notcpip: db 0
EMAPTAB:db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
totmaps:    db  0
freemaps:   db  0   
P2_sys  db  0
S_C db  0
S_S db  0
T_S_C   db  0
segsel  db  0
segp    db  0
tsegt   db  0
;MAPTAB status0,page0,status1,page1.... status79,page79
; status 0-free "S"-server page, "C"-channell page, "H"-help page, "P"-private page
MAPTAB  db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
SSIAT:  ds  80
    ds  10



year:   dw  0
day:    db  0
month:  db  0
minute: db  0
hour    db  0
second: db  0

timtim  dw  0

serv1c: db  0
serv2c: db  0
serv3c: db  0
serv1s: ds  2
serv2s: ds  2
serv3s: ds  2

req:    db  0

;
D_MSG:
    db  "NICK "     ; Nickname
    db  "PRIVMSG "  ;
    db  "NOTICE "
    db  "JOIN "
    db  "PART "
    db  "MODE "
    db  "KICK " 
    db  "QUIT "     ;
    db  "353 "      ; nicklist
    db  "366 "      ; end nicklist
    db  "324 "          ; mode replay

    db  0
D_COMM:
    db  "nick "
    db  "NICK "
    db  "join "
    db  "JOIN "
    db  "query "
    db  "QUERY "
    db  "part "
    db  "PART "
    db  0


;Table timestump template
TABTS:
    db  71,1    ; 0 none
    db  72,5    ; 1 HH:MM
    db  72,8    ; 2 HH:MM:SS
    db  66,11   ; 3 MM-DD HH:MM
    db  66,14   ; 4 MM-DD HH:MM:SS
    db  63,14   ; 5 YY-MM-DD HH:MM
    db  63,17   ; 6 YY-MM-DD HH:MM:SS
    db  61,16   ; 7 YYYY-MM-DD HH:MM
    db  61,19   ; 8 YYYY-MM-DD HH:MM:SS

PA_ST:  db  0   ; bit mask status parametr's
            ; 0 - server        1 - port
            ; 2 - server password   3 - nick
            ; 4 - user str

ME_STATUS:  db  0
AA_PART     db  "PART ",0
PA_ME:      db  1,"ACTION ",0
AA_PRIVMSG: db  "PRIVMSG ",0
C_CHAN:     db  0
        ds  50
PA_DP:      db  ":"
AA_CRLF:    db  #0D,#0A,0
AA_SERVER:  db  "SERVER "
PA_SERVER:  ds  256
AA_PORT     db  "PORT "
PA_PORT:    db  "6667",0
AA_SPAS     db  "PASS "
AA_SRVPASS: db  "SERVER PASSWORD "
PA_SRVPASS: db  0
        ds  16
AA_NICK:    db  "NICK "
PA_NICK:    db  0
        ds  32
AA_ANICK:   db  "ALTNICK "
PA_ANICK:   db  0
        ds  32
AA_USER:    db  "USER "
PA_USER:    db  "user host server :Real Name",0
        ds  256-25
AA_JOIN:    db  "JOIN ",0
PA_CHANNEL: db  "#channel password",0
        ds  52
PA_FONT:    db  0,0,0,0, 0,0,0,0, 0,0,0, 0, "$"
PA_IC:      db  "1",0
            ds  3
PA_PC:      db  "15",0
        ds  2
PA_AIC:     db  "1",0
        ds  3
PA_APC:     db  "13",0
        ds  2
PA_TIMEST:  db  "0",0
        ds  3
PA_QNICK:   db  0
        ds  30

AA_PING:    db  "PING ",0
AA_PONG:    db  "PONG ",0

;--- Buffer for the remote host name

HOST_NAME:  ds 256;

;--- Generic temporary buffer for data send/receive
;    and for parameter parsing
B_BU:       dw  NB_BU
E_BU:       dw  NB_BU

POINT:      ds  2
LBUFF:      ds      2
ADDRES:     db  0
        ds  256

NB_BU       equ #C100
BUFFER:             ;   equ #C100
        ds  512
BUFFER1:    ds  512

;--- NAME: NUMTOASC
;      Converts a 16 bit number into an ASCII string
;    INPUT:      DE = Number to convert
;                HL = Buffer to put the generated ASCII string
;                B  = Total number of characters of the string
;                     not including any termination character
;                C  = Padding character
;                     The generated string is right justified,
;                     and the remaining space at the left is padded
;                     with the character indicated in C.
;                     If the generated string length is greater than
;                     the value specified in B, this value is ignored
;                     and the string length is the one needed for
;                     all the digits of the number.
;                     To compute length, termination character "$" or 00
;                     is not counted.
;                 A = &B ZPRFFTTT
;                     TTT = Format of the generated string number:
;                            0: decimal
;                            1: hexadecimal
;                            2: hexadecimal, starting with "&H"
;                            3: hexadecimal, starting with "#"
;                            4: hexadecimal, finished with "H"
;                            5: binary
;                            6: binary, starting with "&B"
;                            7: binary, finishing with "B"
;                     R   = Range of the input number:
;                            0: 0..65535 (unsigned integer)
;                            1: -32768..32767 (twos complement integer)
;                               If the output format is binary,
;                               the number is assumed to be a 8 bit integer
;                               in the range 0.255 (unsigned).
;                               That is, bit R and register D are ignored.
;                     FF  = How the string must finish:
;                            0: No special finish
;                            1: Add a "$" character at the end
;                            2: Add a 00 character at the end
;                            3: Set to 1 the bit 7 of the last character
;                     P   = "+" sign:
;                            0: Do not add a "+" sign to positive numbers
;                            1: Add a "+" sign to positive numbers
;                     Z   = Left zeros:
;                            0: Remove left zeros
;                            1: Do not remove left zeros
;    OUTPUT:    String generated in (HL)
;               B = Length of the string, not including the padding
;               C = Length of the string, including the padding
;                   Tailing "$" or 00 are not counted for the length
;               All other registers are preserved

NUMTOASC:   
push    af
push ix
push de
push hl
    ld  ix,WorkNTOA
    push    af
    push af
    and %00000111
    ld  (ix+0),a    ;Type
    pop af
    and %00011000
    rrca
    rrca
    rrca
    ld  (ix+1),a    ;Finishing
    pop af
    and %11100000
    rlca
    rlca
    rlca
    ld  (ix+6),a    ;Flags: Z(zero), P(+ sign), R(range)
    ld  (ix+2),b    ;Number of final characters
    ld  (ix+3),c    ;Padding character
    xor a
    ld  (ix+4),a    ;Total length
    ld  (ix+5),a    ;Number length
    ld  a,10
    ld  (ix+7),a    ;Divisor = 10
    ld  (ix+13),l   ;User buffer
    ld  (ix+14),h
    ld  hl,BufNTOA
    ld  (ix+10),l   ;Internal buffer
    ld  (ix+11),h

ChkTipo:    ld  a,(ix+0)    ;Set divisor to 2 or 16,
    or  a   ;or leave it to 10
    jr  z,ChkBoH
    cp  5
    jp  nc,EsBin
EsHexa: ld  a,16
    jr  GTipo
EsBin:  ld  a,2
    ld  d,0
    res 0,(ix+6)    ;If binary, range is 0-255
GTipo:  ld  (ix+7),a

ChkBoH: ld  a,(ix+0)    ;Checks if a final "H" or "B"
    cp  7   ;is desired
    jp  z,PonB
    cp  4
    jr  nz,ChkTip2
PonH:   ld  a,"H"
    jr  PonHoB
PonB:   ld  a,"B"
PonHoB: ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+5)

ChkTip2:    ld  a,d ;If the number is 0, never add sign
    or  e
    jr  z,NoSgn
    bit 0,(ix+6)    ;Checks range
    jr  z,SgnPos
ChkSgn: bit 7,d
    jr  z,SgnPos
SgnNeg: push    hl  ;Negates number
    ld  hl,0    ;Sign=0:no sign; 1:+; 2:-
    xor a
    sbc hl,de
    ex  de,hl
    pop hl
    ld  a,2
    jr  FinSgn
SgnPos: bit 1,(ix+6)
    jr  z,NoSgn
    ld  a,1
    jr  FinSgn
NoSgn:  xor a
FinSgn: ld  (ix+12),a

ChkDoH: ld  b,4
    xor a
    cp  (ix+0)
    jp  z,EsDec
    ld  a,4
    cp  (ix+0)
    jp  nc,EsHexa2
EsBin2: ld  b,8
    jr  EsHexa2
EsDec:  ld  b,5

EsHexa2:    push    de
Divide: push    bc
	push hl   ;DE/(IX+7)=DE, remaining A
    ld  a,d
    ld  c,e
    ld  d,0
    ld  e,(ix+7)
    ld  hl,0
    ld  b,16
BucDiv: rl  c
    rla
    adc hl,hl
    sbc hl,de
    jr  nc,$+3
    add hl,de
    ccf
    djnz    BucDiv
    rl  c
    rla
    ld  d,a
    ld  e,c
    ld  a,l
    pop hl
    pop bc

ChkRest9:   cp  10  ;Converts the remaining
    jp  nc,EsMay9   ;to a character
EsMen9: add a,"0"
    jr  PonEnBuf
EsMay9: sub 10
    add a,"A"

PonEnBuf:   ld  (hl),a  ;Puts character in the buffer
    inc hl
    inc (ix+4)
    inc (ix+5)
    djnz    Divide
    pop de

ChkECros:   bit 2,(ix+6)    ;Cchecks if zeros must be removed
    jr  nz,ChkAmp
    dec hl
    ld  b,(ix+5)
    dec b   ;B=num. of digits to check
Chk1Cro:    ld  a,(hl)
    cp  "0"
    jr  nz,FinECeros
    dec hl
    dec (ix+4)
    dec (ix+5)
    djnz    Chk1Cro
FinECeros:  inc hl

ChkAmp: ld  a,(ix+0)    ;Puts "#", "&H" or "&B" if necessary
    cp  2
    jr  z,PonAmpH
    cp  3
    jr  z,PonAlm
    cp  6
    jr  nz,PonSgn
PonAmpB:    ld  a,"B"
    jr  PonAmpHB
PonAlm: ld  a,"#"
    ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+5)
    jr  PonSgn
PonAmpH:    ld  a,"H"
PonAmpHB:   ld  (hl),a
    inc hl
    ld  a,"&"
    ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+4)
    inc (ix+5)
    inc (ix+5)

PonSgn: ld  a,(ix+12)   ;Puts sign
    or  a
    jr  z,ChkLon
SgnTipo:    cp  1
    jr  nz,PonNeg
PonPos: ld  a,"+"
    jr  PonPoN
    jr  ChkLon
PonNeg: ld  a,"-"
PonPoN  ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+5)

ChkLon: ld  a,(ix+2)    ;Puts padding if necessary
    cp  (ix+4)
    jp  c,Invert
    jr  z,Invert
PonCars:    sub (ix+4)
    ld  b,a
    ld  a,(ix+3)
Pon1Car:    ld  (hl),a
    inc hl
    inc (ix+4)
    djnz    Pon1Car

Invert: ld  l,(ix+10)
    ld  h,(ix+11)
    xor a   ;Inverts the string
    push    hl
    ld  (ix+8),a
    ld  a,(ix+4)
    dec a
    ld  e,a
    ld  d,0
    add hl,de
    ex  de,hl
    pop hl  ;HL=initial buffer, DE=final buffer
    ld  a,(ix+4)
    srl a
    ld  b,a
BucInv: push    bc
    ld  a,(de)
    ld  b,(hl)
    ex  de,hl
    ld  (de),a
    ld  (hl),b
    ex  de,hl
    inc hl
    dec de
    pop bc
    ld  a,b ;*** This part was missing on the
    or  a   ;*** original routine
    jr  z,ToBufUs   ;***
    djnz    BucInv
ToBufUs:    ld  l,(ix+10)
    ld  h,(ix+11)
    ld  e,(ix+13)
    ld  d,(ix+14)
    ld  c,(ix+4)
    ld  b,0
    ldir
    ex  de,hl

ChkFin1:    ld  a,(ix+1)    ;Checks if "$" or 00 finishing is desired
    and %00000111
    or  a
    jr  z,Fin
    cp  1
    jr  z,PonDolar
    cp  2
    jr  z,PonChr0

PonBit7:    dec hl
    ld  a,(hl)
    or  %10000000
    ld  (hl),a
    jr  Fin

PonChr0:    xor a
    jr  PonDo0
PonDolar:   ld  a,"$"
PonDo0: ld  (hl),a
    inc (ix+4)

Fin:    ld  b,(ix+5)
    ld  c,(ix+4)
    pop hl
    pop     de
    pop ix
    pop af
    ret

WorkNTOA:   defs    16
BufNTOA:    ds  10


;--- EXTNUM16
;      Extracts a 16-bit number from a zero-finished ASCII string
;    Input:  HL = ASCII string address
;    Output: BC = Extracted number
;            Cy = 1 if error (invalid string)

EXTNUM16:   call    EXTNUM
    ret c
    jp  c,INVPAR    ;Error if >65535

    ld  a,e
    or  a   ;Error if the last char is not 0
    ret z
    scf
    ret


;--- NAME: EXTNUM
;      Extracts a 5 digits number from an ASCII string
;    INPUT:      HL = ASCII string address
;    OUTPUT:     CY-BC = 17 bits extracted number
;                D  = number of digits of the number
;                     The number is considered to be completely extracted
;                     when a non-numeric character is found,
;                     or when already five characters have been processed.
;                E  = first non-numeric character found (or 6th digit)
;                A  = error:
;                     0 => No error
;                     1 => The number has more than five digits.
;                          CY-BC contains then the number composed with
;                          only the first five digits.
;    All other registers are preserved.

EXTNUM: push    hl
	push ix
    ld  ix,ACA
    res 0,(ix)
    set 1,(ix)
    ld  bc,0
    ld  de,0
BUSNUM: ld  a,(hl)  ;Jumps to FINEXT if no numeric character
    ld  e,a ;IXh = last read character
    cp  "0"
    jr  c,FINEXT
    cp  "9"+1
    jr  nc,FINEXT
    ld  a,d
    cp  5
    jr  z,FINEXT
    call    POR10

SUMA:   push    hl  ;BC = BC + A 
    push    bc
    pop hl
    ld  bc,0
    ld  a,e
    sub "0"
    ld  c,a
    add hl,bc
    call    c,BIT17
    push    hl
    pop bc
    pop hl

    inc d
    inc hl
    jr  BUSNUM

BIT17:  set 0,(ix)
    ret
ACA:    db  0   ;b0: num>65535. b1: more than 5 digits

FINEXT: ld  a,e
    cp  "0"
    call    c,NODESB
    cp  "9"+1
    call    nc,NODESB
    ld  a,(ix)
    pop ix
    pop hl
    srl a
    ret

NODESB: res 1,(ix)
    ret

POR10:  push    de
push hl   ;BC = BC * 10 
    push    bc
    push    bc
    pop hl
    pop de
    ld  b,3
ROTA:   sla l
    rl  h
    djnz    ROTA
    call    c,BIT17
    add hl,de
    call    c,BIT17
    add hl,de
    call    c,BIT17
    push    hl
    pop bc
    pop hl
    pop de
    ret


; =======================================================================
; User interface subroutine
; =======================================================================

; Iit SCREEN 0 MODE 80 / 26.5
; 
INISCREEN:
    DI
    ld  a,2
    out (#99),a
    ld  a,15
    out (#99),a
lla1:   in  a,(#99)
    and #80
    jr  z,lla1

    
;   ld  bc,SETI
    ld  hl,SETI
    call    LRVD

    ld  a,(fntsour)
    cp  1
    jr  z,lla_nsf
    
; ROM PGT => VRAM PGT (symbol tab)
; [HL] - ROM PGT
; [DE] - VRAM PGT
; [BC] - lenght blok PGT
    ld  hl,#1BBF
    ld  DE,#1000
    ld  BC,2048
    ld  a,e ; LB VRAM
    out (#99),a
    ld  a,d ; HB VRAM
    or  #40     ; set 6 bit
    out (#99),a
LDirmv:

    push    de
    push    bc
    ld  a,#00 ; slot bios 0
    bios    RDSLT
    pop bc
    pop de
;
    out (#98),a
    inc hl
    dec bc
    ld  a,b
    or  c
    jr  nz,LDirmv
lla_nsf:
; Clear VRAM CT (0)
; [DE] - VRAM
; [BC] - lengt
    ld  de,#A00
    ld  bc,#270
    ld  a,e
    out (#99),a
    ld  a,d
    or  #40
    out (#99),a
LDirCT: xor a
    out (#98),a
    dec bc
    ld  a,b
    or  c
    jr  nz,LDirCT

; --- "space" (" ") #20 => VRAM PNT
; [DE] = VRAM
; [BC] = lenght
    ld  de,0
    ld  bc,1920
    ld  a,e
    out (#99),a
    ld  a,d
    or  #40
    out (#99),a
LDiPNT: ld  a,#20
    out (#98),a
    dec bc
    ld  a,b
    or  c
    jr  nz,LDiPNT


; set BIOS width 80
    ld  a,80
    ld  (#F3B0),a

    ei
    ret


; - Load text RAM => VRAM
; [HL] RAM
; [DE] VRAM
; [A] - 3 bit 16k bank vram
; [B] lenght block
; [C] port #98
 ;  ld  hl,tit
 ;  ld  de,116
 ;  ld  bc,#0898
LDVR:
    out (#99),a
    ld  a,#80 + 14
    out (#99),a
    ld  c,#98   
    ld  a,e
    out (#99),a
    ld  a,d
    or  #40
    out (#99),a
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
    ret
;
; input HL = File.ini output DE = "FILE    INI" (8+3)
CFILENAME:
    ld  c,8+3
    push    hl
    ld  l,e
    ld  h,d
    ld  b,c
Cfn1:   ld  (hl)," "
    inc hl
    djnz    Cfn1
    ld  hl,8
    add hl,de
    ld  (point),hl
    pop hl
Cfn2:   ld  a,(hl)
    or  a
    ret z
    cp  "."
    jr  nz,Cfn3
    inc hl
    ld  de,(point)
    ld  c,3
    jr  Cfn2
Cfn3    and %11011111
    ex  de,hl
    ld  (hl),a
    inc hl
    ex  de,hl   
    dec c
    inc hl
    jr  Cfn2
    ret
LOADFONT:
;
    ld  hl,FCB+1+8+3
    ld  b,28
    xor a
LFontt: ld  (hl),a
    inc hl
    djnz    LFontt
;
    ld  hl,PA_FONT
    ld  de,FCB+1
    call    CFILENAME
    ld  de,FCB
    ld  c,_FOPEN
    call    DOS
    or  a
    jr  z,LFont1
    ld  a,2
    ld  (fferr),a
    jr  LFont2
LFont1: ld  de,#9000    ; prebuffer PGT
    ld  c,_SDMA
    call    DOS
    ld  hl,1    ; set recod = 1 byte
    ld  (FCB+14),hl
    ld  de,FCB
    ld  hl,2048 ; size font tab  
    ld  c,_RBREAD
    call    DOS
    ld  (ttvar),hl
    ld  (fferr),a
    ld  de,2048
    xor a
    sbc hl,de
    jr  z,LFont2
    ld  a,3
    ld  (fferr),a
LFont2: ld  de,FCB
    ld  c,_FCLOSE
    call    DOS     
    ld  a,(fferr)
    or  a
    ret nz
;   
    ld  hl,#9000
    ld  bc,2048
    di
    xor a
    out (#99),a
    ld  a,#10+#40
    out (#99),a
LFont3: ld  a,(hl)
    out (#98),a
    inc hl
    dec bc
    ld  a,b
    or  c
    jr  nz,LFont3
    ld  a,1
    ld  (fntsour),a 
    ret
; Clear screeen buffer (global)
CLS_G:
;clear PNT
    ld  c," "
    ld  hl,#8000
    ld  de,80*28
CLSg1   ld  (hl),c
    inc hl
    dec de
    ld  a,e
    or  d
    jr  nz,CLSg1
;clear  CT
    ld  hl,#8A00
    ld  de,10*28
CLSg2   ld  (hl),c
    inc hl
    dec de
    ld  a,e
    or  d
    jr  nz,CLSg2
    ret
; Print text string for TW (text windows)
; input IX - WCB 
;   HL - start text string
;
PRINT_TW:
    ld  a,(hl)
    or  a
    ret z
    cp  "$"
    ret z
    push    hl
    call    OUTC_TW
    pop hl
    inc hl
    jr  PRINT_TW

CLOCK:
; get data
    ld  c,_GETDATE
    call    DOS
    ld  (year),hl
    ld  (day),de
    ld  c,_GETTIME
    call    DOS
    ld  (minute),hl
    ld  a,d
    ld  (second),a
; convert -> ascii
;    -------------- 2013.07.01 20:38| <- right top conner of screen
    ld  iy,year
    ld  hl,#8000+80-20
    ld  (hl)," "
    inc hl
    ld  de,(year)
    ld  bc,#0400 + "0"
;   ld  c,"0"
;   ld  a,%10000000
    xor a
    call    NUMTOASC
    ld  hl,#8000+80-15
    ld  (hl),"."
    inc hl
    ld  bc,#0200 + "0"
    ld  d,0
    ld  e,(iy+3)
    call    NUMTOASC
    inc hl
    inc hl
    ld  (hl),"."
    inc hl
    ld  bc,#0200 + "0"
    ld  e,(iy+2)
    call    NUMTOASC
    inc hl
    inc hl
    ld  (hl)," "
    inc hl
    ld  bc,#0200 + "0"
    ld  e,(iy+5)
    call    NUMTOASC
    inc hl
    inc hl
    ld  (hl),":"
    inc hl
    ld  bc,#0200 + "0"
    ld  e,(iy+4)
    call    NUMTOASC
    inc hl
    inc hl
    ld  (hl),":"
    inc hl
    ld  bc,#0200 + "0"
    ld  e,(iy+6)
    call    NUMTOASC
; load to VRAM
    ld  hl,#8000+80-20
    ld  b,80
    ld  c,#98
    di
    ld  a,80-20
    out (#99),a
    ld  a,#40
    out (#99),a
    otir
    ei
    ret
; Load CT buffer to VDP RAM;
LOAD_SA:
    ld  b,240 ;#F0
    ld  hl,#8A0A
    di
    ld  a,#0A
    out (#99),a
    ld  a,#0A+#40
    out (#99),a
    ld  c,#98
    otir
    ret

; Load PNT buffer to VDP RAM
;
LOAD_S:
; 80*27 = 2080  #0826
    di
    ld  a,2
    out (#99),a
    ld  a,15
    out (#99),a

    ld  hl,fulls
    ld  de,0
    xor a
    ld  b,0
    out (#99),a
    ld  a,#80 + 14
    out (#99),a
    ld  c,#98   
    ld  a,e
    out (#99),a
    ld  a,d
    or  #40
    out (#99),a
lds1:   in  a,(#99)
    and #80
    jr  z,lds1
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
;256  #100
lds2:   in  a,(#99)
;   and #80
;   jr  z,lds2
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
;512  #200
lds3:   in  a,(#99)
;   and #80
;   jr  z,lds3
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
lds4:   in  a,(#99)
;   and #80
;   jr  z,lds4
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
;1024 #400
lds5:   in  a,(#99)
;   and #80
;   jr  z,lds5
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
lds6:   in  a,(#99)
;   and #80
;   jr  z,lds6
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
lds7:   in  a,(#99)
;   and #80
;   jr  z,lds7
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
lds8:   in  a,(#99)
;   and #80
;   jr  z,lds8

    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
;2048 #800
lds9:   in  a,(#99)
;   and #80
;   jr  z,lds9
 
;#800 
    ld  b,#70
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
    ei
    ret
LRVD:   
    ld  b,(hl)
    inc hl
lrvd1   ld  a,(hl)
    inc hl
    out (#99),a
    djnz    lrvd1
    
    ret

;
; locate cursor x,y [0..maxH, 0..maxY]
;   e - horisontal d - vertical 
;   ix - WCB
POS_TW: ld  [ix+6],e
    ld  [ix+7],d
    ret
;
; Out char to position cursor win
;   ix - WCB
;
;
OUTC_TW:
; special simbol
    cp  #0D
    jp  z,otc0D
    cp  #0A
    jp  z,otc0A
    cp  #08
    jp  z,otc08
    cp  #09
    jp  z,otc09
; regular symbol
;
; test corret position cursor
    ex  af,af'
;   ld  b,a
    ld  d,(ix+4)  ;h size
    ld  a,(ix+6)  ;h pos
    cp  d
    jp  m,otcw_5  ;x posit <= max x
    ld  a,(ix+8)
    or  a
    ret z   ; drop out string
; next string
    xor a 
    ld  (ix+6),a
    inc (ix+7)  ; y++
otcw_5
; test correct position vertical
    ld  a,(ix+7)  ; v pos
    ld  c,(ix+5)  ; v max
    cp  c
    jp  p,otcw_4 ; y posit > max y
    jp  otcw_1  
otcw_4
    ld  a,(ix+9)
    or  a
    jr  nz,otcw_0
;   dec (ix+9)
    ret     ; drop out win
    
otcw_0: call    SCRLU_TW


;
otcw_1:         ; output symbol
;   ld  l,(IX+2)        ;
;   ld  h,(IX+3)        ; begin w
;   ld  c,(ix+7)    ; y posit
;   ld  de,80
;   inc c
;otcw_3:    dec c
;   jp  z,otcw_2
;   add hl,de
;   jr  otcw_3  

;otcw_2:    ld  d,0
;   ld  e,(ix+6)    ; x posit
;
    ld  hl,TMUV         ; tabl mult of 80
    ld  b,0
    ld  c,(ix+7)    ; y posit
    rlc c       ; *2
    add hl,bc
    ld  e,(hl)
    inc hl
    ld  d,(hl)          ; de=  y * 80
    ld  l,(ix+2)        ; begin w
    ld  h,(ix+3)        ;
    add hl,de
    ld  c,(ix+6)    ; x posit
    add hl,bc
    set 7,h
    ex  af,af'
        ld  (hl),a
    ld  b,a
;   increment posit cursor
    inc (ix+6)
        ld  a,(ix+11)
    or  a
    ret z
    di
    ld  a,(IX)
    out (#99),a
    ld  a,#80 + 45
    out (#99),a
    ld  a,(IX+1)
    out (#99),a
    ld  a,#80 + 14
    out (#99),a
    ld  a,l
    out (#99),a
    ld  a,h
    and #7F
    or  #40
    out (#99),a
;   ex  af,af'
    ld  a,b
    out (#98),a
    ld  (hl),a 
    ei
    ret
; scroll up text windows
; clear end string
; ix - WCB

SCRLU_TW:
        ld  h,(ix+3)
    ld  l,(ix+2)
    ld  b,0
;   ld  c,(ix+4)
    ld  c,80
    ld  a,(ix+5)
scrlu1: cp  2
    jp  m,srldu_1       ; end scroll
    ld  d,h
    ld  e,l
    ld  c,80
    add hl,bc
    ld  c,(ix+4)
    push    hl
    set 7,h
    set 7,d
    ldir
    pop hl
    dec a
    jr  scrlu1

srldu_1:    ; clear ending string

    ld  b,(IX+4)
    ld  a," "   ;spase
    set 7,h 
srldu_2:
    ld  (hl),a
    inc hl
    djnz    srldu_2

    ld  a,(ix+11)
    or  a
    call    nz,LOAD_S

    dec (ix+7)

    ret 

otc0D:  ld  a,[ix+20]
    or  a
    jr  nz,otc0D1
otc0D0: ld  a,[ix+6]
    ld  c,[ix+4]
    cp  c
    jp  p,otc0D1
    ld  a," "
    ex  af,af'
    call    otcw_1
    jr  otc0D0
otc0D1: xor a
    ld  [ix+6],a    ; x = 0
    ret

otc0A:  ld  a,[ix+7]    ; y_cur
    ld  b,[ix+5]    ; y_size
    inc [ix+7]               ; y = y+1
    cp  b
    ret c
    ld  a,(ix+9)
    or  a
    jr  nz,SCRLU_TW
    dec [ix+7]
    ret

otc09:  ld  a," "
    ex  af,af'
    call    otcw_1
    ld  a,(ix+6)
    and 7
    jr  nz,otc09
    ret
otc08:  ld  a,[ix+6]
    dec a       ; x = x-1
    jp  m,otc08_1       ; < 0
    ld  [ix+6],a
    ret
otc08_1: ld a,[ix+8]
    or  a
    ret z
    ld  a,[ix+4]
    dec a       
    ld  [ix+6],a    ; max h position
    ld  a,[ix+7]
    dec a           ; y = y-1
    jp  m,otc08_2   ; < 0
    ld  [ix+7],a
    ret
otc08_2: ld a,[ix+9]
    or  a
    ret z 
;   Scroll down text windows
;   clear 1st string
;   ix - WCB
SCRLD_TW:
    ld  a,[ix+5]      ; v max
    cp  2
    jp  m,srldw_1     ; v max < 2 - end scroll
;
    dec a
    ld  bc,80
    ld  h,(ix+3)
    ld  l,(ix+2)
srldw1:
    dec a
    jr  z,srldw0    
    add hl,bc
    jr  srldw1
srldw0:
; hl - last-1 string
    ld  a,[ix+5]
    dec a
    ld  d,h
    ld  e,l
    add hl,bc
    ex  de,hl
srldw2: ld  c,(ix+4)
    push    hl
    set 7,h
    set 7,d
    ldir          ; 1 str transfer
    pop hl
    ld  d,h
    ld  e,l
    ld  c,80
    or  a
    sbc hl,bc
    dec a
    jr  nz,srldw2
;
srldw_1:    ; clear 1st string
    ld  h,(ix+3)
    ld  l,(ix+2)
    ld  b,(IX+4)
    ld  a," "   ;spase
    set 7,h 
srlw_2: ld  (hl),a
    inc hl
    djnz    srlw_2
;   jr  LOAD_S
;   ret
CURSOR:
; in hl - absolute byte of screen
    ex  de,hl
    call    CURSOFF
    ex  de,hl
    xor a
    rr  h
    rr  l
    rra
    rr  h
    rr  l
    rra
    rr  h
    rr  l
    rra

    rra
    rra
    rra
    rra
    rra
    
    ld  de,#0A00
    add hl,de
    ld  (oldcur),hl
    ld  b,a
    di
    ld  a,l
    out (#99),a
    ld  a,h
    and #7F
    or  #40
    out (#99),a
    set 7,h
    inc b
    xor a
    scf
cur1:   rra
    djnz    cur1
    ld  (oldcur+2),a        
    or  (hl)
    out (#98),a
    ret
    
CURSOFF:
; cursor off 
    ld  hl,(oldcur) ; absolute coordinate CT
;   ld  a,(oldcur+2)    ; bit mask
    di
    ld  a,l
    out (#99),a
    ld  a,h
    and #7F
    or  #40
    out (#99),a
    set 7,h
    ld  a,(oldcur+2)
    cpl
    and (hl)
    out (#98),a
    ret
; 
;
OUTSTRW:
; out string of screen windows WCB - ix
; ix+22 - start out
    ld  l,(ix+22) ; start out from buffer
    ld  h,(ix+23)
    ld  e,(ix+16) ; end buffer
    ld  d,(ix+17)
;
    exx
    ld  l,(ix+2)  ; start screen
    ld  h,(ix+3)  ; 
    set 7,h
    ld  b,(ix+4)  ; H size
    exx
;
ostrw3: xor a
    ld  a,(hl)
    sbc hl,de       ; st - end
    jr  c,ostrw1
    ld  a," "     ; out buff - out " "
ostrw1: add hl,de
    inc hl
;
    exx
    ld  (hl),a
    inc hl
    dec b
    exx
;
    jr  nz,ostrw3
    
    ld  l,(ix+2)
    ld  h,(ix+3)
    ld  b,(ix+4)
    di
    ld  a,l
    out (#99),a
    ld  a,h
    or  #40
    out (#99),a
    set 7,h
    ld  c,#98
    otir

    ret 
;   Init Text Windows
;   CLS windows  
;   IX = WCB

CLS_TW:
    ld  h,(ix+3)
    ld  l,(ix+2)
    ld  de,fulls
    add hl,de
    ld  d,(ix+5)
    ld  a," "   ;spase

CLSTW2:
            
    ld  b,(IX+4)
    push    hl
    
CLSTW1: ld  (hl),a
    inc hl
    djnz    CLSTW1
    pop hl
    dec d
    jp  z,CLSTW3
    ld  c,80
    add hl,bc
    jr  CLSTW2
CLSTW3: ld  a,(ix+11)
    or  a
    ret z
    jp  LOAD_S  

; Clear Keyboard buffer 
CLKB:
    ld      c,_CONST
        call    DOS
        or      a
        ret z
        ld      c,_INNO
        call    DOS
    jp  CLKB

; Draw segment record table
DrSegT:
    ld  a,(P2_sys)
    call    PUT_P2
    ld  ix,sWCB1
    call    CLS_TW
    xor a
    ld  b,a
    ld  (ix+6),a ; cursor 0,0
    ld  (ix+7),a 
    ld  a,(ix+22) ;shift
;   ld  (ix+23),a ;rs
    ld  d,a
    rla
    ld  c,a
    ld  hl,MAPTAB
    add hl,bc
DrS1    ld  a,(hl)
    or  a
    jr  nz,DrS2 ; need out
    inc hl ; next record 
DrS3:   inc hl
    inc d
    ld  a,78
    cp  d   ;out table
    jr  nc,DrS1
    ret 
DrS2:   inc hl
    ld  a,(hl)
    exx 
    call    PUT_P2  
    ld  hl,#8000
    ld  de,BUFFER
    ld  bc,34
    ldir
    ex  de,hl
    ld  (hl),13
    inc hl  
    ld  (hl),10
    inc hl
    ld  (hl),"$"
    ld  a,(P2_sys)
    call    PUT_P2
    ld  hl,BUFFER
    call    PRINT_TW
    exx
    jr  DrS3
; Buffer segment active records table out to screen
BOSegT:
    ld  ix,sWCB1
    call    CLS_TW
    ld  a,(ix+16)
    or  a
    ret z       ; not record
    ld  de,50+4+1
    ld  hl,#9000
    ld  a,(ix+22)
    inc a
BOS2:   dec a
    jr  z,BOS1
    add hl,de
    jr  BOS2
BOS1:   ld  a,(ix+16)
    sub (ix+22)
    cp  (ix+5)
    jr  c,BOS4
    ld  a,(ix+5)
BOS4:   inc hl
    ex  de,hl
    ld  hl,#8000
    ld  bc,(sWCB1+2)
    add hl,bc
    ex  de,hl
BOS3:   ld  bc,34
    ldir
    ld  bc,55-34
    add hl,bc
    ex  de,hl
    ld  bc,80-34
    add hl,bc
    ex  de,hl
    dec a
    jr  nz,BOS3
    ret
; Bufferisation segment record table
BFSegT:
    ld  a,(P2_sys)
    call    PUT_P2
    ld  ix,sWCB1
    ld  de,#9000
    ld  (ix+16),0   ;b_end
    ld  (ix+17),0
    ld  hl,MAPTAB
BFS1    ld  a,(hl)
    or  a
    jr  nz,BFS2         ; not empry record
    inc hl          ; next record 
BFS3:   inc hl
    inc (ix+17)         ; counter record
    ld  a,78
    cp  (ix+17) ;out table
    jr  nc,BFS1
;   ret             ; finish scan records
    ld  a,(ix+16)       ; counter active records
    dec a
    sub (ix+5)          ; v- size
    jr  nc,BFS4         
    ld  (ix+22),0       ; no shift 
    jr  BFS5
BFS4:   inc a
    cp  (ix+22)
    jr  nc,BFS5         ; Shift <
    ld  (ix+22),a       
BFS5:
    ld  a,(ix+16)       
    cp  (ix+10)         ; curs att > couter active ?
    ret nc
    ld  (ix+10),a
    ret

BFS2:   inc hl
    ld  a,(hl)
    exx 
    ld  hl,BUFFER
    ld  b,(ix+17)
    ld  (hl),b
;   ld  (hl),(ix+17)
    call    PUT_P2
    inc hl
    ex  de,hl
    ld  hl,#8000
    ld  bc,50+4
    ldir
    ld  a,(P2_sys)
    call    PUT_P2
    exx
    push    hl
    ld  hl,BUFFER
    ld  bc,50+4+1
    ldir
    pop hl
    inc (ix+16)
    jr  BFS3


; Set segment information attribute
SSIA:   ld  hl,MAPTAB
    ld  de,SSIAT
    ld  b,80
SSIA1:  ld  a,(hl)
;   ex  hl,de
    cp  %10000000   ; 7-bit = 0 -> exist new data on record
    adc a,0
    or  %10000000
    and %10111111
    ld  (de),a
;   ex  hl,de
    inc hl
    inc hl
    inc de
    djnz    SSIA1

;   ld  de,SSIAT+80
    ld  l,e
    ld  h,d
    ld  b,10
    xor a
SSIA2:  ld  (hl),a
    inc hl
    djnz    SSIA2

    ld  a,(segs)
    ld  c,a
    xor a
    ld  b,a
    rr  c
    rra
    rr  c
    rra
    rr  c
    rra
    rra
    rra
    rra
    rra
    rra
    ex  de,hl
    add hl,bc   
    ld  b,a
    inc b
    xor a
    scf
SSIA3:  rra
    djnz    SSIA3
    ld  (hl),a  
    ret 

; Load segment information to VRAM
L_SIA:  
    di
    ld  hl,SSIAT    
    ld  a,#20
    out (#99),a
    ld  a,#08+#40
    out (#99),a
    ld  c,#98
    ld  b,80
    otir
    ld  a,#04
    out (#99),a
    ld  a,#0B+#40
    out (#99),a
;   ld  c,#98
    ld  b,10
    otir
    ei
    ret
; Clear atribute for cannel and nicks area 1-25 string
CLAT_C_N:
    ld  hl,#8A00 + 10   ; (80/8)
    ld  b,10*24
    xor a
clcn1:  ld  (hl),a
    inc hl
    djnz    clcn1
    ret
; Set atribute for nicks 
; ix+10 - select nick from UP string window to Down, if - 0 no select
SETAT_N:
    ld  a,(ix+10)   ; 
    or  a
    ret z
    cp  25
    ret nc
    ld  b,a
    ld  hl,#8A00 + 8
    ld  de,10
statn1: add hl,de
    djnz    statn1  
    ld  (hl),%01111111
    inc hl
    ld  (hl),%11111111
    ret
; Set atribute for name segment 
; ix+10 - select name from UP string window to Down, if - 0 no select
SETAT_S:
    ld  a,(ix+10)   ; 
    or  a
    ret z
    cp  25
    ret nc
    ld  b,a
    ld  hl,#8A00 + 5
    ld  de,10
stats1: add hl,de
    djnz    stats1  
    ld  (hl),%00000011
    ld  a,#FF
    inc hl
    ld  (hl),a
    inc hl
    ld  (hl),a
    inc hl
    ld  (hl),a
    inc hl
    ld  (hl),a
    ret

;
; print part buffer of chanel 
; last srtike - cur - end str win
; WCB channel windows - sWCB0 (#8870)
PPBC:   
    ld  ix,sWCB0
    call    CLS_TW
;   ld  l,(ix+18)   ; buffer curs
;   ld  h,(ix+19)
    ld  hl,(sWCB0+18)
    ld  (var3),hl   ; save old buff curs 
    dec hl
    dec hl      
    ld  d,(ix+5)    ; vertical size ( nm str win ); search start string
    ld  bc,3000
ppb0:   ld  a,#0A
    cpdr    ; CP A,(HL) HL=HL-1 BC=BC-1 repeat until CP A,(HL) = 0 or BC=0
    jp  nz,ppb0
    ld  a,(ix+12)   ;buf
;   ld  a,(sWCB0+12)
    sub l
    ld  a,(ix+13)
;   ld  a,(sWCB0+13)
    sbc a,h 
    jr  nc,ppb3 
    dec d
    jr  nz,ppb0 ; next string..
    inc hl
;   inc hl
    jr  ppb4
ppb3:   
;   ld  l,(ix+12)   ;start buufer
;   ld  h,(ix+13)
    ld  hl,(sWCB0+12)   
ppb4:
ppb2:   ld  a,(hl)
    push    hl
    call    OUTC_TW
    pop hl
    inc hl
    ld  de,(var3)
    ld  a,l
    sub e
    ld  a,h
    sbc a,d
    jr  nz,ppb2

    call    LOAD_S
    ei
    ret 

; This routine applies color and timestamp parameters
APP_PA:
    ld  hl,PA_IC
    call    EXTNUM16
    ld  a,c
    rl  a
    rl  a
    rl  a
    rl  a
    and #F0
    ld  c,a
    ld  a,(SETIc)
    and #0F
    or  c
    ld  (SETIc),a
    ld  hl,PA_PC
    call    EXTNUM  ; Extract ASCII num
    ld  a,c
    and #0F
    ld  c,a
    ld  a,(SETIc)
    and #F0
    or  c
    ld  (SETIc),a

    ld  hl,PA_AIC
    call    EXTNUM  ; Extract ASCII num
    ld  a,c
    rl  a
    rl  a
    rl  a
    rl  a
    and #F0
    ld  c,a
    ld  a,(SETIc+2)
    and #0F
    or  c
    ld  (SETIc+2),a
    ld  hl,PA_APC
    call    EXTNUM  ; Extract ASCII num
    ld  a,c
    and #0F
    ld  c,a
    ld  a,(SETIc+2)
    and #F0
    or  c
    ld  (SETIc+2),a

    ld  hl,PA_TIMEST
    call    EXTNUM   ; Extract ASCII num
    ld  a,c
    ld  (t_stmp),a

    ret

; =======================================================================
; Templates and Variable Set 1 (< #8000) (for user intrfase)
; =======================================================================
S_U:        db  0
S_L:        db  #87

SYSMESS1:   db  "MSX IRC Client v1.0 by Pasha Zakharov",13,10,10,"$"
SM_fntBIOS: db  "Use system ROM font",13,10,"$"
SM_fntLOAD: db  "Custom font has beem loaded",13,10,"$"
SM_fntLERR: db  "Custom font can not be loaded. Error - ","$"
SM_D2MAPI:  db  "MSXDOS2 Mapper initialization - Ok",13,10,"$"
SM_D2M_TOT: db  "Total number of 16k RAM segments - ","$"
SM_D2M_FREE:    db  "Number of free 16k RAM segments  - ","$"
SM_UNAPI3:  db  "TCP/IP UNAPI implementation found of page 3",13,10,"$"
SM_UNAPIM:  db  "TCP/IP UNAPI implementation found in RAM segment, use mapper",13,10,"$"
SM_UNAPIR:  db  "TCP/IP UNAPI implementation found in ROM slot",13,10,"$"
SM_NOREC:   db  "No more free segment records",13,10,"$"
SM_NOSEG:   db  "No more free segment mapper",13,10,"$"
SM_NOMAPPER:    db  "DOS2 Mapper initialization - Failure!",13,10,"$"
SM_DOS1MAP: db  "Attempt of use Mapper on MSXDOS(1)",13,10,"$" 
SM_LostSeg: db  "This segment is lost",13,10,"$" 
SM_NOSERV:  db  "No more free Server control records",13,10,"$"
SM_HELP:    db  "Push F1 for help screen",13,10,"$"
SM_CONNS:   db  "Push F2 to connect irc server, F3 - disconnect, F4 - edit parametrs",13,10,"$"
SM_CONNEXIST:   db  "The connection with a server is already established",13,10,"$"
SM_QNA:     db  "/QUERY: if insufficient parameters",13,10,"$"

;--- User Parametr's

;PA_PSERV   ds  256
;--- Words param
WRDPA:      dw  WRDPA1,PA_SERVER,WRDPA2,PA_PORT
        dw  WRDPA3,PA_SRVPASS,WRDPA4,PA_NICK
        dw  WRDPA5,PA_USER,WRDPA6,PA_ANICK,WRDPA7,PA_FONT
        dw  WRDPA8,PA_IC,WRDPA9,PA_PC,WRDPA10,PA_AIC
        dw  WRDPA11,PA_APC,WRDPA12,PA_TIMEST,0
WRDPA1:     db  7,"server ",%0001
WRDPA2:     db  5,"port ",%0010
WRDPA3:     db  8,"srvpass ",%0100
WRDPA4:     db  5,"nick ",%1000
WRDPA5:     db  5,"user ",%10000
WRDPA6:     db  8,"altnick ",%100000
WRDPA7:     db  5,"font ",%1000000
WRDPA8:     db  6,"ink_c ",0
WRDPA9:     db  8,"paper_c ",0
WRDPA10:    db  7,"aink_c ",0
WRDPA11:    db  9,"apaper_c ",0
WRDPA12:    db  11,"timestamp ",0 
    
SETI:   ;   db  #99,
    db  SETIe - SETI -1
    db  #04,0 + #80       ; text2
    db  #70,1 + #80       ;
    db  #08,8 + #80       ;
    db  #80,9 + #80       ; width 80
    db  #03,2 + #80       ; base PNT
    db  #02,4 + #80       ; base PGT
    db  #00,10 + #80      ; base CT
    db  #2F,3 + #80       ;
SETIc:  db  #1F,7 + #80       ; inc/paper   color
    db  #1D,12 + #80      ; flash inc/paper color
    db  #70,13 + #80      ; time flip/flop (flash)
    db  #00,45 + #80      ; VRAM / ERAM bank
    db  #00,14 + #80      ; bank = 0
SETIe:      

sys_p2  db  #81
use_p2  db  #84
    db  #85
    ds  10
bbuf    ds  2
lenb    ds  2
bbuf1   ds  2
lenb1   ds  2
bbuf2   ds  2
lenb2   ds  2

t_stmp  db  0
s_ins   db  #FF

var2    dw  0
var3    dw  0
nicu    db  0
stopC   db  1
fntsour db  0
fferr   db  0
point   dw  0
ttvar   dw  0
serv1   db  0
serv2   db  0
serv3   db  0
segsRS  db  0   ; - map segment parental server save
TMUV    dw  0,80,160,240,320,400,480,560,640,720
    dw  800,880,960,1040,1120,1200,1280,1360,1440,1520
    dw  1600,1680,1760,1840,1920,2000,2080,2160,2240,2320

;Windows control block
;
;
WCB:                    ; 24b
    db  0   ; 0    0 - VRAM 1 - EXPANDED VRAM
    db  0   ; 1    00000bbb A16, A15, A14 (n - 16b page)
;   dw  10+3*80 ; 2 3  00hhhhhhlllllllll A13-A0 VRAM
    dw  1+80
;   db  35  ; 4    horizontal size 1-80
;   db  15  ; 5    vertical size   1-26
    db  78
    db  24
    db  0   ; 6    cursor horizontal posit
    db  0   ; 7    cursor vertical posit    
    db  1   ; 8    0 - drop end string 1 - auto LF
    db  1   ; 9    0 - drop end windows 1 - auto scroll
    db  0   ; 10   0 - invisible cursor 1 - visible cursor
    db  1   ; 11   0 - disable VRAM load, RAM Buffer only
    dw  #9000   ; 12   buffer
    dw  #C000   ; 14   max buffer
    dw  #9000   ; 16   buffer end
    dw  #9000   ; 18   cur
    db  0   ; 20   0 - clear new string 1 - not clear
    db  0   ; 21   0 - normal 1- out of buffer
    dw  #9000   ; 22   last string
WCB0:   ; for help screen    ; 24b
    db  0,0
    dw  80
    db  80,24
    db  0,0
    db  1,1
    db  0
    db  0   ; disable VRAM load
    dw  #9000
    dw  #C000
    dw  #9000
    dw  #9000
    db  1,0
    dw  #9000

WCB01:  ; for server and query screen    ; 24b
    db  0,0
    dw  80
    db  80,24
    db  0,23
    db  1,1
    db  0
    db  0   ; disable VRAM load
    dw  #BFFF
    dw  #C000
    dw  #C000
    dw  #C000
    db  1,0
    dw  #BFFF

WCB1:   ; for cannel screen    ; 24b
    db  0,0
    dw  80
    db  80-16,24
    db  0,23
    db  1,1
    db  0
    db  0   ; disable VRAM load
    dw  #BFFF
    dw  #C000
    dw  #C000
    dw  #C000
    db  1,0
    dw  #BFFF

WCB2:   ; for nick screen    ; 24b
    db  0,0
    dw  80+80-15
    db  15,24
    db  0,0
    db  0,0 ; no auto CR LF, no auto scroll
    db  0
    db  0   ; disable VRAM load
    dw  #8C00
    dw  #8EFF
    dw  #8C00
    dw  #8C00
    db  1,0
    dw  #8C00

WCB3:   ; for input string    ; 24b
    db  0,0
    dw  80*25
    db  80,1
    db  0,0
    db  1,1
    db  1
    db  1   ; enable VRAM load
    dw  #8F00
    dw  #C000
    dw  #8F00
    dw  #8F00
    db  1,0
    dw  #8F00

WCB4:   ; for system info     ; 24b
    db  0,0
    dw  80*1
    db  80-32-3,24 ;80+80-32-3,24
    db  0,0
    db  1,1
    db  1
    db  1   ; enable VRAM load
    dw  #9000
    dw  #C000
    dw  #9000
    dw  #9000
    db  1,0
    dw  #8F00
WCB5:   ; for page select     ; 24b
    db  0,0
    dw  80+80-32-2 
    db  34,24
    db  0,0
    db  0,0 ; no auto CR LF, no auto scroll
    db  1
    db  0   ; disable VRAM load
    dw  #8C00
    dw  #8EFF
    dw  #8C00
    dw  #8C00
    db  1,0
    dw  #8C00
;--- File Control Block
FCB:    db  0
    db  "MSXIRC  INI"
    db  0,0,0,0,0,0,0,0,0,0
    db  0,0,0,0,0,0,0,0,0,0
    db  0,0,0,0,0,0,0,0

FCBhelp:
    db  0
    db  "MSXIRC  HLP"
    ds  28
var1:   dw  0
helpdes db  "Help ",0
;SIND:  ds  80

tnicks: db  "ptero xn_ @Zhuchka DeCadance Phantasm nick001 nick002 longnick__1234567890_001 longnick__1234567890_002 nick003 nick004 nick006 ",0
tnickse:
tsb:    dw  0   ; counter
    dw  0   ; pointer
    ds  512 ; send buffer

chsas:  dw  1255


;nick name  -32b max
;channel name   -50b max



; Screen buffers

fulls   equ #8000   ; 16kB segment for one channel or privat
;#8000-886F PNT buffer
;#8870-89FF free area for variable parametr
;#8A00-8B0E CT buffer
;#8C00-8DFF = 512 b nick name buffer
;#8E00-8FFF = -512
;#9000-BFFF = 12287 free bytes for text buffer
sWCB0   equ #8870
sWCB1   equ #8870+24
sWCB2   equ #8870+48
oldcur  equ #8870+48+24 ; (3)
segs    equ #8870+48+24+3 ; (1) #88BB
segsR   equ #8870+48+24+3+1 ; (1) - map segment parental server
nlnew   equ #8870+48+24+3+1+1 ; (1) - flag new nickname list
w0new   equ #8000+2 ; nlnew+1
w1new   equ w0new+2
    END
; ?????? ????? ?????!   

