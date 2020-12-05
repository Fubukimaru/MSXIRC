; MSX IRC Client v 1.1
; Original Client by Pasha Zakharov
; Reviewed and fixed by Oduvaldo Pavan Junior (ducasp / ducasp@gmail.com)
;
; v1.0 - Original Release by Pasha Zakharov
;
; v1.1 - Release by Oduvaldo Pavan Junior
;       -> Fixes to the UNAPI calling code so it works with ROM UNAPI's
;       -> Fixes not being able to connect to server when using a INI file as
;          input parameter
;       -> Fixes DOS1 Mapper support when no mapper present
;       -> DOS1 Mapper wouldn't allow usage of #FF segment for our program, it
;          a valuable segment, one more window and no reason to do so
;       -> Fixes possible crash with DOS1 mapper support and Mapper UNAPI, it
;          was assuming it always use last mapper segment in DOS1, this is not
;          a rule even though it works for Obsonet that does that :)
;       -> Changed the exit function, so it closes open connection as well
;       -> Updated so the main menu won't show remainings of the cursor or of
;          the SIAT :)
;       -> Improvement on the Help File
;       -> Text strings review / correction
;       -> Clean-up of code
;       -> Commentaries about code functionality
;
; How this IRC Client works?
; That is what I ( Ducasp ) found out so far:
;
; This absolutely require a MSX 2 at least as it works on text mode 2.
;
; It also needs a memory mapper with at least 2 segments free, as each "window"
; (channel, system, private message) occupies a segment to buffer what has
; been received. More free segments means more windows can be open! :)
;
; It uses a custom/direct I/O to VDP after setting it to text mode 2, so all
; routines that put text on screen are customized. Those routines are driven by
; WCB's (Window Control Block), that define start VDP address, buffer address,
; etc...
;
; A WCB also tells if its contents are going to be dumped on VDP or not. If not
; , all content just goes to system / segment RAM. This allows each window to
; be updated even if not being displayed, and select which one is currently 
; on screen.
;
; How the lower bar works?
;
; That is a neat idea... TEXT2 alternative mode uses 212 scan lines, which if
; you consider each character is 8 bits tall, means you have 26.5 lines...
; No kidding, so you end-up with a 27th line that only the upper portion of it
; is visible. So, it is a useless line where you can't have full characters...
; Only that Pasha had this nice idea, use it to show symbols, 80, meaning the
; 27th line will contain special characters from his customized font that are
; a small square for unused, a stilized S for the Server Window, a stilized H
; for the Help Window, a q for private messages (Query) and a C for channels.
; Also, the selected one uses the attribute of alternate color, so it is
; very nice interface. By hitting CTRL+LEFT or CTRL+RIGHT you navigate all the
; open windows.
;
; The special sauce of it is SSIAT, 80 bytes for the 27th line that is updated
; by SSIA function, also, after it, there 10 bytes, which is used to set the
; attributes of the patterns used on the 27th line, so, of those 80bits, the
; bits that are set are the ones that will show in alternate color, hilighting
; the selection.
;
; So, SSIA function uses MAPTAB, which is 80 words (160 bytes) table, where the
; LSB of the word (1st byte) is the functionality of that position ( 'S' for
; Server Window, 'H' for Help Window, 'C' for a Channel Window and finally 'Q'
; for the Private Message (Query) Window, otherwise, it is 0 meaning empty. The
; MSB of the word (2nd byte) is the segment assigned to that Window, that must
; be selected at page 2 when updating or showing it.
;
; How the segment/Window list is built?
;
; Basically list is built at 0x9000 by BFSegT, and is held in Main Menu / App
; segment memory.
; It is composed of window/segment number in HEX, then the printable window/
; segment number, and the window title. Each record is 56 bytes long. sWCB1
; 17th byte holds a count of how many windows/nicknames are listed, having a
; different behavior than other WCB's.
;
; sWCB0 -> Will hold the WCB that is currently being showed on the Screen, be
; it the Main Menu, Server Control, Query or Channel Windows.
;
; sWCB1 -> Hold the WCB for either the Window list used by Main Menu or Nick
; list used by Channel Windows.
;
; sWCB2 -> Hold the WCB for the input box in the Server Control, Channel and
; Query windows.

;--- Macro for printing a $-finished string
;--- Changes DE and C
macro print data
    ld  de,data
    ld  c,_STROUT
    call    DOS
    endm

;--- Constants

;--- Code legibility constants
NICK_COUNT:         equ 23              ; when sWCB1 is selected, this holds the nick count
WINDOW_COUNT:       equ 16              ; when sWCB1 is selected, this holds the window count
WIN_LIST_BUILD_TMP: equ 17              ; when sWCB1 is selected, this holds a temporary count of scanned segment entries
WIN_LIST_ITEM_SEL:  equ 10              ; when sWCB1 is selected, this holds the window list item that is currently selected
WIN_LIST_SHIFT:     equ 22              ; when sWCB1 is selected, this holds how many itens should skip before start rendering the list
WIN_CR_CLR_CURS_ON: equ 20              ; If on CR will clear from current cursor position on before returning to home X position
WIN_AUTO_SCROLL:    equ 9               ; If windows Auto Scrolls or not
WIN_AUTO_LF:        equ 8               ; If windows Auto Line Feed or not
WIN_BUFF_STS:       equ 21              ; WCB Buffer Status - 0 normal or 1 out of Buffer
WIN_H_POS:          equ 6               ; H cursor position a given WCB
WIN_V_POS:          equ 7               ; V cursor position a given WCB
WIN_V_SIZE:         equ 5               ; maximum number of lines for a given WCB
WIN_H_SIZE:         equ 4               ; maximum number of columns for a given WCB
WIN_WRITE_TO_VRAM:  equ 11              ; if this WCB is being written to VRAM (showing on screen)
WIN_RAM_B_ADD:      equ 12              ; Address of the RAM buffer for our window
WIN_RAM_B_ADD_LSB:  equ 12              ; Address of the RAM buffer for our window, LSB
WIN_RAM_B_ADD_MSB:  equ 13              ; Address of the RAM buffer for our window, MSB
WIN_RAM_B_CUR:      equ 18              ; Address of the current position in RAM buffer for our window
WIN_RAM_B_CUR_LSB:  equ 18              ; Address of the current position in RAM buffer for our window, LSB
WIN_RAM_B_CUR_MSB:  equ 19              ; Address of the current position in RAM buffer for our window, MSB
WIN_RAM_B_END:      equ 16              ; Address of the end of RAM buffer for our window
WIN_RAM_B_END_LSB:  equ 16              ; Address of the end of RAM buffer for our window, LSB
WIN_RAM_B_END_MSB:  equ 17              ; Address of the end of RAM buffer for our window, MSB
WIN_L_STR_ADD:      equ 22              ; Address of the last string printed
WIN_L_STR_ADD_LSB:  equ 22              ; Address of the last string printed, LSB
WIN_L_STR_ADD_MSB:  equ 23              ; Address of the last string printed, MSB
WINDOW_VR_ADD:      equ 2               ; VRAM address to start writing for this WCB
WINDOW_VR_ADD_LSB:  equ 2               ; VRAM address to start writing for this WCB, LSB
WINDOW_VR_ADD_MSB:  equ 3               ; VRAM address to start writing for this WCB, MSB

;--- DOS function calls
DOS:                equ #0005           ; DOS Function call entry
_TERM0:             equ #00             ; DOS Program terminate
_CONIN:             equ #01             ; Console input with echo
_CONOUT:            equ #02             ; Console output
_DIRIO:             equ #06             ; Direct console I/O
_INNO:              equ #07             ; Direct console I/O, but locks waiting for input
_INNOE:             equ #08             ; Console input without echo
_STROUT:            equ #09             ; String output
_BUFIN:             equ #0A             ; Buffered line input
_CONST:             equ #0B             ; Console status
_FOPEN:             equ #0F             ; Open file
_FCLOSE             equ #10             ; Close file
_SDMA:              equ #1A             ; Set Disk Transfer Address
_RBREAD:            equ #27             ; Random block read
_TERM:              equ #62             ; Terminate with error code
_DEFAB:             equ #63             ; Define abort exit routine
_DOSVER:            equ #6F             ; Get DOS version
_GETDATE:           equ #2A             ; Get Date 
_GETTIME:           equ #2C             ; Get Time

;--- Will mess with AF in addition to any registers of BIOS function being called
macro bios  bioscall
    rst #30                             ; Interslot call
    db  0                               ; Slot 0
    dw  bioscall                        ; Function
    endm

;--- BIOS functions calls
RDSLT:              equ #000C           ; Reads value of an address in another slot
CALSLT:             equ #001C           ; Interslot Call
ENASLT:             equ #0024           ; Switch a given page to a given slot
WRTVDP:             equ #0047           ; Write data in VDP Register C=R, B=Data
RDVRM:              equ #004A           ; Reads from VRAM
WRTVRM:             equ #004D           ; Writes in VRAM
FILVRM:             equ #0056           ; Fill VRAM with a value
LDIRVM:             equ #005C           ; Block Transfer RAM -> VRAM
INITXT:             equ #006C           ; Initialize Screen 0
CHGET:              equ #009F           ; One character input (blocking)
INLIN:              equ #00B1           ; Store keys in buffer until STOP or ENTER is pressed
BREAKX:             equ #00B7           ; Test status of CTRL+STOP
BEEP:               equ #00C0           ; BEEP BEEP
CLS:                equ #00C3           ; Clear screen
POSIT:              equ #00C6           ; Move cursor to specified position
GTSTCK:             equ #00D5           ; Returns joystick status

;--- MSX System Variables
TPASLOT1:           equ #F342           ; Slot Address of RAM  in page 1 (DOS Only)
linnl40:            equ #F3AE           ; Screen Width of Screen 0
ARG:                equ #F847           ; Argument for MATHPACK, also used by UNAPI
timer:              equ #FC9E           ; JIFFY, increases every VDP VSYNC interrupt
EXTBIO:             equ #FFCA           ; EXTBIO Hook, to access EXTBIO functions like UNAPI


;--- Scan code special buttons
ESC_:               equ 27
UP_:                equ 30
DOWN_:              equ 31
LEFT_:              equ 29
RIGHT_:             equ 28
TAB_:               equ 9
BS_:                equ 8
SELECT_:            equ 24
CLS_:               equ 11
INC_:               equ 18
DEL_:               equ 127

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
    org #100
    ld  hl,(chsas)                      ; Load Reference Value from memory
    ld  de,1255                         ; This is what the value should be
    xor a                               ; Clear flags
    sbc hl,de                           ; Compare
    jr  z,MSXIRCST0
    ; If not zero, corrupt, so exit
    print   CORRUPTFILE_S               ; Ok, tell corrupt file
    ret
MSXIRCST0:
    ld  a,#00                           ; slot bios 0
    ld  hl,#002D                        ; Check MSX Version
    bios    RDSLT                       ; Read from bios
    or  a
    jr  nz,MSXIRCST1
    ; If zero, MSX1, need MSX2 at least
    print   MSX1_S                      ; Ok, tell it is MSX1 and need MSX2
    ret
MSXIRCST1:
;--- Checks the DOS version and establishes variable DOS2
    ld  c,_DOSVER
    call    DOS                         ; Get DOS version
    or  a
    jr  nz,NODOS2                       ; NZ on A means it is not MSX DOS
    ld  a,b
    cp  2
    jr  c,NODOS2                        ; B<2 means it is older than MSX DOS 2
    ld  a,#FF
    ld  (DOS2),a                        ; #FF for DOS 2, 0 for DOS 1
    print   USEDOS2_S                   ; Ok, tell we recognize we are under DOS2
NODOS2:
;--- Prints the presentation
    print   PRESENT_S
    print   INFO_S
    ld  a,(DOS2)
    or  a
    jp  nz,LsSPD2                       ; If we've detected DOS2, use DOS2 routines
    ;--- DOS1 not mapper support
    call    INIMAPDOS1                  ; And try to initialize it
    ld  a,(freemaps)                    ; How many free segments?
    cp  2
    jr  c,NOMAPPER                      ; Yeah, we need at least 2 free segments to be useful, one for server and one for a chat window
    jr  MAPPERDONE                      ; Skip dos 2 routines and go on
LsSPD2:
    ;--- Get mapper support routines in DOS 2
    ld  de,#0402                        ; Device 4 is DOS2 Mapper, Function 2 is get mapper jump table
    xor a
    call    EXTBIO                      ; Call it, A will hold number of segments of main mapper, B the slot of it, C how many free segments we have in it and HL the jump table address
    or  a
    jp  nz,MAPPER2                      ; If has any segment, follow through
NOMAPPER:
    ; Ok
    print   SM_NOMAPPER
    ret                                 ; No mapper, no play
MAPPER2:
    ld  (totmaps),a                     ; Save total segments
    ld  a,c
    ld  (freemaps),a                    ; Save free segments
    cp  2
    jr  c,NOMAPPER                      ; Yeah, we need at least 2 free segments to be useful, one for server and one for a chat window
    ld  de,ALL_SEG
    ld  bc,16*3
    ldir                                ; Copy the jump table to ALL_SEG
MAPPERDONE:
;--- Time to Check UNAPI / TCPIP
    ;--- Search a TCP/IP UNAPI implementation
    ld  hl,TCPIP_S                      ; API specification identifier (TCP/IP)
    ld  de,ARG                          ; Loaded in F847
    ld  bc,15                           ; Copy 15 bytes
    ldir
    ;--- Check how many TCP/IP implementation are available
    xor a                               ; A = 0
    ld  b,a                             ; B = 0
    ld  de,#2222                        ; UNAPI EXTBIO CALL
    call    EXTBIO
    ld  a,b                             ; B has number of implementations found
    or  a                               ; 0 ?
    jp  z,IUNAPID                       ; And done looking for UNAPI
    ;--- Ok, there is at least one, so let's get the first one 
    ld  a,1                             ; 1-st API (identifier = TCP/IP)
    ld  de,#2222                        ; UNAPI EXTBIO CALL, get details of 1-st Implementation
    call    EXTBIO                      ;A=slot , B=segment (#FF=not RAM), HL=enter if #C000-FFFF
                                        ; page - 3 then A,B register not use  
    ;--- Setup the UNAPI calling code
    ld  (CALL_um+8),hl                  ; At this point we don't know if it is page 3, mapper or
    ld  (CALL_U+5),hl                   ; rom, so save it for both mapper and rom routines
    ld  c,a                             ; Save slot in C
    ld  a,h
    cp  #C0                             ; Is address in page 3?
    ld  a,c                             ; Slot back in A
    jr  c,NO_UNAPI_P3                   ; If not in page 3, interslot call or ramhelpr call
    ;--- Page 3 UNAPI
    ld  a,#C3
    ld  (CALL_U),a                      ; (JP XXXX (hl))
    ld  (CALL_U+1),hl                   ; Page 3 is just a direct call, and its return return direct to the caller
    ld  hl,SM_UNAPI3
    jr  OK_SET_UNAPI                    ; And that is all we need
NO_UNAPI_P3:
    ;--- Ok, it is either a mapper or rom UNAPI
    ld  (CALL_U+2),a                    ; Slot UNAPI ROM implementation, just in case
    ld  a,b
    cp  #FF                             ; If segment is FF, it means ROM
    jr  nz,NO_UNAPI_ROM                 ; So if not FF, let's prepare CALL_U for mapper routines
    jr  OK_SET_UNAPI                    ; And done
NO_UNAPI_ROM:
    ;--- UNAPI is in ram segment, so we need to update CALL_um that is the call for memory mapper
    ld  (CALL_um+2),a                   ; Mapper segment that UNAPI is installed
    ld  a,(TPASEG1)                     ; Our current segment, to switch back after calling UNAPI
    ld  (CALL_um+12),a                  ; Put into CALL_um
    ; Ok, the mapper segment needs to be reserved if in DOS1, otherwise it will be overwritten
    ld  a,(DOS2)
    or  a
    jp  NOT_DOS1                        ; If not on dos 1, no need to care
    ; Ok, DOS1, let's reserve the segment used by UNAPI
    ld  a,(CALL_um+2)                   ; Mapper segment for UNAPI
    ld  e,a                             ; Save segment number to allocate in E
    and %00000111                       ; Remainder of division per 8, basically the bit number in the MAP tap
    ld  b,a                             ; Save in B
    xor a                               ; A and Carry 0
    ld  d,a                             ; D = 0
    ld  a,e                             ; Segment number in A
    rra
    rra
    rra
    and %00011111                       ; Divide by 8, so this is the MAPTAB index
    ld  e,a                             ; Save MAPTAB index in E, D is o
    ld  hl,EMAPTAB
    add hl,de                           ; HL now has the MAPTAB for byte for this segment
    xor a
    scf                                 ; Carry 1, A = 0, our OR mask to set used segment
    inc b                               ; For bit 0, need to do it once, bit 2? three times... So inc counter
D1RAMUNAPIALLOC:
    rla
    djnz    D1RAMUNAPIALLOC             ; A will have the bit masked (0)
    or  (hl)
    ld  (hl),a                          ; Mask the MAP tab occupying the segment 
    ld  a,(freemaps)                    ; Get free segments
    dec a
    ld  (freemaps),a                    ; Save free segments
    cp  2                               ; How many free segments?
    jp  c,NOMAPPER                      ; Yeah, we need at least 2 free segments to be useful, one for server and one for a chat window, less than that don't even bother
NOT_DOS1:
    ld  hl,CALL_um
    ld  de,CALL_U
    ld  bc,18
    ldir                                ; Overwrite CALL_U with CALL_um, and we are ready to work with MM UNAPI

    jp  OK_SET_UNAPI                    ; And done
IUNAPID:
    ;--- If here, no TCPIP UNAPI has been found
    print   NOTCPIP_S                   ; No TCP/IP found message
    ret
OK_SET_UNAPI:
;--- Checks if there are command line parameters.
;    If not, try to use default ( MSXIRC.INI )
    ld  a,1
    ld  de,BUFFER                       ; Our 512 bytes buffer
    call    EXTPAR                      ; Get 1st parameter, it must be ini file name
    jr  c,NOPARA                        ; If no parameter, keep going with the default
; convert filename.ext to FILENAMEEXT 8+3
    ld  hl,BUFFER
    ld  DE,FCB+1
    call    CFILENAME                   ; Will convert, if need, from "name.ext" to NAME    EXT [8+3]
NOPARA:
;--- Open file .ini, set user parameter's
    ld  de,FCB
    ld  c,_FOPEN
    call    DOS                         ; Filename in FCB
    or  a
    ld  de,NOINIF_S
    jp  nz,PRINT_TERML                  ; If error opening, print error message and terminate
    ld  de,BUFFER
    ld  c,_SDMA
    call    DOS                         ; Our 512 bytes buffer is now being used to store file transfers
    ld  hl,1
    ld  (FCB+14),hl                     ; set record size = 1 byte
    ld  de,FCB
    ld  hl,512                          ; read 512 records
    ld  c,_RBREAD
    call    DOS
    ld  (LBUFF),hl                      ; Number of bytes read in LBUFF
    ld  de,BUFFER
    add hl,de                           ; HL has end of buffer
    xor a
    ld  (hl),a                          ; 0 -> end record with null termination
    ld  de,FCB
    ld  c,_FCLOSE
    call    DOS                         ; Close the file, bye bye and thanks for all the fish!
    ;--- Extract user parameters
    ld  bc,(LBUFF)
    ld  a,b
    or  c
    jp  z,CHECKSL                       ; If LBUFF is zero, no records
    ld  hl,BUFFER
    ld  iy,WRDPA
    call    G_PA                        ; Parse and extract parameters
    ld  a,(PA_ST)
    and %01000000                       ; Do we have a font to load?
    call    nz,LOADFONT                 ; If yes, load it
;--- Apply color and timestamp parameters from .INI (or use the default ones in RAM)
    call    APP_PA
CHECKSL:
    ;--- If we are in DOS 2, set the abort exit routine
    ld  a,(DOS2)
    or  a
    ld  de,EXIT                         ; From now on, pressing CTRL-C
    ld  c,_DEFAB                        ; has the same effect of Q in the main menu
    call    nz,DOS                      ; (aborts the TCP connection and terminates program)
    ei
    ld  b,60
Lsw:
    halt
    djnz    Lsw                         ; Wait 1s...
    call    INISCREEN                   ; Initialize screen amd clear tables as needed
;--- 1st screen ( info )
;--- clear screen
    call    CLS_G                       ; Initialize / Clear Screen Buffers
    call    LOAD_S                      ; And load screen buffer in VRAM
; initialize system window in RAM
    ld  hl,WCB4                         ; Parameters for system Window
    ld  de,sWCB0                        ; Go to Window 0
    ld  bc,24
    ldir
; initialize select page window in RAM
    ld  hl,WCB5                         ; Parameters for page select that goes in system Window
    ld  de,sWCB1                        ; Go to Window 1
    ld  bc,24
    ldir
; position BIOS cursor
    ld  hl,#0019                        ; v-25
    bios    POSIT
; print system information
    ld  ix,sWCB0
    ld  bc,0
    ld  (sWCB0+6),bc                    ; set cursor at 0x0
    ld  hl,SYSMESS1
    call    PRINT_TW                    ; And print our welcome message in system window
    ld  a,(PA_ST)
    and %01000000
    jr  z,Ls01                          ; Using a custom font?
    ld  a,(fntsour)
    or  a
    jr  z,Ls02                          ; Yes, but was it loaded?
    ld  hl,SM_fntLOAD
    call    PRINT_TW                    ; Yes, print a message about it then...
    jp  LsSP1                           ; And keep going
Ls02:
    ld  hl,SM_fntLERR
    call    PRINT_TW                    ; Font not loaded, so, error message is printed
    ld  a,(fferr)
    add a,"0"
    call    OUTC_TW                     ; And the error code
    ld  a,13
    call    OUTC_TW
    ld  a,10
    call    OUTC_TW                     ; And jump line
Ls01:
    ld  hl,SM_fntBIOS
    call    PRINT_TW                    ; Tell we are using the bios font
LsSP1:
    ld  hl,SM_D2MAPI
    ld  a,(DOS2)
    or  a
    jp  nz,LsSPD1.2                     ; If we've detected DOS2, using DOS 2 routines
    ;--- DOS1 not mapper support
    ld  hl,SM_DOS1MAP
LsSPD1.2:
    call    PRINT_TW                    ; Tell the type of mapper routines being used
    ld  hl,SM_D2M_TOT
    call    PRINT_TW                    ; And let's detail total segments
    ld  d,0
    ld  a,(totmaps)
    ld  e,a
    or  a                               ; If A = 0 and we are here, it is dos 1 with a 4MB Mapper
    jr  nz,NOT4MONDOS1
    ld  de,#100                         ; if here 256 segments available
NOT4MONDOS1:
    ld  hl,BUFFER
    ld  b,3
    ld  c," "
    ld  a,%00001000
    call    NUMTOASC
    call    PRINT_TW                    ; Total number of segments on screen
    ld  a,13
    call    OUTC_TW
    ld  a,10
    call    OUTC_TW                     ; Jump line
    ld  hl,SM_D2M_FREE
    call    PRINT_TW                    ; Now free segments
    ld  d,0
    ld  a,(freemaps)
    ld  e,a
    ld  hl,BUFFER
    ld  b,3
    ld  c," "
    ld  a,%00001000
    call    NUMTOASC
    call    PRINT_TW                    ; Number of free segments on screen
    ld  a,13
    call    OUTC_TW
    ld  a,10
    call    OUTC_TW                     ; Jump Line
    call    GET_P2                      ; Check the segment on page 2 (0x8000-0xBFFF)
    ld  (P2_sys),a                      ; And save it in our variable
    call    GET_P1                      ; Get segment for page 1 (0x4000-0x7FFF)
    ld  (TPASEG1),a                     ; Save it in TPASEG1 to make sure it is restored
    ld  ix,sWCB0                        ; System Message Window
    ld  hl,SM_BASICHLP
    call    PRINT_TW                    ; Print a basic help message


;***************************************************************
;   Root enter main program
;   System info, select work segment's open/close segment,s
;   SYS_S is a point to always go back to the previous segment
;   When starting it just select segment 0, which I believe is
;   the System Message Window
;***************************************************************
SYS_S:
    call    CSIA                        ; Make sure we do not get attribute on the lower 27th line
    ld  a,(segp)                        ; The segment that was executing (first time will be 0)
    ld  (segsel),a                      ; And make it selected
SYS_S1:
    ld  ix,sWCB0                        ; Main Screen Window
    ld  a,(P2_sys)                      ; The Segment of page 2 of our application
    call    PUT_P2                      ; Make sure it is paged
    call    BFSegT                      ; Buffer Segments Information
    call    BOSegT                      ; Move it to the screen buffer
    call    LOAD_S                      ; And update screen from buffer

; draw attribute cursor segment select (ix+WIN_LIST_ITEM_SEL) 1..24 (0-off)
    ld  ix,sWCB1                        ; Secondary (Selection) Window
    call    CLAT_C_N                    ; Clear the attributes of the secondary window (either a nick list or a window list go there)
    call    SETAT_S                     ; Generate the alternate color for what is selected
    call    LOAD_SA                     ; And now send that to the VDP

LsSPW:
    call    TCPSEP                      ; Check if there is data from server, if there is a connection
    call    CLOCK                       ; Print date and time on top right corner of the screen
    ld  c,_CONST
    call    DOS                         ; Check if key was pressed
    or  a
    jr  z,LsSPW                         ; If no key pressed, just loop
    ; key was pressed
    ld  c,_INNO
    call    DOS                         ; Get key
    ld  b,a                             ; and move key to B
    ld  ix,sWCB0                        ; Main Window WCB in IX
    ld  hl,#FBEB
    ld  a,b
    bit 5,(hl)                          ; Was F1 pressed?
    jp  z,Ls_help                       ; Go to Help Instance
    cp  #0D                             ; Enter?
    jp  z,Ls_GoTo                       ; Go to the selected Window
    cp  LEFT_
    jp  z,LsDEC                         ; If left decrease selection of selected window
    cp  UP_
    jp  z,LsDEC                         ; Same for Up
    cp  DOWN_
    jp  z,LsINC                         ; If down increase selection of selected window
    cp  RIGHT_
    jp  z,LsINC                         ; Same for right
    cp  27
    jp  z,Ls_ESC                        ; If ESC try to go back to previous window
    and %01011111                       ; Uppercase
    cp  "S"
    jp  z,SERV_C                        ; If S or s, server Window
    cp  "Q"
    jp  z,EXIT                          ; If Q or q, exit routine
    jp  LsSPW                           ; Otherwise, loop

;--- Go to the segment / window on our left side
S_LEFT:
    call    CURSOFF
    ld  a,(segp)
    ld  b,a                             ; Save current segment in B
S_L2:
    dec b
    ld  a,#FF
    cp  b
    jr  nz,S_L3                         ; Safe guard, if segment greater than 0 ok, but if 0, the left will wrap-around to the 80th segment, segment 79
    ld  b,79
S_L3:
    ld  a,b                             ; Segment - 1 in A
    rla                                 ; Multiply it by 2, MAPTAB is comprised of pairs
    ld  e,a                             ; E has the segment ID * 2
    ld  d,0                             ; and D must b 0, 79*2 < 0xFF
    ld  hl,MAPTAB
    add hl,DE                           ; Get the MAPTAB entry 
    ld  a,(hl)
    or  a                               ; Is it an existing segment?
    jr  z,S_L2                          ; nope, decrease and try again
;--- Found a segment to our left, could be our own... 
    ld  a,b
    ld  (segsel),a                      ; Save as the segment selected
    jp  Ls_GoTo                         ; And go to it

;--- Go to the segment / window on our right side
S_RIGHT:
    call    CURSOFF
    ld  a,(segp)
    ld  b,a                             ; Save current segment in B
S_R2:
    inc b
    ld  a,79
    cp  b
    jr  nc,S_R3                         ; Safe guard, if segment lower than 80 ok, but if 80, the right will wrap-around to the 1st segment, segment 0
    ld  b,0
S_R3:
    ld  a,b                             ; Segment + 1 in A
    rla                                 ; Multiply it by 2, MAPTAB is comprised of pairs
    ld  e,a                             ; E has the segment ID * 2
    ld  d,0                             ; and D must b 0, 79*2 < 0xFF
    ld  hl,MAPTAB
    add hl,DE                           ; Get the MAPTAB entry 
    ld  a,(hl)
    or  a                               ; Is it an existing segment?
    jr  z,S_R2                          ; nope, increase and try again
;--- Found a segment to our right, could be our own... 
    ld  a,b
    ld  (segsel),a                      ; Save as the segment selected
;--- And go to it
;--- DO NOT ADD FUNCTIONS HERE, or, if you do, need to add a jp Ls_Goto above
; Go to on selected segment (channel/Query/Server/Help)
Ls_GoTo:
    call    CLAT_C_N                    ; Clear the attributes of the secondary window (either a nick list or a window list go there)
    call    LOAD_SA                     ; And send color attributes of secondary window to the VDP
    xor a                               ; Clear flags
    ld  a,(segsel)                      ; Segment selected in A
Ls_go1:
    rla                                 ; Multiply by 2
    ld  e,a
    ld  d,0                             ; DE has MAPTAB offset
    ld  hl,MAPTAB
    add hl,DE                           ; Position of our segment in MAPTAB
    ld  a,(hl)                          ; Now let's identify it
    and %01111111
    cp  "H"
    jp  z,LsEnSH                        ; Prepare for Help Menu and then enter its loop
    cp  "C"
    jp  z,LsEnCS                        ; Prepare for Channel and then enter its loop
    cp  "S"
    jp  z,LsEnSS                        ; Prepare for Server Window and then enter its loop
    cp  "Q"
    jp  z,LsEnQS                        ; Prepare for Query (private message) Window and then enter its loop
    ld  a,(P2_sys)
    call    PUT_P2                      ; None, so back to our main menu, allocate app P2
;   ld  hl,SM_LostSeg
;   call    PRINT_TW                    ; The only time I saw this happen is if you hit enter without anything selected, so just ditch the message, not meaningful
    jp  LsSPW                           ; Main system menu loop

;--- Decrease selection on auxiliary window
LsDEC:
    ld  ix,sWCB1
    ld  a,(ix+WIN_LIST_ITEM_SEL)        ; Current selection
    cp  1
    jr  z,LsD1                          ; If one, do not decrease
    dec a
    ld  (ix+WIN_LIST_ITEM_SEL),a        ; Decrement it and save
    jp  LsD2
LsD1:
    ; Current selection was 1
    ld  a,(ix+WIN_LIST_SHIFT)           ; Is listing shifted?
    or  a
    jp  z,LsSPW                         ; If zero, not shifted, main system menu loop
    ; Yes, it is shifted
    dec a
    ld  (ix+WIN_LIST_SHIFT),a           ; Decrement shift and save
LsD2:
    ld  a,(ix+WIN_LIST_ITEM_SEL)        ; selection
    add a,(ix+WIN_LIST_SHIFT)           ; add shift
    ld  hl,#9000                        ; pointer to buffer
    ld  de,50+4+1                       ; Window Information Buffered size
LsD4:
    dec a                               ; Decrement
    jr  z,LsD3                          ; if 0, done
    add hl,de                           ; Next window information
    jr  LsD4                            ; loop until HL has the address of the first position to start our list
LsD3:
    ld  a,(hl)
    ld  (segsel),a                      ; The segment selected segment is saved
    jp  SYS_S1                          ; Back to redraw main system menu and then loop

;--- Increase selection on auxiliary window
LsINC:
    ld  ix,sWCB1
    ld  b,(ix+WIN_LIST_ITEM_SEL)        ; Current selection
    ld  c,(ix+WIN_LIST_SHIFT)           ; List shift
    ld  a,b
    add a,c                             ; add both to get the current item
    cp  (ix+WINDOW_COUNT)
    jp  nc,LsSPW                        ; if >=, no redraw, already in the last, just back to menu loop
    ld  a,b
    cp  (ix+WIN_V_SIZE)                 ; check if need to scroll
    jr  nc,LsI1                         ; If at last line, yeah, scroll
    ; No need to scroll
    inc a                               ; Just add 1 to the item selection
    ld  (ix+WIN_LIST_ITEM_SEL),a        ; Save it
    jr  LsD2                            ; Remaining is done in LsD2
LsI1:
    inc c
    ld  (ix+WIN_LIST_SHIFT),c           ; Ok, item selected will still be the last in the list, but now increase the list shift... :)
    jr  LsD2                            ; Remaining is done in LsD2

; Go back to last window
Ls_ESC:
    call    CLAT_C_N                    ; Clear the attributes of the secondary window (either a nick list or a window list go there)
    call    LOAD_SA                     ; And send color attributes of secondary window to the VDP
    xor a                               ; Clear flags
    ld  a,(segp)                        ; and we want to go to the segment that was being displayed before entering the main menu
    jp  Ls_go1                          ; there we go


LsEnSH:
;************************************
; Enter Help Segment
;************************************
    inc hl                              ; Jump to the mapper segment
    ld  a,(hl)                          ; now in A
    ld  (S_C),a                         ; And this is the main window segment
    ld  a,(segsel)
    ld  (segp),a                        ; segment selected saved in segp
    jp  Hmcw                            ; And help menu loop

Ls_help:
;*************************************
; Select Help Segment (Open if needed)
;*************************************
    call    CURSOFF
    ; clear kbd buffer (Fx Key) and Attributes of Nick/List area as Help occupies all screen
    call    CLKB
    call    CLAT_C_N
    ; Find help segment
    ld  a,"H"
    ld  de,helpdes                      ; Help Segment descriptor
    call    SrS                         ; Check if it already exists
    jr  c,Ls_h_noh                      ; If carry, nope
    ld  (S_C),a                         ; Otherwise, it is selected and it is "Server Control Window"
    jp  Hmcw                            ; And help menu loop
    ; Help segment not found, initialize help segment
Ls_h_noh:
    ; get free record
    call    ALL_REC
    ld  a,b
    ld  (segp),a                        ; This will be the current segment/window being displayed
    jp  c,NO_REC                        ; If carry, no more records!
    push    hl                          ; Save the MAP Table entry
    ld  a,0
    ld  b,a                             ; Primary mapper only
    call    ALL_SEG                     ; Request a user segment to be allocated from primary maper
    jp  c,NO_SEG                        ; If carry, failed to allocate
    pop hl                              ; Restore MAP Table entry
    ; set record to H status
    ld  (hl),"H"
    inc hl
    ; set segment mapper
    ld  (hl),a
    ; initialize Help Segment
    ld  (S_C),a                         ; Load it in screen control segment
    call    PUT_P2                      ; Select the segment in page 2
    call    CLS_G                       ; Clear the screen buffer as we are going to build the screen for our new segment
    ld  a,(segp)
    ld  (segs),a                        ; make it the selected segment
    ld  d,0
    ld  a,(segs)
    ld  e,a                             ; DE has segment #
    ld  hl,#8000
    ld  b,2
    ld  c,"0"
    ld  a,%00000000
    call    NUMTOASC                    ; Will convert the segment number in printable format

    ld  hl,#8000+3
    ld  (hl),"H"                        ; H identify Window as H type
    inc hl
    inc hl
    ld  de,helpdes                      ; Help Window descriptor
    ex  de,hl
    ld  bc,4
    ldir

    ld  hl,WCB0                         ; help WCB template
    ld  de,sWCB0                        ; will go to the main Window
    ld  bc,24
    ldir                                ; set WCB to segment
    ld  ix,sWCB0
; load help file
    ld  hl,FCBhelp+1+8+3                ; point past FCB filename
    ld  b,28
    xor a
LsHi2:
    ld  (hl),a
    inc hl
    djnz    LsHi2                       ; and reset FCB
    ld  a,(P2_sys)
    call    PUT_P2                      ; Put our APP segment back in P2
    ld  de,FCBhelp
    ld  c,_FOPEN
    call    DOS                         ; open the file
    ld  de,#9000
    ld  c,_SDMA
    call    DOS                         ; transfer area at 0x9000
    ld  hl,1
    ld  (FCBhelp+14),hl
    ld  de,FCBhelp
    ld  hl,#BFFF-#9000                  ; Read all we can in the buffer reserved area
    ld  c,_RBREAD
    call    DOS                         ; Execute read
    ld  (var2),hl                       ; Store Help Size
    ld  de,FCBhelp
    ld  c,_FCLOSE
    call    DOS                         ; Close file
; copy help buffer to help segment
    ld  hl,#9000                        ; Origin
LsHi1:
    ld  a,(P2_sys)
    call    PUT_P2                      ; Main App segment
    ld  a,(hl)
    ld  b,a                             ; Copy help byte to B
    ld  a,(S_C)
    call    PUT_P2                      ; Help segment
    ld  a,b
    ld  (hl),a                          ; Save it
    inc hl                              ; Adjust pointr
    ld  a,h
    cp  #C0
    jr  nz,LsHi1                        ; And copy all the way up to C0000.... Doesn't seem smart, we have size in var2, why not use it? TODO
    ; set size of help bufer
    ld  ix,sWCB0                        ; Help segment WCB
    ld  hl,(var2)                       ; Size of help in HL
    ld  de,(sWCB0+12)                   ; #9000 text buffer
    add hl,de
    ld  (sWCB0+16),hl                   ; end buffer 
    call    BFSegT                      ; rebuild active segment table as it sits on 0x9000 and was destroyed :)
    jp  Hmcw                            ; Help screen operations

;--- Get the Segment for Server Control in P2
Hmcw:
    ld  a,(S_C)
    call    PUT_P2                      ; Help segment @ P2
    ; set segment information attributes
    call    SSIA
    ld  ix,sWCB0                        ; WCB where Help is
    call    CLS_TW                      ; Initialize screen buffer for it
    ld  hl,(sWCB0+WIN_RAM_B_CUR)        ; RAM Buffer for Help in HL
    xor a
    ld  (ix+WIN_H_POS),a
    ld  (ix+WIN_V_POS),a                ; Cursor @ 0x0
    ld  (ix+WIN_BUFF_STS),a             ; And buffer normal
    inc a
Hmcw2:
    ld  a,(ix+WIN_V_POS)                ; v pos (line)
    ld  c,(ix+WIN_V_SIZE)               ; v max
    cp  c                               ; at the last line
    jp  p,Hmcw1                         ; y posit > max y (out of screen)
    ld  de,(sWCB0+WIN_RAM_B_END)        ; RAM Buffer End in DE
    ld  a,l
    sub e
    ld  a,h
    sbc a,d                             ; HL - DE should carry, otherwise done
    jr  nc,Hmcw3                        ; out of buffer to print
    ld  a,(hl)                          ; Get char
    inc hl                              ; update pointer
    cp  #0A
    jr  nz,Hmcw0                        ; If new line jump
    ld  (sWCB0+WIN_L_STR_ADD),hl        ; Update last string address
Hmcw0:
    push    hl                          ; Save HL
    call    OUTC_TW                     ; Char on screen
    pop hl                              ; Restore HL
    jp  Hmcw2                           ; And loop
Hmcw3:
    ld  a,1
    ld  (ix+WIN_BUFF_STS),a             ; out of buffer to print
Hmcw1:
    call    LOAD_S                      ; And update screen with WCB buffer
; operations 
HmwcG:
    call    CLOCK                       ; Update clock and time on screen
    call    TCPSEP                      ; Check if there is data, if connection is open of course
    jp  SEL_RE                          ; Safe guard, just in case segment is lost, switch to different window, otherwise, will end-up in HLP_RE
HLP_RE:
    call    L_SIA                       ; Update the last line with the segment information
    ld  c,_CONST
    call    DOS
    or  a
    jr  z,HmwcG                         ; If zero, no key pressed, loop
    ; Key pressed, let's get it
    ld  c,_INNO
    call    DOS
    ld  b,a                             ; Key IN B
    ld  a,(S_C)
    call    PUT_P2                      ; Make sure Help segment is @P2
    ld  a,b                             ; Key back in A
    ld  hl,#FBEB                        ; 6th keyboard matrix row address
    ld  ix,sWCB0
    cp  ESC_
    jp  z,Hmcw_EX                       ; Return to main screen
    cp  UP_
    jr  z,HmcwUP                        ; Check if scroll one line or page up
    cp  DOWN_
    jr  z,HmcwDOWN                      ; Check if scroll one line or page down
    bit 1,(hl)
    jr  z,HmcWCTRL                      ; If CTRL is pressed, check more stuff
    jp  Hmcw                            ; Otherwise back to main loop
    ; Check if anything is pressed with CTRL that we care about
HmcWCTRL:
    cp  LEFT_
    jp  z,S_LEFT                        ; CTRL Left -> Switch to the window to the left of ours, if any
    cp  RIGHT_
    jp  z,S_RIGHT                       ; CTRL Right -> Switch to the window to the right of ours, if any
    and %01011111
    cp  17                              ; CTRL+Q
    jp  z,HmcwCLOSE                     ; Close this Window
    jp  Hmcw                            ; Otherwise, back to main loop

HmcwUP:
    ld  b,1
    ld  hl,#FBEB
    bit 0,(hl)                          ; Shift pressed?
    jr  nz,Hmcw_UP2                     ; If not, will go one line up
    ld  b,(ix+WIN_V_SIZE)               ; If pressed, go up the number of lines (a page)
Hmcw_UP2:
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
    ld  de,(sWCB0+WIN_RAM_B_ADD)
    dec hl
Hmcw_UP1:
    xor a
    push    hl                          ; Save HL
    sbc hl,de                           ; CUR - ADD
    pop hl                              ; Restore HL
    jp  m,Hmcw_UP3                      ; If CUR<ADD go to UP3, nothing else to do / buffer finished
    ; CUR >= ADD
    dec hl
    ld  a,(hl)
    cp  #0A
    jr  nz,Hmcw_UP1                     ; Loop until no more data in buffer or new line
    dec b
    jr  nz,Hmcw_UP1                     ; And loop until no more lines to go up
Hmcw_UP3:
    inc hl
    ld  (sWCB0+WIN_RAM_B_CUR),hl        ; Update Current
    jp  Hmcw                            ; Back to help main loop


HmcwDOWN:
    ld  a,(ix+WIN_BUFF_STS)
    or  a
    jp  nz,Hmcw                         ; Back to help main loop if out of buffer to print
    ld  hl,#FBEB
    bit 0,(hl)                          ; Shift pressed?
    jr  nz,Hmcw_DW0                     ; If not, will go one line down
    ; Go up to one page down
    ld  a,(ix+WIN_L_STR_ADD_LSB)
    ld  (ix+WIN_RAM_B_CUR_LSB),a
    ld  a,(ix+WIN_L_STR_ADD_MSB)
    ld  (ix+WIN_RAM_B_CUR_LSB),a        ; Last string in current, so start drawing from the last
    jp  Hmcw                            ; Back to help main loop
    ; One line down
Hmcw_DW0:
    ld  hl,(sWCB0+WIN_RAM_B_CUR)        ; Current in HL
Hmcw_DW1:
    ld  a,#0A
    ld  bc,0
Hmcw_DW2:
    cpir                                ; Search for Line Feed
    jp  nz,Hmcw_DW2                     ; Repeat if not found
    ld  (sWCB0+WIN_RAM_B_CUR),hl        ; Save as last string
    jp  Hmcw                            ; Back to help main loop

;--- Exit Help Menu
Hmcw_EX:
    call    CURSOFF
    ld  a,(segp)                        ; get segment being displayed
    ld  (segsel),a                      ; into segment selected
    jp  SYS_S                           ; and go to main menu

;--- Free Help segment and then exit Help Menu
HmcwCLOSE:
    call    CURSOFF
    ld  a,(segp)
    call    FRE_RECS                    ; Free memory segment
    call    BFSegT                      ; Update the bufferized segment table
    ld  a,(ix+WINDOW_COUNT)
    or  a                               ; Is there a segment?
    jp  z,SYS_S                         ; If not, go to main menu
    jp  S_LEFT                          ; Otherwise, go to the segment to our left

;*****************************************
; Enter Server Segment
;*****************************************
LsEnSS:
    inc hl                              ; Jump from segment type to segment in mapper
    ld  a,(hl)                          ; in A
    ld  (S_C),a                         ; Segment for main window
    ld  a,(segsel)
    ld  (segp),a                        ; segment selected in segp
    jp  SRVC                            ; Server Window loop


;Create Server record (Server Console)
SERV_C:
;*****************************************
; Server control segment
;*****************************************
    call    CLKB                        ; clear kbd buffer
    call    CLAT_C_N                    ; clear attribute channel (server)
    ld  a,(serv1)
    or  a
    jp  nz,NO_SERV                      ; server windows exists, it won't be recreated, select it in main menu...
    call    ALL_REC                     ; get free record
    ld  a,b
    ld  (segp),a                        ; This will be the current segment/window being displayed
    jp  c,NO_REC                        ; If carry, no more records!
    push    hl                          ; Save the MAP Table entry
    ld  a,0
    ld  b,a                             ; Primary mapper
    call    ALL_SEG                     ; Request a user segment to be allocated from primary maper
    jp  c,NO_SEG                        ; If carry, failed to allocate
    pop hl                              ; Restore MAP Table entry
    ; set record to S status
    ld  (hl),"S"
    inc hl
    ; set mapper segment
    ld  (hl),a
    ; Initialize Server control segment
    ld  (S_C),a                         ; Load it in screen control segment
    ld  (serv1s+1),a                    ; mapper segment N save to sw
    call    PUT_P2                      ; Select the segment in page 2
    call    CLS_G                       ; Clear the screen buffer as we are going to build the screen for our new segment
    ld  a,1
    ld  (serv1),a                       ; set server record already exist
    ld  a,(segp)
    ld  (segs),a                        ; make it the selected segment
    ld  (serv1s),a                      ; save N record
    ld  d,0
    ld  a,(segs)
    ld  e,a                             ; DE has segment #
    ld  hl,#8000
    ld  b,2
    ld  c,"0"
    ld  a,%00000000
    call    NUMTOASC                    ; Will convert the segment number in printable format
    ld  hl,#8000+3
    ld  (hl),"S"                        ; S identify Window as S type
    inc hl
    inc hl
    ld  iy,PA_SERVER                    ; Server name -> name record
    ld  b,60                            ; can write up to 60 characters
SRVC2:
    ld  a,(iy)
    or  a
    jr  z,SRVC1                         ; if 0 done
    ld  (hl),a
    inc hl
    inc iy
    djnz    SRVC2                       ; otherwise copy to buffer and repeat, unless we've done it 60 times
SRVC1:
    ld  hl,WCB01                        ; server WCB template
    ld  de,sWCB0                        ; will go to the main Window
    ld  bc,24
    ldir                                ; set WCB to segment
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
    call    PRINT_BF                    ; Initial text on server screen has all settings and tell what to do next (F2 connect, F3 disconnect)
    ; initialize string input window
    ld  hl,WCB3
    ld  de,sWCB2
    ld  bc,24
    ldir                                ; Template of string input window on sWCB2
    ld  ix,sWCB2
    call    CLS_TW                      ; Initialize screen buffer for it
    ; initialize cursor for input window
    xor a
    ld  (oldcur),a
    ld  (oldcur+1),a
    ld  (oldcur+2),a
    ; clear ct buffer
    ld  hl,#8A00
    ld  bc,270
Swi4:
    xor a
    ld  (hl),a                          ; Save 0
    inc hl
    dec bc                              ; Adjust pointer and counter
    ld  a,b
    or  c
    jr  nz,Swi4                         ; Loop until counter is 0
    call    LOAD_S
    ; ini buffer for back loading
    ld  hl,#0019                        ; v-25 h-00
    bios    POSIT                       ; position cursor
    call    CLKB                        ; clear kbd buffer
    call    BFSegT                      ; rebuild active segment table

SRVC:
SRVw:
    ld  a,(S_C)
    call    PUT_P2                      ; Server Segment in P2
    call    SSIA                        ; Set the information attributes
    ld  ix,sWCB2                        ; Line Input WCB
    ld  hl,(sWCB2+WINDOW_VR_ADD)        ; VRAM Address in HL
    ld  d,0
    ld  e,(ix+WIN_H_POS)                ; Cursor Position
    add hl,de                           ; HL has the VRAM address
    call    CURSOR                      ; Set the cursor
    call    LOAD_S                      ; And put all on screen

SRVC0:
    ; macros auto
    ld  bc,(tsb)                        ; Bytes in input buffer
    ld  a,b
    or  c                               ; Check if zero
    jr  z,SRVCB                         ; If it is, regular handling
    ; Otherwise, that buffer has priority over keyboard input, so deal with it
    dec bc
    ld  (tsb),bc                        ; Decrement counter
    ld  hl,(tsb+2)                      ; Address in HL
    ld  a,(hl)                          ; Get its content
    inc hl
    ld  (tsb+2),hl                      ; Update pointer
    jp  SRVCC                           ; And handle as key input
SRVCB:
    call    TCPSEP                      ; First check if there is data from server
    jp  SEL_RE                          ; Safe guard, just in case segment is lost, switch to different window, otherwise, will end-up in SRV_RE
SRV_RE:
    call    L_SIA                       ; Update the last line with the segment information
    call    newsload
    call    CLOCK                       ; Update clock and time on screen
    ; keyboard input
    ld  c,_CONST
    call    DOS
    or  a
    jr  z,SRVC0                         ; If zero, no key pressed, loop
    ld  c,_INNO
    call    DOS
SRVCC:
    ld  b,a                             ; Key IN B
    ld  a,(S_C)
    call    PUT_P2                      ; Make sure Server segment is @P2
    ld  ix,sWCB2                        ; Any updates from here go to the line input window
    ld  hl,#FBEB                        ; 6th keyboard matrix row address
    ld  a,b                             ; Key back in A
    bit 7,(hl)
    jp  z,SRV_F3                        ; F3 -> Disconnect
    bit 6,(hl)
    jp  z,SRV_F2                        ; F2 -> Connect
    bit 5,(hl)
    jp  z,Ls_help                       ; F1 -> Go to Help
    cp  #0D
    jp  z,SRV_se                        ; Enter -> send whatever is in our input window
    cp  ESC_
    jp  z,SRV_EX                        ; Back to main system menu
    cp  11
    jp  z,SRV_home                      ; CLS/HOME go back to last line in Window
    cp  UP_
    jp  z,SRV_UP                        ; Go one line up if control is pressed or one page up if shift is pressed
    cp  DOWN_
    jp  z,SRV_DW                        ; Go one line down if control is pressed or one page down if shift is pressed
    cp  "&"
    jp  z,SRV_F4                        ; Just send nick, password, server pass
    ; otherwise it is part of the line input, enter string
    ; First check actions keys
    cp  8
    jp  z,SRV_bs                        ; "BS" <-
    cp  18
    jp  z,SRV_ins                       ; INS
    cp  127
    jp  z,SRV_del                       ; DEL
    cp  LEFT_
    jp  z,SRV_left                      ; Go Left if possible
    cp  RIGHT_
    jp  z,SRV_right                     ; Go Right if possible
    ; Ok, so it is just a regular character
    ex  af,af'                          ; Use shadow AF preserving character in AF
    ld  a,(s_ins)
    or  a
    jr  z,SRV_r4                        ; Insert is Off
    ; Insert is ON
    ld  hl,(sWCB2+WIN_RAM_B_END)
    ld  e,l
    ld  d,h                             ; Buffer End of Input Window on DE
    dec hl                              ; HL has it adjusted
    ld  bc,(sWCB2+WIN_RAM_B_CUR)
    xor a                               ; Clear carry
    sbc hl,bc
    jr  c,SRV_r4                        ; If HL equal or greater, cursor in last position, not goint to insert
    ; Yeah, going to insert on cursor position
    inc hl                              ; HL adjusted
    ld  c,l
    ld  b,h                             ; And it is now the count of characters to "shift" to allow a character to be inserted
    ld  l,e
    ld  h,d                             ; Origin is the last buffer byte
    inc de                              ; Destination is origin + 1
    ld  (sWCB2+WIN_RAM_B_END),de        ; New buffer end
    inc bc                              ; Adjust count
    lddr                                ; And move last to last + 1, from last to insert position
SRV_r4:
    ex  af,af'                          ; Back to original AF / Character
    ; save char to buff
    ld  hl,(sWCB2+WIN_RAM_B_CUR)
    ld  (hl),a                          ; Save in buffer
    inc hl
    ld  (sWCB2+WIN_RAM_B_CUR),hl        ; Save new current
    ld  de,(sWCB2+WIN_RAM_B_END)
    xor a                               ; Clear Carry
    sbc hl,de
    jr  c,SRV_r3                        ; If carry, no more space
    inc de
    ld  (sWCB2+WIN_RAM_B_END),de        ; There is, so adjust end
SRV_r3:
    ld  a,(ix+WIN_H_POS)
    ld  b,(ix+WIN_H_SIZE)
    dec b                               ; adjust size, column start at 0, size at 1
    cp  b                               ; screen cursor at last position?
    jr  nc,SRV_r1                       ; yes, last position
    ; not last position, inc h pos
    inc a
    ld  (ix+WIN_H_POS),a
    jr  SRV_r2                          ; And go to update screen
SRV_r1:
    ; Cursor on last position
    ld  hl,(sWCB2+WIN_L_STR_ADD)
    inc hl
    ld  (sWCB2+WIN_L_STR_ADD),hl        ; Update the last so it will "scroll"
SRV_r2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  SRVw                            ; And done, loop


SRV_ins:
    ld  a,(s_ins)                       ; Current insert option
    cpl                                 ; invert
    ld  (s_ins),a                       ; New insert option, now toggled
    jp  SRVw                            ; And done, loop


SRV_left:
    bit 1,(hl)
    jp  z,S_LEFT                        ; If control, check if there is a window to our left to jump to
    ; No control, so let's check if we can navigate our input window to the left
    ld  de,(sWCB2+WIN_RAM_B_CUR)
    ld  hl,(sWCB2+WIN_RAM_B_ADD)
    xor a                               ; Clear flag
    sbc hl,de                           ; ADD - CUR will have size and carry
    jp  nc,SRVw                         ; if no carry, cursor position is in first position, back to loop
    dec de                              ; Decrement
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; Save
; LEFT
    dec (ix+WIN_H_POS)                  ; c_cur --
    jp  p,SRVL1                         ; > 0 norm
    ; Ooops, it was zero
    inc (ix+WIN_H_POS)                  ; c_cur ++, back to 0
    ld  (sWCB2+WIN_L_STR_ADD),de        ; And adjust the position of the last shown, as this is a scroll
SRVL1:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  SRVw                            ; And done, loop


SRV_right:
    bit 1,(hl)
    jp  z,S_RIGHT                       ; If control, check if there is a window to our right to jump to
    ld  de,(sWCB2+WIN_RAM_B_CUR)
    ld  hl,(sWCB2+WIN_RAM_B_END)
    inc de
    xor a                               ; Clear flag
    sbc hl,de
    jp  c,SRVw                          ; if carry, cursor at last position, back to loop
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; Otherwise, new position
    ld  b,(ix+WIN_H_SIZE)               ; H-size
    ld  a,(ix+WIN_H_POS)                ; h_cur
    inc a                               ; Adjust as size starts with 1 and pos with 0
    cp  b
    jp  nc,SRV_R1                       ; If not carry, at last screen position, so do not update cursor position
    ld  (ix+WIN_H_POS),a                ; Otherwise, save the new position
    jr  SRV_R2                          ; And good to display and be done
SRV_R1:
    ; If here, cursor at last screen position, but there is data to the right, so "scroll"
    ld  hl,(sWCB2+WIN_L_STR_ADD)
    inc hl
    ld  (sWCB2+WIN_L_STR_ADD),hl        ; Update the last to be shown on screen
SRV_R2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  SRVw                            ; And done, loop


SRV_del:
    ld  hl,(sWCB2+WIN_RAM_B_CUR)
    ld  de,(sWCB2+WIN_RAM_B_END)
    dec de                              ; Adjust END to check how it will be after "deleting"
    xor a                               ; Clear flag
    sbc hl,de                           ; CUR - END -> Should be 0 or Carry if there is something to delete, cursor should not be at end (thus why DE = END -1)
    jr  c,SRV_del1                      ; negative number, so will need to shift/scroll
    jp  nz,SRVw                         ; 0 means one to delete, no need to shift/scroll, non-zero means nothing in front of cursor to delete
SRV_del1:
    ld  (sWCB2+WIN_RAM_B_END),de        ; Save adjusted end
    jr  z,SRV_del2                      ; 0 -> No need to shift / scroll
    ; scroll right part string
    inc de                              ; de back to end
    xor a                               ; Clear flag
    add hl,de                           ; hl = b_cur  de = b_end-1 old
    ex  de,hl                           ; hl = b_end new de = B_cur
    sbc hl,de                           ; hl = characters to move / delete
    ld  c,l
    ld  b,h                             ; Count
    ld  l,e
    ld  h,d
    dec hl                              ; HL is current position - 1
    inc bc                              ; Adjust count
    ex  de,hl                           ; Current position - 1 in DE, HL current position, so that is our copy
    ldir                                ; And copy
SRV_del2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  SRVw                            ; And done, loop


; "back space" delete last symbol in position before cursor
SRV_bs:
    ld  hl,(sWCB2+WIN_RAM_B_ADD)
    ld  de,(sWCB2+WIN_RAM_B_CUR)
    xor a                               ; Clear Carry
    sbc hl,de                           ; |<- X
    jp  nc,SRVw                         ; not possible to BS, back to loop
    dec de
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; will be back a position, adjust
    ; bs
    dec (ix+WIN_H_POS)                  ; c_cur --
    jp  p,SRVbs1                        ; > 0, ok to go
    ; No, so will need to shift a little as cursor is in first display position for input window
    inc (ix+WIN_H_POS)                  ; c_cur ++, back to 0
    ld  (sWCB2+WIN_L_STR_ADD_MSB),de    ; Adjust last position to shift
SRVbs1:
    ;scroll right part of string 1 byte to the left
    ld  hl,(sWCB2+WIN_RAM_B_END)
    dec hl
    ld  (sWCB2+WIN_RAM_B_END),hl        ; adjust endbuff decreasing the character erased by back space
    xor a                               ; Clear carry
    sbc hl,de                           ; New end position - new cursor position
    ld  a,h
    or  l
    jr  z,SRVbs2                        ; If 0, no content to scroll / shift
    ld  c,l
    ld  b,h                             ; Otherwise, HL has the number of characters to scroll to the left
    ld  l,e
    ld  h,d                             ; DE is destination new cursor position
    inc hl                              ; HL is source, one character after new cursor position
    ldir                                ; and move all
SRVbs2: 
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  SRVw                            ; And done, loop


; Enter was hit, so send if any string
SRV_se:
    call    CLS_TW                      ; clear input window
    xor a
    ld  (ix+WIN_H_POS),a
    ld  (ix+WIN_V_POS),a                ; Cursor at 0x0
    ld  hl,(sWCB2+WIN_RAM_B_END)
    ld  (hl),#0D
    inc hl
    ld  (hl),#0A                        ; Finish with CR/LF, irc protocol
    inc hl                              ; curs
    ld  de,(sWCB2+WIN_RAM_B_ADD)        ; buff
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; curs at start of buff
    ld  (sWCB2+WIN_L_STR_ADD),de        ; last is start, so, nothing
    ld  (bbuf),de                       ; save in BBUF 
    xor a                               ; Clear carry
    sbc hl,de                           ; HL -> count of how many characters to send
    ld  (lenb),hl                       ; save in LENB
    ld  (sWCB2+WIN_RAM_B_END),de        ; Buffer End at beginning as well
    ld  a,(hl)                          ; HL has the beginning of buffer to send
    cp  13
    jp  z,SRVw                          ; if starts with CR/ENTER, empty string, do not send, back to loop
    call BuffOU                         ; Not empty, so, BuffOU will send it to the server and print on the main window
    jp  SRVw                            ; And done, loop


; This will print a 0 or '$' terminated string on main window, string address @ HL
; The string will be preceeded by a timestamp if timestamps are configured
PRINT_BF:
    ld  bc,0                            ; Initial count 0
    ld  (bbuf),hl                       ; HL -> address to print, put it in BBUF
PR_BF2:
    ld  a,(hl)
    cp  "$"
    jr  z,PR_BF1
    or  a
    jr  z,PR_BF1                        ; If 0 or '$' end of string
    inc hl
    inc bc                              ; Adjust counter and pointer
    jr  PR_BF2                          ; Loop until the end of string
PR_BF1:
    ld  (lenb),bc                       ; Save string lenght
    ld  a,(S_C)
    call    PUT_P2                      ; Make sure our memory segment is at P2
    jr  BuffOU1                         ; BuffOU1 will send to the main window and return from there 


;--- BuffOU
;    Will send (lenb) bytes starting at the address stored in bbuf to the server
;    Whatever is sent will be printed in the main window, preceeded by a time stamp if configured
BuffOU:
    call    TCPSEND                     ; TCPSEND will send data with proper IRC protocol
    ;   string[bbuf,lenb] to buffer(ix)
    ld  hl,(bbuf)
    ld  (bbuf1),hl
    ld  hl,(lenb)
    ld  (lenb1),hl                      ; Copy bbuf and lenb to its 1 counterparts
    ld  hl,PA_NICK
    ld  (bbuf),hl                       ; PA_NICK at bbuf
    ld  bc,32
    xor a
    cpir                                ; Try to find 0 at PA_NICK
    ld  bc,PA_NICK
    sbc hl,bc                           ; Result is the size of what is in PA_NICK
    ld  (lenb),hl                       ; Size of PA_NICK area at lenb
    call    BuffOU1                     ; Sent it to the screen first
    ld  hl,(bbuf1)
    ld  (bbuf),hl
    ld  hl,(lenb1)
    ld  (lenb),hl                       ; Now restore bbuf and lenb with the text we've sent to the server
    ; And send it to the screen
BuffOU1:
    ld  bc,(lenb)
    ld  a,b
    or  c
    ret z                               ; If nothing to print, just return
    ld  a,"*"
    ld  (w0new),a                       ; New content on window
    xor a                               ; Clear carry
    ld  a,(segs)
    rla                                 ; Multiply by 2 the window/segment id, this is our maptab entry offset
    ld  c,a
    ld  b,0
    ld  hl,MAPTAB
    add hl,bc                           ; HL has the maptab entry for the segment
    res 7,(hl)                          ; reset 7th bit, new content to be updated
    ; time stamp
    ld  a,(t_stmp)
    or  a
    jr  z,SRV_se00                      ; If no time-stamp configured, move on....
    ld  ix,sWCB0
    ld  a,(ix+WIN_H_POS)
    or  a
    jr  nz,SRV_se00                     ; If not at position 0, no need for a time stamp
    call    CLOCK                       ; Update date an time on top of screen
    ld  hl,(bbuf)
    ld  (bbuf2),hl
    ld  hl,(lenb)
    ld  (lenb2),hl                      ; Save bbuf and lenb in its 2 counterparts
    ld  hl,TABTS
    ld  a,(t_stmp)
    and #0F                             ; Get only LSB and clear carry at the same time
    rla
    ld  c,a
    ld  b,0                             ; BC is the offset in TABTS for the configured time stamp
    add hl,bc
    ld  e,(hl)                          ; first byte of TABTS entry in E, address LSB
    inc hl
    ld  c,(hl)                          ; second byte (TS lenght) in C
    ld  d,#80                           ; Address MSB
    ld  b,0                             ; Count is less than 256, so only C
    ld  (bbuf),de
    ld  (lenb),bc                       ; Length and where to put TS in BBUF and LENB
    call    SRV_se00                    ; So, we are using what is on top of the screen, clock and date, and sending to the line beginning, cool not? :)
    ld  de,#8000+71
    ld  bc,1
    ld  (bbuf),de
    ld  (lenb),bc                       ; Get a space from the top line to put after the time stamp
    call    SRV_se00                    ; And print
    ld  hl,(bbuf2)
    ld  (bbuf),hl
    ld  hl,(lenb2)
    ld  (lenb),hl                       ; Restore BBUF and LENB to it's original and now to the screen
SRV_se00:
    ld  ix,sWCB0
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
    ld  bc,#C000                        ; Limit for our page / memory
    xor a                               ; Clear Carry
    sbc hl,bc                           ; if different
    jp  nz,SRV_se01                     ; still space in memory, not out channel windows
    ; out chan windows
    ld  hl,(bbuf)
    ld  bc,(lenb)                       ; buffer in hl and lenght in BC
SRV_se0:
    ld  a,(hl)                          ; character in A
    push    hl
    push    bc                          ; save pointer and counter
    call    OUTC_TW                     ; put it on screen
    pop bc
    pop hl                              ; restore pointer and counter
    inc hl
    dec bc                              ; update pointer and counter
    ld  a,b
    or  c
    jr  nz,SRV_se0                      ; and repeat until counter is 0
SRV_se01:
    ; cut buffer
    ld  bc,(lenb)
    ld  hl,(sWCB0+WIN_RAM_B_ADD)
    ld  de,#9200                        ; lower line ********************************
    xor a
    sbc hl,bc                           ; new buffer    hl = hl - (len)
    sbc hl,de                           ; < #9000 ?
    jr  nc,SRV_se1                      ; no overfull
    ld  hl,0
SRV_se1:
    add hl,de                           ; hl - dest adr
    ld  (sWCB0+WIN_RAM_B_ADD),hl
    push    hl                          ; old
    add hl,bc                           ; add count
    ex  de,hl
    ld  hl,#C000
    xor a
    sbc hl,de                           ; hl=#C000 - source
    ld  c,l
    ld  b,h                             ; now in BC
    pop hl                              ; restore dest address
    ex  de,hl                           ; and now in DE
    ; hl = new buf + (len) , de new buf , bc = #C000 - (new buf +(len))
    ldir                                ; move
    ld  a,(T_S_C)
    ld  b,a
    ld  a,(S_C)
    cp  b                               ; if we are the current segment
    call    z,LOAD_S                    ; load in VRAM
    ei
    ; load buffer
    xor a
    ld  hl,#C000
    ld  bc,(lenb)
    sbc hl,bc
    ex  de,hl
    ld  hl,(bbuf)
    ldir
    ret

SRV_home:
    ld  ix,sWCB0
    ld  hl,#C000
    ld  (sWCB0+WIN_RAM_B_CUR),hl
    call    PPBC
    jp  SRVw


SRV_UP:
    ld  ix,sWCB0
    bit 0,(hl)                          ; if 0 - SHIFT
    jp  z,SRVUPvPU                      ; View channel buffer UP 1 page
    bit 1,(hl)                          ; if 0 - CTRL
    jp  z,SRVUPvU                       ; View channel buffer UP 1 string
    jp  SRVw                            ; if no shift or control, nothing to do, back to loop


SRV_DW:
    ld  ix,sWCB0
    bit 0,(hl)                          ; if 0 - SHIFT
    jp  z,SRVDWvPD                      ; View channel buffer UP 1 page
    bit 1,(hl)                          ; if 0 - CTRL
    jp  z,SRVDWvD                       ; View channel buffer UP 1 string
    jp  SRVw                            ; if no shift or control, nothing to do, back to loop


SRVUPvPU:
    ld  d,(ix+WIN_V_SIZE)               ; Limit of lines in D
    jr  SRVU2
SRVUPvU:
    ; View channel buff UP 1 string (a string means a full line received, no matter if fits one line in window or more)
    ld  d,1                             ; Just 1 line
SRVU2:
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
    dec hl
    dec hl
SRVU3:
    ld  a,#0A
SRVU1:
    cpdr
    jr  nz,SRVU1                        ; will look back until find a new line, indicating end of previous string
    dec d                               ; decrement line count
    jr  nz,SRVU3                        ; do it again until line count is 0
    inc hl
    inc hl                              ; adjust
    ex  de,hl                           ; now in DE
    ld  hl,(sWCB0+WIN_RAM_B_ADD)
    xor a                               ; Clear carry
    dec hl
    sbc hl,de                           ; hl-de=?
    jp  nc,SRVw                         ; if no carry, nothing to update, back to loop
    ld  (sWCB0+WIN_RAM_B_CUR),de        ; Otherwise update current
    call    PPBC                        ; Print Part of Buffer Channel
    jp  SRVw                            ; And done


SRVDWvPD
    ld  d,(ix+WIN_V_SIZE)               ; Limit of lines in D
    jr  SRVD0
SRVDWvD:
    ; View channel buff Down 1 string
    ld  d,1                             ; Just 1 line
SRVD0:
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
SRVD2:
    ld  a,#0A
SRVD1:
    cpir
    jp  nz,SRVD1                        ; will look forward until find a new line, indicating end of next string
    ld  a,h
    cp  #C0
    jr  nc,SRVD3                        ; out of buffer hl > #C000
    dec d                               ; decrement line count
    jr  nz,SRVD2                        ; do it again until line count is 0
SRVD4:
    ld  (sWCB0+WIN_RAM_B_CUR),hl
    call    PPBC                        ; Print Part of Buffer Channel
    jp  SRVw                            ; And done
SRVD3:
    ld  hl,#C000                        ; set cur end of buffer
    jp  SRVD4


SRV_EX:
    call    CURSOFF
    ld  a,(segp)
    ld  (segsel),a                      ; segment displayed in segment selected
    jp  SYS_S

; --- F2 will connect to the server
SRV_F2:
    call    CLKB                        ; clear keyboard buffer, F key...
    call    GET_P2
    ld  (segsRS),a                      ; Save current P2 in segsRS
    ld  a,(notcpip)                     ; check for TCP/IP UNAPI implementation
    or  a
    jr  z,SRVF2_1                       ; If 0, there is an UNAPI implementation
    ; There is not
    ld  hl,NOTCPIP_S
    call    PRINT_BF                    ; Error message
    jp  SRVw                            ; Back to window loop
SRVF2_1:
    ; check for existing connection
    ld  a,(serv1c)
    or  a
    jr  z,SRVF2_2                       ; If 0, no connection, so let's do it
    ; Connection already exists
    ld  hl,SM_CONNEXIST
    call    PRINT_BF                    ; Error message
    jp  SRVw                            ; Back to window loop
SRVF2_2:
    ; Attempt to connect
    call    CONNECT_S
    jp  SRVw                            ; And back to window loop after it


; --- F3 will disconnect
SRV_F3:
    call    CLKB                        ; clear keyboard buffer, F key...
    xor a
    call    TCP_ERROR2                  ; TCP_ERROR2, despite its name, will close the connection
    xor a
    ld  (serv1c),a                      ; update flag that there is no connection
    jp  SRVw                            ; And back to window loop after it


; --- Name is F4, key is &... Will send again all configured user parameters ( nick, pass, user and serverpass if configured)
SRV_F4:
    ld  de,tsb+4
    ld  (tsb+2),de                      ; Pointer at first tsb position 
    ld  a,(PA_SRVPASS)
    or  a
    jr  z,SRVF4_1                       ; no server password, next
    ld  a,"/"
    ld  (de),a
    inc de
    ld  hl,AA_SPAS
    call    COPYARG                     ; "/PASS "
    ld  hl,PA_SRVPASS
    call    COPYARG                     ; Add the password
    dec de                              ; last space not needed
    ld  a,13                            ; CR
    ld  (de),a
    inc de                              ; And let's continue
SRVF4_1:
    ld  a,"/"
    ld  (de),a
    inc de
    ld  hl,AA_NICK                      ; "/NICK "
    call    COPYARG
    ld  hl,PA_NICK
    call    COPYARG                     ; Add the nickname
    dec de                              ; last space not needed
    ld  a,13                            ; CR
    ld  (de),a
    inc de
    ld  a,"/"
    ld  (de),a
    inc de
    ld  hl,AA_USER                      ; "/USER "
    call    COPYARG
    ld  hl,PA_USER
SRVF4_3:
    ld  a,(hl)
    or  a
    jr  z,SRVF4_2                       ; If NULL, done
    ld  (de),a                          ; Copy USER string
    inc hl
    inc de                              ; increment pointers
    jr  SRVF4_3                         ; and loop
SRVF4_2:
    ld  a,13                            ; CR
    ld  (de),a
    inc de
    xor a
    ld  (de),a                          ; NULL Terminate
    ld  hl,tsb+4
    ld  bc,512
    xor a
    cpir                                ; Look for null, to make sure it doesn't exceed our 512 bytes buffer
    jp  nz,SRVw                         ; It exceeded... Do not send... As tsb is the last thing of our program, exceeding, unless by about 15KB, won't hurt
    ld  de,tsb+4
    xor a
    dec hl
    sbc hl,de
    ld  (tsb),hl                        ; Size of data
    jp  SRVw                            ; Back to main loop, it will send what is in tsb


LsEnCS:
;*****************************************
; Enter Channel Segment
;*****************************************
    inc hl                              ; HL was at segment type, jump to segment in mapper
    ld  a,(hl)                          ; Now in A
    ld  (S_C),a                         ; And it is the segment for main Window
    ld  a,(segsel)
    ld  (segp),a                        ; segment selected in segment displayed
    jp  CHAN                            ; channel window loop

;Create Channel records
;
;
CHANNEL_C:
    ld  a,"C"
    ld  de,C_CHAN
    call    SrS                         ; Does the channel in C_CHAN exist?
    jr  c,CHANNEL_CREATE                ; If Carry, not, then create it
    ; Otherwise it does, and it is now selected @ P2
    ret

newsload:
    ld  a,(w0new)
    or  a
    ret z                               ; if nothing new for wcb0, nothing to do
    ; Otherwise...
    call    LOAD_S                      ; Update screen with WCB buffer
    xor a
    ld  (w0new),a                       ; reset w0new
    ld  a,(segs)
    rla
    ld  c,a
    ld  b,0
    ld  hl,MAPTAB
    add hl,bc                           ; Our segment maptab entry
    set 7,(hl)                          ; Clear new flag as it has been updated on screen
    ret


CHANNEL_CREATE:
;***********************************************
; Channel control segment
;***********************************************
    CALL    CLAT_C_N                    ; Clear the attributes of the secondary window (either a nick list or a window list go there)
    call    ALL_REC                     ; get free record
    ld  a,b
    ld  (segp),a                        ; Record number in segp
    jp  c,NO_REC                        ; If carry, no segment available
    push    hl                          ; MAPTABle Entry, save it
    ld  a,0
    ld  b,a                             ; Primary mapper only
    call    ALL_SEG
    jp  c,NO_SEG                        ; If carry, couldn't allocate it
    ; Ok, allocated MM segment
    pop hl                              ; Restore MAP Table entry
    ld  (hl),"C"                        ; 'C' as it is a channel
    inc hl
    ld  (hl),a                          ; Segment
    ld  (S_C),a                         ; Also in S_C
    call    PUT_P2                      ; Select it
    call    CLS_G                       ; Clear the screen buffer as we are going to build the screen for our new segment
    ld  b,24                            ; 24 lines
    ld  de,80                           ; each line is 80 characters
    ld  hl,#8000 + 80 * 2 - 16          ; start at the second line, we are going to draw our nick list separator
    ld  a,22                            ; 134 ?     ;"!"
wi3:
    ld  (hl),a                          ; Put it for that line
    add hl,de                           ; jump to next line
    djnz    wi3                         ; Repeat while we have not done all lines
    ld  a,(segp)
    ld  (segs),a                        ; Our segment that was created is now in segS
    ld  a,(segsRS)                      ; segment parent
    ld  (segsR),a
    ld  d,0
    ld  a,(segs)
    ld  e,a                             ; DE - Record or Window #
    ld  hl,#8000                        ; First position of buffer
    ld  b,2                             ; Two digits
    ld  c,"0"                           ; Leading 0
    ld  a,0
    call    NUMTOASC                    ; Convert to ASC in the first line
    ld  hl,#8000+3
    ld  (hl),"C"                        ; C identificator
    inc hl
    inc hl                              ; two blank spaces
    ld  iy,C_CHAN                       ; Current Channel name
    ld  b,50                            ; Up to 50 characters
CCr01:
    ld  a,(iy)
    or  a
    jr  z,CCr02                         ; If NULL, done
    cp  " "
    jr  z,CCr02                         ; If ' ', done
    ld  (hl),a                          ; Otherwise put it in the 1st line 
    inc hl
    inc iy                              ; Adjust pointers
    djnz    CCr01                       ; If we haven't reached the limit, loop
CCr02:
    ld  (hl)," "                        ; And ends with a blank space
    ld  hl,WCB1                         ; channel WCB template
    ld  de,sWCB0                        ; For our main WCB
    ld  bc,24
    ldir                                ; Move template
    ld  ix,sWCB0
    call    CLS_TW                      ; Initialize screen buffer for it
    ; initialize nicknames windows
    ld  hl,WCB2                         ; Nick List template
    ld  de,sWCB1                        ; For secondary window
    ld  bc,24
    ldir                                ; Move template
    ld  ix,sWCB1
    call    CLS_TW                      ; Initialize screen buffer for it
    ; ini windows enter string
    ld  hl,WCB3                         ; Input window template
    ld  de,sWCB2                        ; Our last line window
    ld  bc,24
    ldir                                ; Move template
    ld  ix,sWCB2
    call    CLS_TW                      ; Initialize screen buffer for it
    ; initialize cursor
    xor a
    ld  (oldcur),a
    ld  (oldcur+1),a
    ld  (oldcur+2),a
    ; clear ct buffer
    ld  hl,#8A00
    ld  bc,270
wi4:
    xor a
    ld  (hl),a                          ; 0 goes to memory 
    inc hl
    dec bc                              ; adjust pointer and counter
    ld  a,b
    or  c
    jr  nz,wi4                          ; Loop until all buffer is cleared (counter is 0)
    call    LOAD_S                      ; And load screen buffer in VRAM
    ; ini buffer for back loading
    ld  hl,#0019                        ; v-25
    bios    POSIT
    ld  a,1                             ; need new nick list
    ld  (nlnew),a
    call    BFSegT                      ; rebuild active segment table
    ld  a,(S_C)
    call    PUT_P2                      ; restore the segment that called for this channel creation
    or  a
    ret                                 ; and return

;======================================================================================
;   Channel control segment
;======================================================================================
CHAN:
tccw:
    ld  bc,(tsb)                        ; Bytes in input buffer
    ld  a,b
    or  c
    jr  z,tccwB                         ; Done if none
    ; Otherwise, that buffer has priority over keyboard input, so deal with it
    dec bc
    ld  (tsb),bc                        ; Decrement counter
    ld  hl,(tsb+2)                      ; Address in HL
    ld  a,(hl)                          ; Get its content
    inc hl
    ld  (tsb+2),hl                      ; Update pointer
    jp  tccwC                           ; And handle as key input
tccwB:
    ld  a,(S_C)
    call    PUT_P2                      ; Our channel segment @ P2
    call    SSIA                        ; Set the information attributes
    ld  ix,sWCB2                        ; Line Input WCB
    ld  hl,(sWCB2+WINDOW_VR_ADD)        ; VRAM Address in HL
    ld  d,0
    ld  e,(ix+WIN_H_POS)                ; Cursor Position
    add hl,de                           ; HL has the VRAM address
    call    CURSOR                      ; Set the cursor
    call    LOAD_S                      ; And put all on screen
tccw0:
    call    CLOCK                       ; Update clock and time on screen
    call    TCPSEP                      ; Check if there is data from server
    jp  SEL_RE                          ; Safe guard, just in case segment is lost, switch to different window, otherwise, will end-up in CHA_RE
CHA_RE:
    call    L_SIA                       ; Update the last line with the segment information
    ld  a,(w1new)
    or  a
    jr  z,CHA_RE1                       ; If no new nicklist, just update main screen if needed
    ld  ix,sWCB1                        ; Otherwise, Nicklist WCB in IX
    call    NICKOS                      ; Print it on screen
    xor a
    ld  (w1new),a
    ld  (w0new),a                       ; No new content for main screen and nick screen
    call    LOAD_S                      ; Put on screen
    jr  CHA_RE2                         ; and jump newsload
CHA_RE1:
    call    newsload                    ; Update in screen and clear the new content flag of the window descriptor
CHA_RE2:
    ld  c,_CONST
    call    DOS                         ; Check if key was pressed
    or  a
    jr  z,tccw0                         ; If no key pressed, just loop
    ; key was pressed
    ld  c,_INNO
    call    DOS                         ; Get key
tccwC:
    ld  b,a                             ; and move key to B
    ld  a,(S_C)
    call    PUT_P2                      ; Make sure channel segment is @P2
    ld  ix,sWCB2                        ; Any updates from here go to the line input window
    ld  hl,#FBEB                        ; 6th keyboard matrix row address
    ld  a,b                             ; Key back in A
    bit 6,(hl)
    jp  z,tcc_F2                        ; F2 -> Navigate Nick List
    bit 5,(hl)
    jp  z,Ls_help                       ; F1 -> Go to Help
    cp  #0D
    jp  z,tcc_se                        ; Enter -> send whatever is in our input window
    cp  ESC_
    jp  z,tcc_ESC                       ; Back to main system menu
    cp  11
    jp  z,tcc_home                      ; CLS/HOME go to back to the last line of the channel window
    cp  UP_
    jp  z,tcc_UP                        ; Go one line up if control is pressed or one page up if shift is pressed
    cp  DOWN_
    jp  z,tcc_DW                        ; Go one line down if control is pressed or one page down if shift is pressed
    cp  24
    jp  z,tcc_F2                        ; SELECT - also navigate the nick list
    bit 1,(hl)
    jr  nz,tccWNC                       ; If control not pressed, Q is not tested
    cp  17                              ; Control is pressed, but is Q pressed as well?
    jp  z,tcc_Q                         ; If so, CTRL+Q -> Close Window
tccWNC:
    ; Check if key is related to input window editing functionality
    cp  8
    jp  z,tcc_bs                        ; "BS" <-
    cp  18
    jp  z,tcc_ins                       ; INS
    cp  127
    jp  z,tcc_del                       ; DEL
    cp  LEFT_
    jp  z,tcc_left                      ; Move cursor left
    cp  RIGHT_
    jp  z,tcc_right                     ; Move cursor right
    ; ok, normal character input, so let's handle it and update input winwdow
    ex  af,af'                          ; Let's use shadow AF and keep character in original AF
    ld  a,(s_ins)                       ; Current insert option
    or  a
    jr  z,tcc_r4                        ; no insert option
    ; Insert is ON
    ld  hl,(sWCB2+WIN_RAM_B_END)
    ld  e,l
    ld  d,h                             ; Buffer End of Input Window on DE
    dec hl                              ; HL has it adjusted
    ld  bc,(sWCB2+WIN_RAM_B_CUR)
    xor a                               ; Clear carry
    sbc hl,bc
    jr  c,tcc_r4                        ; If HL equal or greater, cursor in last position, not goint to insert
    ; Yeah, going to insert on cursor position
    inc hl                              ; HL adjusted
    ld  c,l
    ld  b,h                             ; And it is now the count of characters to "shift" to allow a character to be inserted
    ld  l,e
    ld  h,d                             ; Origin is the last buffer byte
    inc de                              ; Destination is origin + 1
    ld  (sWCB2+WIN_RAM_B_END),de        ; New buffer end
    inc bc                              ; Adjust count
    lddr                                ; And move last to last + 1, from last to insert position
tcc_r4:
    ex  af,af'
    ; save char to buff
    ld  hl,(sWCB2+WIN_RAM_B_CUR)
    ld  (hl),a                          ; Save in buffer
    inc hl
    ld  (sWCB2+WIN_RAM_B_CUR),hl        ; Save new current
    ld  de,(sWCB2+WIN_RAM_B_END)
    xor a                               ; Clear Carry
    sbc hl,de
    jr  c,tcc_r3                        ; If carry, no more space
    inc de
    ld  (sWCB2+WIN_RAM_B_END),de        ; There is, so adjust end
tcc_r3:
    ld  a,(ix+WIN_H_POS)
    ld  b,(ix+WIN_H_SIZE)
    dec b                               ; adjust size, column start at 0, size at 1
    cp  b                               ; screen cursor at last position?
    jr  nc,tcc_r1                       ; yes, last position
    ; not last position, inc h pos
    inc a
    ld  (ix+WIN_H_POS),a
    jr  tcc_r2                          ; And go to update screen
tcc_r1:
    ; Cursor on last position
    ld  hl,(sWCB2+WIN_L_STR_ADD)
    inc hl
    ld  (sWCB2+WIN_L_STR_ADD),hl        ; Update the last so it will "scroll"
tcc_r2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  tccw                            ; And done, loop


tcc_ins:
    ld  a,(s_ins)                       ; And done, loop
    cpl                                 ; invert
    ld  (s_ins),a                       ; New insert option, now toggled
    jp  tccw                            ; And done, loop


tcc_left:
    bit 1,(hl)
    jp  z,S_LEFT                        ; If control, check if there is a window to our left to jump to
    ; No control, so let's check if we can navigate our input window to the left
    ld  de,(sWCB2+WIN_RAM_B_CUR)
    ld  hl,(sWCB2+WIN_RAM_B_ADD)
    xor a                               ; Clear flag
    sbc hl,de                           ; ADD - CUR will have size and carry
    jp  nc,tccw                         ; if no carry, cursor position is in first position, back to loop
    dec de                              ; Decrement
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; Save
; LEFT
    dec (ix+WIN_H_POS)                  ; c_cur --
    jp  p,tccL1                         ; > 0 norm
    ; Ooops, it was zero
    inc (ix+WIN_H_POS)                  ; c_cur ++, back to 0
    ld  (sWCB2+WIN_L_STR_ADD),de        ; And adjust the position of the last shown, as this is a scroll
tccL1:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  tccw                            ; And done, loop


tcc_right:
    bit 1,(hl)
    jp  z,S_RIGHT                       ; If control, check if there is a window to our right to jump to
    ld  de,(sWCB2+WIN_RAM_B_CUR)
    ld  hl,(sWCB2+WIN_RAM_B_END)
    inc de
    xor a                               ; Clear flag
    sbc hl,de
    jp  c,tccw                          ; if carry, cursor at last position, back to loop
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; Otherwise, new position
    ld  b,(ix+WIN_H_SIZE)               ; H-size
    ld  a,(ix+WIN_H_POS)                ; h_cur
    inc a                               ; Adjust as size starts with 1 and pos with 0
    cp  b
    jp  nc,tcc_R1                       ; If not carry, at last screen position, so do not update cursor position
    ld  (ix+WIN_H_POS),a                ; Otherwise, save the new position
    jr  tcc_R2                          ; And good to display and be done
tcc_R1:
    ; If here, cursor at last screen position, but there is data to the right, so "scroll"
    ld  hl,(sWCB2+WIN_L_STR_ADD)
    inc hl
    ld  (sWCB2+WIN_L_STR_ADD),hl        ; Update the last to be shown on screen
tcc_R2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  tccw                            ; And done, loop


tcc_del:
    ld  hl,(sWCB2+WIN_RAM_B_CUR)
    ld  de,(sWCB2+WIN_RAM_B_END)
    dec de                              ; Adjust END to check how it will be after "deleting"
    xor a                               ; Clear flag
    sbc hl,de                           ; CUR - END -> Should be 0 or Carry if there is something to delete, cursor should not be at end (thus why DE = END -1)
    jr  c,tcc_del1                      ; negative number, so will need to shift/scroll
    jp  nz,tccw                         ; 0 means one to delete, no need to shift/scroll, non-zero means nothing in front of cursor to delete
tcc_del1
    ld  (sWCB2+WIN_RAM_B_END),de        ; Save adjusted end
    jr  z,tcc_del2                      ; 0 -> No need to shift / scroll
    ; scroll right part string
    inc de                              ; de back to end
    xor a                               ; Clear flag
    add hl,de                           ; hl = b_cur  de = b_end-1 old
    ex  de,hl                           ; hl = b_end new de = B_cur
    sbc hl,de                           ; hl = characters to move / delete
    ld  c,l
    ld  b,h                             ; Count
    ld  l,e
    ld  h,d
    dec hl                              ; HL is current position - 1
    inc bc                              ; Adjust count
    ex  de,hl                           ; Current position - 1 in DE, HL current position, so that is our copy
    ldir                                ; And copy
tcc_del2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  tccw                            ; And done, loop


; "back space" delete last symbol in position before cursor
tcc_bs:
    ld  hl,(sWCB2+WIN_RAM_B_ADD)
    ld  de,(sWCB2+WIN_RAM_B_CUR)
    xor a                               ; Clear Carry
    sbc hl,de                           ; |<- X
    jp  nc,tccw                         ; not possible to BS, back to loop
    dec de
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; will be back a position, adjust
    ; bs
    dec (ix+WIN_H_POS)                  ; c_cur --
    jp  p,tccbs1                        ; > 0, ok to go
    ; No, so will need to shift a little as cursor is in first display position for input window
    inc (ix+WIN_H_POS)                  ; c_cur ++, back to 0
    ld  (sWCB2+WIN_L_STR_ADD_MSB),de    ; Adjust last position to shift
tccbs1: 
    ;scroll right part strint to left on 1 byte
    ld  hl,(sWCB2+WIN_RAM_B_END)
    dec hl
    ld  (sWCB2+WIN_RAM_B_END),hl        ; adjust endbuff decreasing the character erased by back space
    xor a                               ; Clear carry
    sbc hl,de                           ; New end position - new cursor position
    ld  a,h
    or  l
    jr  z,tccbs2                        ; If 0, no content to scroll / shift
    ld  c,l
    ld  b,h                             ; Otherwise, HL has the number of characters to scroll to the left
    ld  l,e
    ld  h,d                             ; DE is destination new cursor position
    inc hl                              ; HL is source, one character after new cursor position
    ldir                                ; and move all
tccbs2:
    call    OUTSTRW                     ; Update WCB2 on screen (input Window)
    jp  tccw                            ; And done, loop


; Enter was hit, so send if any string
tcc_se:
    call    CLS_TW                      ; clear input window
    xor a
    ld  (ix+WIN_H_POS),a
    ld  (ix+WIN_V_POS),a                ; Cursor at 0x0
    ld  hl,(sWCB2+WIN_RAM_B_END)
    ld  (hl),#0D
    inc hl
    ld  (hl),#0A                        ; Finish with CR/LF, irc protocol
    inc hl                              ; curs
    ld  de,(sWCB2+WIN_RAM_B_ADD)        ; buff
    ld  (sWCB2+WIN_RAM_B_CUR),de        ; curs at start of buff
    ld  (sWCB2+WIN_L_STR_ADD),de        ; last is start, so, nothing
    ld  (bbuf),de                       ; save in BBUF 
    xor a                               ; Clear carry
    sbc hl,de                           ; HL -> count of how many characters to send
    ld  (lenb),hl                       ; save in LENB
    ld  (sWCB2+WIN_RAM_B_END),de        ; Buffer End at beginning as well
    call    BuffOU                      ; Not empty, so, BuffOU will send it to the server and print on the main window
    jp  tccw                            ; And done, loop


tcc_home:
    ld  ix,sWCB0
    ld  hl,#C000
    ld  (sWCB0+WIN_RAM_B_CUR),hl
    call    PPBC
    jp  tccw


tcc_UP:
    ld  ix,sWCB0
    bit 0,(hl)                          ; if 0 - SHIFT
    jp  z,tccUPvPU                      ; View channel buffer UP 1 page
    bit 1,(hl)                          ; if 0 - CTRL
    jp  z,tccUPvU                       ; View channel buffer UP 1 string
    jp  tccw                            ; if no shift or control, nothing to do, back to loop


tcc_DW:
    ld  ix,sWCB0
    bit 0,(hl)                          ; if 0 - SHIFT
    jp  z,tccDWvPD                      ; View channel buffer UP 1 page
    bit 1,(hl)                          ; if 0 - CTRL
    jp  z,tccDWvD                       ; View channel buffer UP 1 string
    jp  tccw                            ; if no shift or control, nothing to do, back to loop


tccUPvPU:
    ld  d,(ix+WIN_V_SIZE)               ; Limit of lines in D
    jr  tccU2
tccUPvU:
    ; View channel buff UP 1 string (a string means a full line received, no matter if fits one line in window or more)
    ld  d,1                             ; Just 1 line
tccU2:
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
    dec hl
    dec hl
tccU3:
    ld  a,#0A
tccU1:
    cpdr
    jr  nz,tccU1                        ; will look back until find a new line, indicating end of previous string
    dec d                               ; decrement line count
    jr  nz,tccU3                        ; do it again until line count is 0
    inc hl
    inc hl                              ; adjust
    ex  de,hl                           ; now in DE
    ld  hl,(sWCB0+WIN_RAM_B_ADD)
    xor a                               ; Clear carry
    dec hl
    sbc hl,de                           ; hl-de=?
    jp  nc,tccw                         ; if no carry, nothing to update, back to loop
    ld  (sWCB0+WIN_RAM_B_CUR),de        ; Otherwise update current
    call    PPBC                        ; Print Part of Buffer Channel
    jp  tccw                            ; And done


tccDWvPD:
    ld  d,(ix+WIN_V_SIZE)               ; Limit of lines in D
    jr  tccD0
tccDWvD:
    ; View channel buff Down 1 string
    ld  d,1                             ; Just 1 line
tccD0:
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
tccD2:
    ld  a,#0A
tccD1:
    cpir
    jp  nz,tccD1                        ; will look forward until find a new line, indicating end of next string
    ld  a,h
    cp  #C0
    jr  nc,tccD3                        ; out of buffer hl > #C000
    dec d                               ; decrement line count
    jr  nz,tccD2                        ; do it again until line count is 0
tccD4:
    ld  (sWCB0+WIN_RAM_B_CUR),hl
    call    PPBC                        ; Print Part of Buffer Channel
    jp  tccw                            ; And done
tccD3:
    ld  hl,#C000                        ; set cur end of buffer
    jp  tccD4

tcc_ESC:
    call    CURSOFF
    ld  a,(segp)
    ld  (segsel),a                      ; segment displayed is now segment selected
    jp  SYS_S


;   Select Nick -> Select Nick operation
tcc_F2:
    call    CLKB                        ; clear keyboard buffer, F key...
    ld  a,(S_C)
    call    PUT_P2                      ; Make sure our segment is @ P2
    ld  ix,sWCB1                        ; nick list window
    ; test for nicks empty
    ld  a,(ix+NICK_COUNT)
    or  a
    jp  z,tccw                          ; If no nick, done (well, it should have at least ours...)
    ; cursor on
    xor a
    ld  a,(ix+WIN_LIST_ITEM_SEL)
    or  a
    jr  nz,nks0                         ; If not 0, item selected is fine
    ld  b,(ix+5)
    cp  b
    jr  c,nks0
    ld  a,1
    ld  (ix+WIN_LIST_ITEM_SEL),a        ; n_cur =1
nks0:
    ; draw nick's box on channel window
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
; out full nickname to nickname box
    ld  a,(ix+22)
    add a,(ix+10)   ; a - npos nick in buffer
    or  a
    jr  z,nks8  ; no curs
    ld  d,a
    ld  bc,#300 ; **
    ld  a," "
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

    cp  UP_
    jp  z,nks_UP
    cp  DOWN_
    jp  z,nks_DW
    cp  LEFT_
    ; Oh, unfinished plans... for now, left does... nothing
    cp  RIGHT_
    ; Oh, unfinished plans... for now, right does... nothing
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


; quit channel - part #channel , close channel
tcc_Q:
    call    CURSOFF
    call    TCP_PARTC                   ; part
    ; close
    ld  a,(segp)
    call    FRE_RECS
    call    BFSegT
    jp  S_LEFT                          ; And go to the window to our left

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
    ld  de,(sWCB1+12)
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
    inc hl                              ; Jump segment type to segment in mapper
    ld  a,(hl)                          ; in A
    ld  (S_C),a                         ; main window segment
    ld  a,(segsel)
    ld  (segp),a                        ; segment selected in segment displayed
    jp  QUEC                            ; Main loop for query/private message window

; Create Query record (Query segment)
QUERY_C:
; test on exist some query
; Find query segment
    ld  a,"Q"
    ld  de,PA_QNICK
    call    SrS                         ; Search if segment for it already exists
    jr  c,QUE_NOq                       ; If carry, doesn't exist, need to create
    ret                                 ; If exists, done
QUE_NOq:
    call    CLAT_C_N
;
    call    ALL_REC
    ld  a,b
    ld  (segp),a
    jp  c,NO_REC_M
    push    hl
    ld  a,0
    ld  b,a                             ; Primary mapper only
    call    ALL_SEG
    jp  c,NO_SEG_M
    pop hl                              ; Restore MAP Table entry
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

    jp  SEL_RE
QUE_RE:
    call    L_SIA
    
    call    newsload


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
    call    CURSOFF
    ld  a,(segp)
    ld  (segsel),a                      ; segment displayed is now segment selected
    jp  SYS_S
QUE_Q:  ;close record
    call    CURSOFF
    ld  a,(segp)
    call    FRE_RECS
    call    BFSegT
    jp  S_LEFT;

;--- Handle according to the screen that is being displayed
SEL_RE:
    ld  a,(#8000+3)
    cp  "Q"
    JP  Z,QUE_RE                        ; Query/Private Message
    cp  "C"
    jp  z,CHA_RE                        ; Channel
    cp  "S"
    jp  z,SRV_RE                        ; Server Window
    cp  "H"
    jp  z,HLP_RE                        ; Help
    jp  SYS_S                           ; Otherwise, main menu


;**************************************************************************
; Segment / Records handling routines
;**************************************************************************

; Free record & segment related to it
; a - num of record
FRE_RECS:
    ld  c,a
    ld  a,79
    cp  c
    ret c                               ; If record # > 79, nothing to be done, we handle up to 80, 0 to 79
    rl  c                               ; Multiply by 2, as each MAPTAP entry is 2 bytes long
    ld  b,0                             ; And 79 * 2 = 158, less than 255, so b will always be 0
    ld  hl,MAPTAB
    add hl,bc                           ; HL now has the position of that record
    xor a
    ld  (hl),a                          ; Set to 0, record is now free
    inc hl
    ld  a,(hl)                          ; Load the segment related to the record in A
    jp  FRE_SEG                         ; Free it and return from there


; Get Free Segment Record in MAP TABLE
; input - none
; output B - record #, HL - enter record Table (HL) - status (HL+1) - segment (data empty!)
ALL_REC:
    ld  hl,MAPTAB                       ; Segment Table
    ld  b,0                             ; Record counter
ALL_r1:
    ld  a,(hl)
    or  a                               ; Is it free?
    ret z                               ; Yeah, done
    inc b
    inc hl
    inc hl                              ; No, adjust counter and jump to next record
    ld  a,79
    cp  b
    ret c                               ; If more than 79, browsed through it all, return
    jr  ALL_r1                          ; Otherwise loop

;--- Segment related errors

; No more space in the segment record table, wow, you were able to open 80 Windows, congratulations!
NO_REC:
    ld  hl,SM_NOREC
    call    PRINT_TW
    jp  SYS_S

; Usually failed to allocate a segment from mapper, meaning no more segments free, gotta use them all!
NO_SEG:
    pop hl                              ; Restore stack Balance
    ld  hl,SM_NOSEG
    call    PRINT_TW
    jp  SYS_S

; Can't recreate a server window, once created, that is a done deal
NO_SERV:
    ld  hl,SM_NOSERV
    call    PRINT_TW
    jp  SYS_S

; Can't create Query / Private message Window
NO_REC_M:
    ld  hl,SM_NOREC
    jp  PRINT_TW

; Faile to allocate segment Query / Private message window
NO_SEG_M:
    pop hl                              ; Restore stack Balance
    ld  hl,SM_NOSEG
    jp  PRINT_TW

; Find segment
; Input   A     - descriptor ("H"/"S"/"C"/"Q")
;         DE    - string name "..."
; Output  A     - mapper segment
;         (HL)  - mapper segment
;         CF    - set if not found 
;     set P2 page to the one of the segment, if found
SrS:
    ld  c,a                             ; Descriptor in C
    ld  hl,MAPTAB                       ; Our segment table
    ld  b,80                            ; It has up to 80 entries
SrS2:
    ld  a,(hl)                          ; Get descriptor
    and %01111111                       ; Mask 8th bit
    cp  c
    jr  z,SrS1                          ; If it is the descriptor let's select it
    ; It was not
    inc hl
    inc hl                              ; Jump segment of this item in table and point to the next descriptor
    dec b                               ; decrease our limiter counter
    jr  nz,SrS2                         ; if did not browse through all table, loop
    scf                                 ; sorry, browse it all and did not find
    ret
    ;--- Found the descriptor
SrS1:
    call    GET_P2
    ld  (tsegt),a                       ; Save the current segment in P2 in tsegt
    inc hl
    ld  a,(hl)                          ; Get the segment that has been found
    call    PUT_P2                      ; And select it
    push    hl                          ; Save HL
    push    de                          ; And DE
    ld  hl,#8005
    call    STRCMPSP                    ; Now let's check if it is the segment we are looking
    pop de
    pop hl                              ; Restore HL and DE
    jr  z,SrS3                          ; If STRCMPSP returned 0, found it!
    ;--- Sorry, it was not the one we wanted
    ld  a,(tsegt)
    call    PUT_P2                      ; Restore the PAGE2 back
    inc hl                              ; adjust to point the next item in table
    ld  a,c                             ; Restore descriptor
    jr  SrS2                            ; Loop
SrS3:
    ;--- Put the segment in A and leave it selected
    ld  a,(hl)
    ret


;--- STRCMPSP: Compares two strings that are either 0 or space terminated
;    Input: HL, DE = Strings
;    Output: Z if strings are equal
STRCMPSP:
    ld  a,(de)
    cp  (hl)
    ret nz                              ; Compare if (HL) = (DE)
    or  a
    ret z                               ; If 0, end of string
    cp  " "
    ret z                               ; If space, end of string
    inc hl
    inc de                              ; Increment pointers
    jr  STRCMPSP                        ; Loop

CLOSE_MY_TCP_CONN:
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_CLOSE
    call    CALL_U
    ret


;--- EXIT gracefully, returning text mode back to normal
EXIT:
    ld  a,(serv1c)
    or  a
    jr  z,EXIT_NOCONN
    ; If here, there was a connection, so let's close it
    call    CLOSE_MY_TCP_CONN
EXIT_NOCONN:
    bios    INITXT
    ld  a,(DOS2)                        ; DOS 2, the CTRL-C
    or  a                               ; control routine has to be cancelled first
    ld  de,0
    ld  c,_DEFAB
    call    nz,DOS                      ; So cancel it if using DOS2
    ld  c,_TERM0
    jp  DOS


; TCP/IP subroutine
;******************************
;* Main TCP/IP Routines
;******************************

CONNECT_S:
    ;--- Attemps to connect server
    ld  hl,PA_SERVER
    ld  de,HOST_NAME
EE7:
    ld  a,(hl)
    ld  (de),a
    inc hl
    inc de
    or  a
    jr  nz,EE7                          ; Copy the server from ini to HOST NAME
EE6:
    ld  hl,HOST_NAME
    call    PRINT_BF                    ; Print the name of where we are connecting to
    ld  hl,HOST_PORT_SEPARATOR
    call    PRINT_BF                    ; separetes server name of port
    ;--- Obtains remote port 
    ld  hl,PA_PORT
    ld  de,BUFFER
EE8:
    ld  a,(hl)
    ld  (de),a
    inc hl
    inc de
    or  a
    jr  nz,EE8                          ; Copy port to BUFFER
EE9:
    ld  hl,BUFFER
    call    PRINT_BF                    ; Print the port

EE5:
    ld  hl,BUFFER
    call    EXTNUM16                    ; Convert port to 16 bits number
    jp  c,INVPAR                        ; Error if not a valid number

    ld  (PORT_REMOTE),bc                ; And move to the connection parameters

    ;------------------------------------------------------------
    ;---  Host name resolution and TCP connection initiation  ---
    ;------------------------------------------------------------

    ;>>> Resolve host name

    ld  hl,RESOLVING_S
    call    PRINT_BF
    ld  hl,HOST_NAME
    ld  b,0
    ld  a,TCPIP_DNS_Q
    call    CALL_U                      ; Query the resolver...
    ld  b,a                             ; ...and check for an error
    ld  ix,DNSQERRS_T
    or  a
    jr  nz,DNSQR_ERR
    ;* Wait for the query to finish
DNSQ_WAIT:
    ld  a,TCPIP_WAIT
    call    CALL_U
    call    CHECK_KEY                   ; To allow process abort with CTRL-C
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
    jr  nz,DNSQ_WAIT                    ; The request has not finished yet?
    ;* Request finished? Store and display result, and continue
    ld  (IP_REMOTE),hl                  ; Stores the returned result (L.H.E.D)
    ld  (IP_REMOTE+2),de
    ld  ix,RESOLVIP_S                   ; Displays the result
    ld  a,"$"
    call    IP_STRING
    ld  hl,RESOLVOK_S
    call    PRINT_BF
    ld  hl,TWO_NL_S
    call    PRINT_BF
    jp  RESOLV_OK                       ; Continues
    ;- Error routine for DNS_Q and DNS_S
    ;  Input: B=Error code, IX=Errors table
DNSQR_ERR:
    push    ix
    push    bc
    ;* Prints "ERROR <code>: "
    ld  ix,RESOLVERRC_S
    ld  a,b
    call    BYTE2ASC
    ld  (ix),":"
    ld  (ix+1)," "
    ld  (ix+2),"$"
    ld  hl,RESOLVERR_S
    call    PRINT_BF
    ;* Obtains the error code, display it and done
    pop bc
    pop de
    call    GET_STRING
    ex  de,hl
    call    PRINT_BF
    ret 
RESOLV_OK:
    ;>>> Close all transient TCP connections
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
    ld  hl,NOTCPA_S                     ; Active TCP open
    call    PRINT_BF
    ret
NO_NOT_IMP:
    ;* If error is other, get its message from the errors table
    push    af
    ld  hl,ERROR_S
    call    PRINT_BF
    pop af
    ld  b,a                             ; Error: Show the cause and done
    ld  de,TCPOPERRS_T
    call    GET_STRING
    ex  de,hl
    call    PRINT_BF
    ret
OPEN_OK:
    ld  a,b
    ld  (CON_NUM),a                     ; No error: saves connection handle
    ld  hl,OPENING_S
    call    PRINT_BF
WAIT_OPEN:
    ld  a,TCPIP_WAIT
    call    CALL_U
    ld  a,(CON_NUM)
    ld  b,a
    ld  hl,0
    ld  a,TCPIP_TCP_STATE
    call    CALL_U
    or  a
    jr  z,WAIT_OPEN2
    push    bc
    ld  hl,ONE_NL_S
    call    PRINT_BF
    pop bc
    ld  de,TCPCLOSED_T                  ; If the connection has reverted to CLOSED,
    ld  b,c
    set 7,b
    call    GET_STRING                  ; show the reason and done
    ex  de,hl
    call    PRINT_BF
    ret
WAIT_OPEN2:
    ld  a,b
    cp  4                               ; 4 = code for ESTABLISHED state
    jr  nz,WAIT_OPEN
    ld  hl,OPENED_S
    call    PRINT_BF
    ld  hl,NB_BU
    ld  (B_BU),hl
    ld  (E_BU),hl                       ; Initialize Begin Buffer and End Buffer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;--- Auto NICK, USER
    ld  hl,#FFFF
    ld  de,AA_NICK-1
AN_1:
    inc hl
    inc de
    ld  a,(de)
    or  a
    jr  nz,AN_1                         ; Loop until finding a zero terminator
    ; hl - length string
    ld  a,(CON_NUM)
    ld  b,a
    ld  de,AA_NICK
    ld  c,1                             ; "Push" is specified so it is sent as fast as possible
    ld  a,TCPIP_TCP_SEND                ; And send the nick
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR                    ; Should return ok
    ld  hl,2
    ld  de,AA_CRLF
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U                      ; And send CR LF so irc server knows the command is done
    or  a
    jp  nz,TCP_ERROR                    ; Should return ok
    ld  hl,#FFFF
    ld  de,AA_USER-1
AN_2:
    inc hl
    inc de
    ld  a,(de)
    or  a
    jr  nz,AN_2                         ; This loop is exactly as AN_1 but for user information
    ; hl - length string
    ld  a,(CON_NUM)
    ld  b,a
    ld  de,AA_USER
    ld  c,1                             ; "Push" is specified so it is sent as fast as possible
    ld  a,TCPIP_TCP_SEND                ; And send the user information
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR                    ; Should return ok
    ld  hl,2
    ld  de,AA_CRLF
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U                      ; And send CR LF so irc server knows the command is done
    or  a
    jp  nz,TCP_ERROR                    ; Should return ok
    ld  a,1
    ld  (serv1c),a                      ; We are connected to the server
    ld  hl,(timer)
    ld  (tcptim),hl                     ; And load current jiffy at tcptim
    ret

;--- Check if there is data from server, and if there is, if it is completed so we can proccess it, otherwise, buffer it
;    A Dead connection will most likely be detected here as well
TCPSEP:
    ld  a,(serv1c)
    or  a
    ret z                               ; If not connected to IRC Server, nothing to do
    xor a
    ld  hl,(timer)                      ; JIFFY Counter in HL
    ld  de,(tcptim)                     ; TCPTIM in DE
    sbc hl,de
    ret z                               ; If both equal, do nothing, wait a tick to elapse before checking again
    ld  a,(CON_NUM)
    ld  b,a                             ; Connection # in B
    ld  de,(E_BU)                       ; The current buffer END in DE
    ld  hl,1024                         ; Read up to 1KB
    ld  a,TCPIP_TCP_RCV                 ; And receive data, if any
    call    CALL_U                      ; Execute UNAPI function
    or  a
    jp  nz,TCP_ERROR                    ; If a NZ it is an error...
    ld  hl,(timer)
    ld  (tcptim),hl                     ; update TCPTIM with current JIFFY
    ld  a,b
    or  c                               ; BC indicates that received something?
    jp  z,END_RCV                       ; If Z, no data available, check if connection still is up and return
TCP_RCVOK:
    ld  hl,(E_BU)
    add hl,bc
    ld  (E_BU),hl                       ; Adjust END BUFFER pointer
    ld  a,(S_C)
    ld  (T_S_C),a                       ; Current Segment in T_S_C
TCP_RCV1:
    ld  hl,(E_BU)                       ; Buffer End
    ld  bc,NB_BU                        ; Buffer Start
    xor a                               ; Clear Flag
    sbc hl,bc
    ret z                               ; buffer empty if E_BU hit NB_BU
    ld  b,h
    ld  c,l                             ; Received packet lenght
    ld  hl,NB_BU                        ; Starting at buffer beggining
    ld  a,#0A
    cpir                                ; find end string  [0D][0A]|[x]
    ret nz                              ; end of string not found ( wait for next TCP packet)
    ld  (B_BU),hl                       ; Pointer to the remaining part of the packet
    ld  de,NB_BU
    ld  (bbuf),de                       ; begin buffer
    xor a                               ; Clear flags
    sbc hl,de
    ld  (lenb),hl                       ; Buffer lenght
    call    RECIV_SEP                   ; Proccess the string that was received
    ld  de,(B_BU)
    ld  hl,(E_BU)
    xor a                               ; Clear flags
    sbc hl,de
    ld  b,h
    ld  c,l
    jp  z,tcprc1                        ; no more lines
    ; delete processed string
    push    bc                          ; save remaining count
    ld  hl,(B_BU)
    ld  de,NB_BU
    ldir                                ; move data back to beginning
    pop bc                              ; restore remaining count
tcprc1:
    ld  hl,NB_BU
    ld  (B_BU),hl
    add hl,bc
    ld  (E_BU),hl                       ; Adjust end buffer
    jp  TCP_RCV1                        ; And loop


; --- PING detected, respond to it
;       HL -> Just after "PING " in the server message
PROCESS_PING:
    ld  a,(hl)
    inc hl
    cp  " "
    jr  z,PROCESS_PING
    cp  ":"
    jr  z,PROCESS_PING
    cp  #0D
    jr  z,PROCESS_PING
    or  a
    jr  z,PROCESS_PING                  ; Loop while it is not different than space/:/CR
    ld  (POINT),hl                      ; server name possible start
    ; --- send PONG
    ld  de,AA_PONG
    ld  hl,5
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U                      ; Send message over connection
    or  a
    jp  nz,TCP_ERROR                    ; Should not error
    ; --- send server name
    ld  de,(POINT)                      ; Address in DE
    ld  hl,0                            ; Start with size 0
    push    de                          ; Save DE for now
PROCESS_PING.1:
    ld  a,(de)                          ; Get the character
    inc de
    inc hl                              ; increment counter and pointer
    cp  " "
    jr  z,PROCESS_PING.1
    cp  ":"
    jr  z,PROCESS_PING.1
    cp  0
    jr  z,PROCESS_PING.1
    cp  #0D
    jr  z,PROCESS_PING.1
    cp  #0A
    jr  z,PROCESS_PING.1                ; Loop while it is not different than space/:/CR/LF or NULL
    pop de                              ; restore DE
    ; This could be a secondary server to pong
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND
    call    CALL_U                      ; And send it
    or  a
    jp  nz,TCP_ERROR                    ; Should not error
; --- send CRLF
    ld  de,AA_CRLF
    ld  hl,2
    ld  a,(CON_NUM)
    ld  b,a
    ld  c,1
    ld  a,TCPIP_TCP_SEND                ; Send CR/LF to terminate command response
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR                    ; Should not error
    jp  END_KEY                         ; Done

; --- JOIN detected, create channel window...
;       HL -> Just after "JOIN " in the server message
PROCESS_JOIN:
    dec hl                              ; Adjust for loop
PROCESS_JOIN.1:
    inc hl                              ; Inc pointer
    ld  a,(hl)
    cp  ":"
    jr  z,PROCESS_JOIN.1                ; Skip if ':'
    cp  " "
    jr  z,PROCESS_JOIN.1                ; Skip if ' '
    ;--- copy channel name to parameter C_CHAN
    ld  de,C_CHAN
    ld  b,16                            ; Limit to 16
PROCESS_JOIN.2:
    ld  a,(hl)
    cp  " "
    jr  z,PROCESS_JOIN.3                ; if space, finished
    cp  ","
    jr  z,PROCESS_JOIN.3                ; if ',', finished
    cp  #0D
    jr  z,PROCESS_JOIN.3                ; if CR, finished
    or  a
    jr  z,PROCESS_JOIN.3                ; if NULL, finished
    ld  (de),a                          ; Otherwise copy to C_CHAN
    inc hl
    inc de                              ; Increment pointers
    djnz    PROCESS_JOIN.2              ; Decrement limit counter and loop
PROCESS_JOIN.3:
    ld  a," "
    ld  (de),a                          ; add a space
    inc de
    ld  a,":"
    ld  (de),a                          ; add a ':'
    inc de
    xor a
    ld  (de),a                          ; Null terminate
    ; control
    ld  hl,C_CHAN
    call    PRINT_BF                    ; send to screen
    ; request to create channel record, and will return from there
    jp  CHANNEL_C

; received string processing
RECIV_SEP:
; --- PING ?
    ld  hl,NB_BU
    ld  de,AA_PING
    ld  b,5
    call    STR_CP                      ; Compare up to 5 bytes, ping message
    jp  z,PROCESS_PING                  ; If it is a ping process it
; --- detect join (:[nick]!xxxxxxx JOIN :[#channel])
    ld  hl,NB_BU-1
DE4:
    inc hl
    ld  a,(hl)
    cp  a,":"
    jr  z,DE4                           ; First skip if the first character is ':'
    ld  de,PA_NICK
    ld  b,32
    call    STR_CP                      ; Compare and check if it is our nick, if it is, might be relevant
    jr  nz,DE_0                         ; invalid nick ou not a join....
    ld  a,(hl)
    cp  "!"
    jr  nz,DE_0                         ; If after nick not a '!', invalid or not a join...
    ; Now loop, if found CR or NULL, not a join, if a space, time to check if JOIN....
DE5:
    inc hl
    ld  a,(hl)
    or  a
    jr  z,DE_0
    cp  #0D
    jr  z,DE_0
    cp  " "
    jr  nz,DE5                          ; Loop until end of string or space is found
    inc hl
    ld  de,AA_JOIN
    ld  b,5
    call    STR_CP                      ; Compare and check if it is JOIN
    call    z,PROCESS_JOIN              ; "JOIN ", so let's do it...
;**************************************************************************
;**************************************************************************
DE_0:
; string analize procedure
;
; 1 - save addres part
    ld  hl,NB_BU
    ld  de,ADDRES
DED1:
    ld  a,(hl)
    cp  ":"
    jr  nz,DED2
    inc hl
    jr  DED1                            ; skip 1st ":"
DED2:
    ; address part save
    ld  a,(hl)
    ld  (de),a
    inc hl
    inc de
    cp  " "
    jr  nz,DED2                         ; loop until " "
    xor a
    ld  (de),a                          ; NULL terminate it
; 2 - command part decoder
;
; text command decoder
; hl pointer word of command
    call    DET_MSG                     ; Detect which type of message server has to us
    ld  bc,(LBUFF)
    jr  c,DEDSC                         ; did not find any known message
    cp  1
    jp  z,DE_NICK                       ; NICK
    cp  2
    jp  z,DE_PRIV                       ; PRIVMSG
    cp  3
    cp  4
    jp  z,DE_JOIN                       ; NOTICE or JOIN
    cp  5
    jp  z,DE_PART                       ; PART
    cp  6
    jp  z,DE_MODE                       ; mode
    cp  7
    jp  z,DE_KICK                       ; kick
    cp  8
    jp  z,DE_QUIT                       ; quit
    cp  9
    jp  z,DE_NL                         ; 353 nicklist
    cp  10
    jp  z,DE_ENL                        ; 366 end nicklist
; messages from server that were not detected go to server console
DEDSC:
    ld  de,NB_BU
    ld  (bbuf),de
    ld  hl,(B_BU)
    xor a
    sbc hl,de
    ld  (lenb),hl                       ; Update bbuf and lenb with message received
    ld  a,(serv1s+1)
    ld  (T_S_C),a
    call    PUT_P2                      ; put the server window segment in P2
DEDSC1:
    call    BuffOU1                     ; Send to server screen
    ld  a,(S_C)
    call    PUT_P2                      ; Put our segment back in P2
    ret                                 ; And done

    ; If message was detected...
    ; --- Those messages below will just go to their channel window, if not any, to the server window
DE_PART:
DE_MODE:
DE_KICK:
DE_QUIT:
DE_JOIN:
DE_JC:
    call    NEXTarg                     ; Jump to the next argument
    ld  a,":"
DE_J2:
    cp  (hl)
    jr  nz,DE_J1                        ; If next character is not ':' it is fine
    inc hl                              ; Otherwise skip it
    jr  DE_J2                           ; And loop until it is not
DE_J1:
    ld  de,C_CHAN
    call    COPYARG                     ; Copy argument to C_CHAN
    ld  a,"C"
    ld  de,C_CHAN
    call    SrS                         ; Check if it is a channel we have a window for
    jp  c,DEDSC                         ; If carry, do not have a window for that channel, so dump on server window
    ; We do have a window, so it is pertinent to it
DEDSCE:
    ld  de,NB_BU
    ld  (bbuf),de
    ld  hl,(B_BU)
    xor a
    sbc hl,de
    ld  (lenb),hl                       ; update bbuf and lenb with the message and it's size
    jp  DEDSC1                          ; The window segment is already on P2 thanks to SrS, so BuffOU1 will sent to it's screen and exit

    ; Private Message...
DE_PRIV:
    call    NEXTarg                     ; Jump to the next argument
    ; test on own nick
    push    hl                          ; Save address
    ld  de,PA_NICK
DE_P1:
    ld  a,(de)                          ; Our nick
    cp  (hl)                            ; message nick
    jr  nz,DE_P2                        ; continue if not equal
    inc hl
    inc de                              ; increment pointers
    jr  DE_P1                           ; loop until it doesn't match...
DE_P2:
    or  a
    jr  nz,DE_P3                        ; If NZ, did not match
    ; Ok, match
    ld  a,(hl)
    cp  " "                             ; Check if what is in HL is a separator, if it is not, then not match, we just finished our name before
DE_P3:
    pop hl                              ; Restore address
    ; if Z then Own Nick detected
    jp  z,DE_QUE
    ; Not nick -> channelname
    ; Find record 
    push    hl                          ; Save address again
    ld  a,"C"                           ; Channel record find
    ex  de,hl
    call    SrS                         ; Check if it is a channel we have a window for
    pop hl
    jp  c,DEDSC                         ; If carry, do not have a window for that channel, so dump on server window
    ; We do have a window, so it is pertinent to it, chanel P2 segment is active
DE_CC1:
    ld  (T_S_C),a                       ; Save the mapper segment to T_S_C
    call    NEXTarg                     ; jump to next argument
DE_C2:
    ld  a,(hl)
    cp  ":"
    jr  nz,DE_C1
    inc hl
    jr  DE_C2                           ; Check if ':' is present, if so, loop incrementing HL until it is not
DE_C1:
    ld  (bbuf1),hl                      ; bbuf1 pointing to it
    ld  bc,0                            ; Size count
    ld  a,13                            ; done when CR is found
DE_C3:
    cp  (hl)                            ; CR?
    inc hl
    inc bc                              ; Adjust counter and pointer
    jr  nz,DE_C3                        ; If not CR, loop
    inc bc                              ; increment counter once more
    ld  (lenb1),bc                      ; and lenb1 indicates the lenght
    ; out dest addres (nick)
    ld  hl,ADDRES
    ld  (bbuf),hl                       ; Store in ADDRES buffer
    ld  bc,0                            ; counter stats at 0
DE_C5:
    inc hl
    inc bc                              ; increment pointer and counter
    ld  a,(hl)
    cp  "!"
    jr  z,DE_C4                         ; If '!' done
    cp  " "
    jr  z,DE_C4                         ; If ' ' done
    or  a
    jr  z,DE_C4                         ; If NULL done
    jr  DE_C5                           ; Otherwise loop
DE_C4:
    ld  (hl)," "                        ; add a space at the end
    inc bc                              ; and increment counter to reflect that
    ld  (lenb),bc                       ; save count in lenb
    call    BuffOU1                     ; And to the Window buffer / Screen it goes
    ld  hl,(lenb1)
    ld  (lenb),hl
    ld  hl,(bbuf1)
    ld  (bbuf),hl                       ; bbuf and lenb now back to message
    jp  DEDSC1                          ; send to proper screen/buffer and say good bye
    ; Own nick detected...
DE_QUE:
    push     hl                         ; save HL
    ld  hl,ADDRES
    ld  de,PA_QNICK
    ; Will move from ADDRES to PA_QNICK
DE_Q2:
    ld  a,(hl)
    cp  "!"
    jr  z,DE_Q1                         ; If '!' done
    cp  " "
    jr  z,DE_Q1                         ; If ' ' done
    or  a
    jr  z,DE_Q1                         ; If NULL done
    ld  (de),a                          ; Copy to PA_QNICK
    inc hl
    inc de                              ; Increment pointers
    jr  DE_Q2                           ; Loop
DE_Q1:
    ld  a," "
    ld  (de),a                          ; add a space at the end
    inc de
    xor a
    ld  (de),a                          ; add NULL at the end
    call    QUERY_C                     ; search if segment for it exists, and if not, create. the segment will be there
    pop hl                              ; Restore HL
    ; Find query record ? itc query_C
    jp  DE_CC1

; Copy an argument from IRC response in HL to DE
; The copy in DE will ends with space and null
COPYARG:
COPA1:
    ld  a,(hl)                          ; Get byte
    cp  " "
    jr  z,COPA2
    cp  ","
    jr  z,COPA2
    cp  #0D
    jr  z,COPA2
    or  a
    jr  z,COPA2                         ; If space, comma, CR or NULL, end of argument
    ld  (de),a                          ; Otherwise copy argument to DE
    inc hl
    inc de                              ; Adjust pointers
    jr  COPA1                           ; Repeat
COPA2:
    ld  a," "
    ld  (de),a
    inc de
    xor a
    ld  (de),a                          ; Add a space and NULL at the end of the copy in DE and done
    ret

; Copy an argument from IRC response in HL to DE
; The copy in DE will ends with null
COPYARG0:
COPA_1:
    ld  a,(hl)                          ; Get byte
    cp  " "
    jr  z,COPA_2
    cp  ","
    jr  z,COPA_2
    cp  #0D
    jr  z,COPA_2
    or  a
    jr  z,COPA_2                        ; If space, comma, CR or NULL, end of argument
    ld  (de),a                          ; Otherwise copy argument to DE
    inc hl
    inc de                              ; Adjust pointers
    jr  COPA_1                          ; Repeat
COPA_2:
    xor a
    ld  (de),a                          ; Add NULL at the end of the copy in DE and done
    ret

;--- RPL_NAMREPLY: <channel> :[@|+]<nick> [@|+]<nick> [...]
DE_NL:
    call    DE_NLF                      ; Find the segment / window for that channel
    jp  c,DEDSC                         ; If carry, do not have a window for that channel, so dump on server window
    ld  a,":"
    cp  (hl)
    jr  nz,DE_NL2                       ; If not ':' no need to skip
    inc hl                              ; Otherwise skip it
DE_NL2:
    ex  de,hl                           ; DE has the address of first nick in nicklist
    ld  a,1
    ld  (w1new),a                       ; new content on nicklist...
    ld  ix,sWCB1                        ; nicklist window on IX
    ld  a,(nlnew)
    or  a
    jr  z,DE_NL3                        ; If not a new nl, no need to clear it
    ; Not new, need to clear nicklist
    ld  hl,(sWCB1+WIN_RAM_B_ADD)
    ld  (sWCB1+WIN_RAM_B_END),hl        ; End at start
    xor a
    ld  (ix+WIN_L_STR_ADD_LSB),a
    ld  (ix+WIN_L_STR_ADD_MSB),a        ; Original was +23 +24, but a WCB goes up to +23, seems like an error, I've changed it to 22 and 23, Last String on WCB
    inc a
    ld  (ix+10),a                       ; We have at least 1 nick, ours :)
DE_NL3:
    ld  hl,(sWCB1+WIN_RAM_B_END)        ; where we are going to place it
DE_NL6:
    ld  a,(de)
    cp  13
    jr  z,DE_NL5                        ; If CR, done
    or  a
    jr  z,DE_NL5                        ; If NULL, done
    ld  (hl),a                          ; Add it to ram buffer of W1
    cp  " "
    jr  nz,DE_NL4                       ; If space, do not count
    inc (ix+WIN_L_STR_ADD_MSB)          ; Temp char count of nick size?
DE_NL4:
    inc hl
    inc de                              ; Increment ponters
    jr  DE_NL6                          ; Loop
DE_NL5:
    ld  a," "
    ld  (hl),a                          ; Finish with space
    inc (ix+WIN_L_STR_ADD_MSB)
    inc hl
    ld  (sWCB1+WIN_RAM_B_END),hl        ; New end of buffer
    xor a
    ld  (hl),a                          ; null terminate it
    ld  (nlnew),a                       ; nicklist being initialized
    inc a
    ld  (w1new),a                       ; nicklist window has new content
    jp  DEDSCE                          ; And text go to window

DE_ENL:
    call    DE_NLF
    jp  c,DEDSC
    ld  a,1
    ld  (nlnew),a                       ; Nicklist done
    jp  DEDSCE                          ; And text go to window

;--- Find the segment / window for a given channel in a nicklist argument and select it @P2
DE_NLF:
    call    NEXTarg                     ; Jump 1st Argument
    call    NEXTarg                     ; Jump 2nd Argument
    ld  a,"#"
    cp  (hl)
    jr  z,DE_NL1                        ; If '#', we are at the channel
    call    NEXTarg                     ; Otherwise jump one more argument
DE_NL1:
    ld  de,C_CHAN
    call    COPYARG                     ; Save channel to C_CHAN
    inc hl
    push    hl                          ; And save HL with address of nicklist
    ld  a,"C"
    ld  de,C_CHAN
    call    SrS                         ; Get Channel Segment and select it @ P2
    pop hl                              ; Restore nicklist
    ret                                 ; Done


DE_NICK:
    ld  hl,NB_BU-1
DE_NI4: inc hl
    ld  a,(hl)
    cp  a,":"
    jr  z,DE_NI4
    ld  de,PA_NICK
    ld  b,32
    call    STR_CP
    jp  nz,DEDSC                        ; invalid nick
    ld  a,(hl)
    cp  "!"
    jp  nz,DEDSC                        ; different length nick
    ld  hl,NB_BU
    call    NEXTarg
    call    NEXTarg
    ld  a,":"
    cp  (hl)
    jr  nz,DE_NI5
    inc hl
DE_NI5:
    ld  de,PA_NICK
    call    COPYARG0
    jp  DEDSC                           ; And text go to window


;--- Check if the connection has lost the ESTABLISHED
;    state. If so, close the connection and terminate.
END_RCV:
    ld  a,(CON_NUM)
    ld  b,a
    ld  hl,0
    ld  a,TCPIP_TCP_STATE               ; We want to check the connection state
    call    CALL_U                      ; Execute function
    or  a
    jp  nz,TCP_ERROR                    ; If error, TCP_ERROR will check about it
    ld  a,b
    cp  4                               ; Check if connection state is ESTABLISHED
    jr  z,STATUS_OK                     ; If so, it is ok
    ;--- Hmmmm... Something seems wrong
    ld  a,(CON_NUM)                     ; So, close connection and print
    ld  b,a                             ; "Closed by remote peer" before terminating
    ld  a,TCPIP_TCP_CLOSE
    call    CALL_U                      ; Execute close
    ld  hl,TWO_NL_S
    call    PRINT_BF                    ; New Line
    ld  hl,PEERCLOSE_S+1
    call    PRINT_BF                    ; Peer Close Message
    ld  a,0
    ld  (serv1c),a                      ; Server no longer connected
    ret
STATUS_OK:
END_KEY:
;--- End of the main loop step:
;    Give the UNAPI code an opportunity to execute,
;    then repeat the loop.
    ld  a,TCPIP_WAIT
    call    CALL_U                      ; Call WAIT, each adapter will implement if needed or return immediatelly if not
    ret

; IRC Arguments are space separated
; NEXTarg has a IRC response in HL and will loop through that until space is found, then increase one more time HL and return
; So you effectively have the next argument
NEXTarg:
    inc hl
    ld  a,(hl)
    cp  " "
    jr  nz,NEXTarg
    inc hl
    ret


; TCP SEND
; lenb -> points to the lenght of data to be sent
; bbuf -> points to the data to be sent
TCPSEND:
    ld  a,(serv1c)
    or  a
    ret z                               ; If no server connection, can't send, done
    ;--- insert module irc adapting string
    xor a
    ld  (ME_STATUS),a
    ld  iy,(bbuf)
    ld  bc,(lenb)
    ld  a,b
    or  c
    ret z                               ; If len = 0, nothing to do
    ld  a,(iy)
    cp  "/"
    jr  nz,GI_C1                        ; if first character is not '/', it is a regular msg string
    ; First is a '/', so it is a command
    ld  a,(#FBEB)
    and #00000010                       ; ctrl
    jr  z,GI_C1                         ; If control is pressed, skip command detector
; new command detector
    ld  de,D_COMM
    ld  hl,(bbuf)
    inc hl
    call    DET                         ; 1-nick, 2-join, 3-query, 4-part
    jr  c,GII_OLD
    cp  5
    jp  z,G_query
    cp  6
    jp  z,G_query

GII_OLD:
;--- command line (/command parametrs)
    ld  a,(iy+1)                        ; first character after '/'
    and %11011111                       ; uppercase it
    cp  "M"                             ; detect /me
    jr  nz,GI_C4                        ; not /me
    ld  a,(iy+2)                        ; second character after '/'
    and %11011111                       ; uppercase it
    cp  "E"
    jr  nz,GI_C4                        ; not /me
    ld  a,(iy+3)                        ; third character after '/'
    cp  " "
    jr  nz,GI_C4                        ; not /me
;--- /ME detected
    ld  bc,(lenb)
    dec bc                              ; [/ME_] X
    dec bc
    dec bc
    ld  (lenb),bc
    inc iy
    inc iy
    inc iy
    inc iy
    ld  (bbuf),iy                       ; skip '/me '
    ld  bc,(lenb)
    dec bc
    dec bc
    dec bc
    ld  hl,(bbuf)
    add hl,bc                           ; end of buffer
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
    ld  bc,(lenb)
    dec bc
    ld  (lenb),bc
    inc iy
    ld  (bbuf),iy
    jr  GI_E1
GI_C1:
;--- regular string message for current channel
GI_C2:
;
;test server consol
    ld  a,(serv1s+1)
    ld  b,a
    ld  a,(S_C)
    cp  b
    jp  z,GI_NO_Chann   ; Not channel - send msg stop


;    1p - send "PRIVMSG "
    ld  de,AA_PRIVMSG
    ld  hl,8
    ld  c,1
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
    ld  de,0
    ld  hl,#8000+5
    ld  a," "
GI_C3:  cp  (hl)
    inc hl
    inc de
    jr  nz,GI_C3
    ex  de,hl
; hl    - lenght string
    ld  a,(CON_NUM)
    ld  b,a
    ld  de,#8000+5
    ld  c,1     ;"Push" is specified
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
; send ":"
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
    ld  hl,(lenb)
    ld  a,(CON_NUM) ;Sends the line to the connection
    ld  b,a
    ld  de,(bbuf)
    ld  c,1     ;"Push" is specified
    ld  a,TCPIP_TCP_SEND
    call    CALL_U
    or  a
    jp  nz,TCP_ERROR
    jp  END_KEY1
;
GI_NO_Chann:
    ld  hl,YANCH_S
    call    PRINT_BF
    jp  END_KEY1

END_KEY1:
    ;
    ;--- End of the main loop step:
    ;    Give the UNAPI code an opportunity to execute,
    ;    then repeat the loop.
    ld  hl,(timer)
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

;--- Jump here in case a call to TCP_XXXXX return an error.
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
    ex  de,hl
    call    PRINT_BF
    ld  a,(CON_NUM)
    ld  b,a
    ld  a,TCPIP_TCP_CLOSE
    call    CALL_U
    xor a
    ld  (serv1c),a
    ret

;* The error is "Connection is closed"
;  (cannot be ERR_CONN_STATE, since the
;  connection is either CLOSED, ESTABLISHED or CLOSE-WAIT;
;  and we assume that it is not ERR_INV_PARAM nor ERR_NOT_IMP):
;  Print the cause and finish
TCP_ERROR2:
    ld  hl,TWO_NL_S
    call    PRINT_BF
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
    call    PRINT_TERM
    jp  CLOSE_MY_TCP_CONN

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
    push    hl
    ld  a,(#80)
    ld  c,a ;Adds 0 at the end
    ld  b,0 ;(required under DOS 1)
    ld  hl,#81
    add hl,bc
    ld  (hl),0
    pop hl
    pop af

    push    hl
    push    de
    push    ix
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
CHECK_KEY:
    ld  e,#FF
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

B2A_1D: add "0"
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
;--- Notice that unlike TCPCON, which this code was based, here we
;    won't leave the UNAPI in segment 1, always reverting back to
;    our own ram segment.

; This will overwrite CALL_U if mapper unapi implementatioin
; CALL_um+2  -> UNAPI Impl. Slot
; CALL_um+8  -> UNAPI Impl. Entry Function Address
; CALL_um+12 -> Our Appl. Slot
CALL_um:                                ;[18] +2, +8, +12
    push    af                          ;+0
    ld  a,0                             ;+1 +2
    call    PUT_P1                      ;+3 +4 +5
    pop af                              ;+6
    call    0                           ;+7 +8 +9
    push    af                          ;+10
    ld  a,0                             ;+11 +12
    call    PUT_P1                      ;+13 +14 +15
    pop af                              ;+16
    ret                                 ;+17

; This code is for UNAPI rom's
; Will be overwritten if UNAPI ram page 3 or UNAPI Memory Mapper
; Anyway, calling CALL_U will execute UNAPI properlt
; And if there was switching involved to get UNAPI allocated in
; memory space, it will be switched back once done
;
; CALL_U+2  -> UNAPI Impl. Slot
; CALL_U+5 -> UNAPI Impl. Entry Function Address
CALL_U:         ; +5, +17, +24

    ld  iyh,0                           ;+0 +1 +2
    ld  ix,0                            ;+3 +4 +5 +6
    jp  CALSLT                          ;+7 +8 +9 Execute function and return to the caller
    ds  8                               ; Space to allow CALL_um copy if necessary

;--- Extract parameters from buffer
;   HL - buffer
;   IY - N# Word
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
    ld  a,(iy)                          ; index on name parametr
    or  a                               ; if = 0 to finish
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


; Templates and Variable Set 1 (< #4000) (for TCP/IP routines)


;--- TCP parameters block for the connection, it is filled in with the command line parameters
TCP_PARAMS:
IP_REMOTE:
    db  0,0,0,0
PORT_REMOTE:
    dw  0
PORT_LOCAL:
    dw  #FFFF   ;Random port if none is specified
USER_TOUT:
    dw  0
PASSIVE_OPEN:
    db  0

;--- Variables
CON_NUM:
    db  #FF ;Connection handle
DOS2:
    db  0   ;0 for DOS 1, #FF for DOS 2

;--- Text strings
HOST_PORT_SEPARATOR:
    db  ":$"

USEDOS2_S:
    db  "* DOS2 DETECTED",13,10,"$"

CORRUPTFILE_S:
    db  "MSXIRC.COM is corrupt, copy it again!",13,10,"$"

MSX1_S:
    db  "MSXIRC requires a MSX2 or better, can't execute it on MSX1!",13,10,"$"

PRESENT_S:
    db  "IRC client for MSX. TCP/IP Engine base on:",13,10
    db  "TCP Console for the TCP/IP UNAPI 1.0 By Konamiman, 4/2010",13,10
    db  "User interface from Pasha Zakharov 2:5001/3 HiHi :)",13,10
    db  "v1.1 by Oduvaldo Pavan ducasp@gmail.com",13,10,10,"$"

INFO_S:
    db  "Usage: MSXIRC [inifile.ini]",13,10,10,"$"
NOINIF_S:
    db  "*** Error loading INI File",13,10,"$"
INVPAR_S:
    db  "*** Invalid parameter(s)",13,10,"$"
ERROR_S:
    db  "*** ERROR: $"
CHNOT_S:
    db  "*** Channel not open",13,10,"$"
OPENING_S:
    db  "Opening connection (press ESC to cancel)... $"
RESOLVING_S:
    db  " Resolving host name... $"
OPENED_S:
    db  "OK!",13,10,10
    db  "*** Press F1 for help",13,10,10,"$"
USERCLOS_S:
    db  13,10,"*** Connection closed by user",13,10,"$"
USERAB_S:
    db  13,10,"*** Connection aborted by user",13,10,"$"

    ;* Host name resolution
RESOLVERR_S:
    db  13,10,"ERROR "
RESOLVERRC_S:
    ds  6                               ; Leave space for "<code>: $"
RESOLVOK_S:
    db  "OK: "
RESOLVIP_S:
    ds  16                              ; Space for "xxx.xxx.xxx.xxx$"
TWO_NL_S:
    db  13,10
ONE_NL_S:
    db  13,10,"$"

    ;* DNS_Q errors
DNSQERRS_T:
    db  ERR_NO_NETWORK,"No network connection$"
    db  ERR_NO_DNS,"No DNS servers available$"
    db  ERR_NOT_IMP,"This TCP/IP UNAPI implementation does not support name resolution.",13,10
    db  "An IP address must be specified instead.$"
    db  0

    ;* DNS_S errors
DNSRERRS_T:
    db  1,"Query format error$"
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
TCPOPERRS_T:
    db  ERR_NO_FREE_CONN,"Too many TCP connections opened$"
    db  ERR_NO_NETWORK,"No network connection found$"
    db  ERR_CONN_EXISTS,"Connection already exists, try another local port number$"
    db  ERR_INV_PARAM,"Unespecified remote socket is not allowed on active connections$"
    db  0

    ;* TCP close reasons
TCPCLOSED_T:
    db  128+0,"*** Connection closed$"
    db  128+1,"*** Connection never used$"
PEERCLOSE_S:
    db  128+2,"*** Connection closed by peer$"  ; Actually local CLOSE, but we close only when the peer closes
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
NOTCPIP_S:
    db  "*** No TCP/IP UNAPI implementation found.",13,10,"$"
NOTCPA_S:
    db  "*** This TCP/IP UNAPI implementation does not support",13,10
    db  "    opening active TCP connections.",13,10,"$"
NOTCPPS_S:
    db  "*** This TCP/IP UNAPI implementation does not support",13,10
    db  "    opening passive TCP connections with remote socket specified.",13,10,"$"
NOTCPPU_S:
    db  "*** This TCP/IP UNAPI implementation does not support",13,10
    db  "    opening passive TCP connections with remote socket unespecified.",13,10,"$"
YANCH_S:
    db  "* You are not on a channel",13,10,"$"

;--- UNAPI related
TCPIP_S:    db  "TCP/IP",0,0,0,0,0,0,0,0,0,0


;--- Segment switching routines for page 1,2
;    these are overwritten with calls to
;    mapper support routines on DOS 2
;
;    On MSX-DOS1 it will work only if mapper support reading its registers
;
ALL_SEG:
    jp  D1ALLS
FRE_SEG:
    jp  D1FRES
; --- Not implemented for DOS 1 as we don't use it, placeholder if copying DOS2 mapper routines jump table :)
RD_SEG:
    ret
    ds  2
; --- Not implemented for DOS 1 as we don't use it, placeholder if copying DOS2 mapper routines jump table :)
WR_SEG:
    ret
    ds  2
; --- Not implemented for DOS 1 as we don't use it, placeholder if copying DOS2 mapper routines jump table :)
CALL_SEG:
    ret
    ds  2
; --- Not implemented for DOS 1 as we don't use it, placeholder if copying DOS2 mapper routines jump table :)
CALLS:
    ret
    ds  2
; --- Not implemented for DOS 1 as we don't use it, placeholder if copying DOS2 mapper routines jump table :)
PUT_PH:
    ret
    ds  2
; --- Not implemented for DOS 1 as we don't use it, placeholder if copying DOS2 mapper routines jump table :)
GET_PH:
    ret
    ds  2
PUT_P0:
    out (#FC),a                         ; Try to write to mapper register for P0 selection
    ret
GET_P0:
    in  a,(#FC)                         ; Try to read mapper register for P0 selection
    ret
PUT_P1:
    out (#FD),a                         ; Try to write to mapper register for P0 selection
    ret
GET_P1:
    in  a,(#FD)                         ; Try to read mapper register for P0 selection
    ret
PUT_P2:
    out (#FE),a                         ; Try to write to mapper register for P0 selection
    ret
GET_P2:
    in  a,(#FE)                         ; Try to read mapper register for P0 selection
    ret
PUT_P3:
    out (#FF),a                         ; Try to write to mapper register for P0 selection
    ret
GET_P3:
    in  a,(#FF)                         ; Try to read mapper register for P0 selection
    ret

;    D1ALLS
;
;    On MSX-DOS1 it will allocate a maper segment for our use
;
D1ALLS:
    ld  hl,EMAPTAB                      ; Mapper table in HL
    xor a                               ; zero A and clear flags, so always user segment
    ld  e,a                             ; E hold the index to the free segment found
    ld  d,32                            ; D will count the EMAPTAB entries, we will support up to 32
    dec a                               ; It will be FF if user segment and CF, otherwise will be 0 and no carry, as we use only user segments, it is FF
D2als2:
    cp  (hl)
    jr  nz,D2als1                       ; If given maptab entry do not match 0xFF, no need to seek further as there is a free spot in it
    inc hl                              ; Adjust maptab pointer
    inc e                               ; Increase index
    dec d                               ; Decrement EMAPTAB entries left
    jr  nz,D2als2                       ; If still more EMAPT tab entries, keep seeking
    scf                                 ; If here, nothing free, set carry to indicate that
    ret
    ; Found!
D2als1:
    xor a                               ; A and Carry now 0
    rl  e                               ; Bit 7 to carry, 0 to bit 0
    rl  e                               ; Bit 6 to carry, Bit 7 to bit 0, 0 to bit 1
    rl  e                               ; Bit 5 to carry, Bit 6 to bit 0, Bit 7 to bit 1, 0 to bit 2
    ld  d,a                             ; 0 in D
    ld  b,1                             ; 1 in B, start searching right to left
D2als4:
    ld  a,b                             ; bit to look in A
    and (hl)                            ; Ok, check if bit is set in HL
    jr  z,D2als3                        ; It is not, found the right bit/segment
    ; It is set
    xor a                               ; 0 in A and carry
    rl  b                               ; Next bit to find
    inc d                               ; increment D, bit count
    jr  D2als4                          ; and repeat until find a bit not set, the free segment
D2als3:
    ld  a,b                             ; B has the bit mask of the free segment
    or  (hl)                            ; No longer free 
    ld  (hl),a                          ; Save it
    ld  a,d
    add a,e                             ; So D + E = segment number
    ld  b,0                             ; our DOS1 routine uses only primary mapper, so return 0
    ret

;    D1FRES
;
;    On MSX-DOS1 it will free a maper segment
;
D1FRES:
    ld  e,a                             ; Save segment number to free in E
    and %00000111                       ; Remainder of division per 8, basically the bit number in the MAP tap
    ld  b,a                             ; Save in B
    xor a                               ; A and Carry 0
    ld  d,a                             ; D = 0
    ld  a,e                             ; Segment number in A
    rra 
    rra 
    rra
    and %00011111                       ; Divide by 8, so this is the MAPTAB index
    ld  e,a                             ; Save MAPTAB index in E, D is o
    ld  hl,EMAPTAB
    add hl,de                           ; HL now has the MAPTAB for byte for this segment
    ld  a,#FF
    inc b
D1frs1:
    rla
    djnz    D1frs1                      ; A will have the bit masked (0)
    and (hl)
    ld  (hl),a                          ; Mask the MAP tab freeing the segment and we are done
    ret

INIMAPDOS1:
    ; Get Free mapper segment between 1st 4seg and last segment #FF (<- use TCP/IP UNAPI)
    in  a,(#FC)                         ; Try to read segment in page 0, if there is a mapper, it should be 3
                                        ; https://www.msx.org/wiki/Memory_Mapper
                                        ; The MSX2 BIOS initializes memory mappers by setting up the following configuration:
                                        ;   Segment 3 is set on page 0 (0000-3FFFh).
                                        ;   Segment 2 is set on page 1 (4000-7FFFh).
                                        ;   Segment 1 is set on page 2 (8000-BFFFh).
                                        ;   Segment 0 is set on page 3 (C000-FFFFh).
                                        ; For software unaware of memory mappers, the default configuration above appears like a regular 64 KiB block of RAM.
    cp  #FF                             ; If FF, no mapper or it is not initialized, can't use it anyway
    jp  nz,Imds1                        ; If not FF, we are cool then
    ; No mapper
    xor a
    ld  (totmaps),a
    ld  (freemaps),a                    ; No mapper segments at all
    ret
Imds1:
    inc a                               ; Increase it (so hopefully it is 4)
    push    af                          ; Save
    call    D1FRES                      ; Release it
    pop af                              ; Restore
    cp  #FF
    jr  nz,Imds1                        ; Do this until FF segment
    in  a,(#FF)
    ld  b,a
    xor a
    sub b
    ld  (totmaps),a
    sub 4                               ; Decrease the 64KB assigned to main ram
    ld  (freemaps),a
    ret


;  DET_MSG
;  input  hl - "word ....." 
;  output a - N find template word, CF- not found 
DET_MSG:
    ld  de,D_MSG                        ; Table of messages handled
DET:
    ld  b,0
DEMS0:
    ld  c,0
    push    hl                          ; Save the address to the word to detect
DEMS1:
    ld  a,(de)
    cp  (hl)                            ; First check if the first byte of current word in the table match with our first byte
    jr  z,DEMS2                         ; If it did, go on
    ld  c,1                             ; If it did not increase misses counter
DEMS2:
    cp  " "
    jr  z,DEMS3                         ; If space, done here with this word
    or  a
    jr  z,DEMS5                         ; If zero, table end, not found
    inc hl
    inc de                              ; increment pointers and keep looping until current word in the table is done
    jr  DEMS1
DEMS3:
    pop hl                              ; Restore the address to the word to detect
    inc b                               ; Item count increase
    ld  a,c
    or  a                               ; Check misses
    ld  a,b                             ; Item count in B
    ret z                               ; If no misses, done, found and carry is clear due to OR
    inc de                              ; Otherwise, next word in the table and loop
    jr  DEMS0
DEMS5:
    pop hl                              ; Restore HL and stack balance
    scf                                 ; Set carry, not found
    ret

; --- Stores jiffy value on the latest TCP/IP operation
tcptim:
    dw  0
notcpip:
    db  0
EMAPTAB:
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
    db  #FF,#FF,#FF,#FF, #FF,#FF,#FF,#FF
totmaps:
    db  0
freemaps:
    db  0
; This holds the original P2 segment when program is first loaded
P2_sys:
    db  0
; Server Control Segment
S_C:
    db  0
S_S:
    db  0
T_S_C:
    db  0
; Segment/Window currently selected on the main screen that list all windows
segsel:
    db  0
; The previous selected segment for main window, or currently displayed segment / Window
segp:
    db  0
tsegt:
    db  0

; MAPTAB    status0,page0,status1,page1.... status79,page79
; status 0-free "S"-server page, "C"-channell page, "H"-help page, "P"-private page
; 8th bit set means no new content on that windows, otherwise, new content on it
; This table holds segments for each page/window opened, up to 80 pages/windows
MAPTAB:
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
    db  0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0
SSIAT:
    ds  80
    ds  10

year:
    dw  0
day:
    db  0
month:
    db  0
minute:
    db  0
hour:
    db  0
second:
    db  0
timtim:
    dw  0

;--- Connected to IRC Server
serv1c:
    db  0
;--- Segment information for IRC Server Connection Window
serv1s:
    ds  2

D_MSG:
    db  "NICK "                         ; Nickname
    db  "PRIVMSG "
    db  "NOTICE "
    db  "JOIN "
    db  "PART "
    db  "MODE "
    db  "KICK "
    db  "QUIT "
    db  "353 "                          ; nicklist
    db  "366 "                          ; end nicklist
    db  "324 "                          ; mode replay
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


;Table timestamp template
TABTS:
    db  71,1                            ; 0 none
    db  72,5                            ; 1 HH:MM
    db  72,8                            ; 2 HH:MM:SS
    db  66,11                           ; 3 MM-DD HH:MM
    db  66,14                           ; 4 MM-DD HH:MM:SS
    db  63,14                           ; 5 YY-MM-DD HH:MM
    db  63,17                           ; 6 YY-MM-DD HH:MM:SS
    db  61,16                           ; 7 YYYY-MM-DD HH:MM
    db  61,19                           ; 8 YYYY-MM-DD HH:MM:SS

PA_ST:
    db  0                               ; bit mask status parametr's
                                        ; 0 - server            1 - port
                                        ; 2 - server password   3 - nick
                                        ; 4 - user str          5 - alt nick
                                        ; 6 - custom font

ME_STATUS:
    db  0
AA_PART:
    db  "PART ",0
PA_ME:
    db  1,"ACTION ",0
AA_PRIVMSG:
    db  "PRIVMSG ",0
C_CHAN:
    db  0
    ds  50
PA_DP:
    db  ":"
AA_CRLF:
    db  #0D,#0A,0
AA_SERVER:
    db  "SERVER "
PA_SERVER:
    ds  256
AA_PORT:
    db  "PORT "
PA_PORT:
    db  "6667",0
AA_SPAS:
    db  "PASS "
AA_SRVPASS:
    db  "SERVER PASSWORD "
PA_SRVPASS:
    db  0
    ds  16
AA_NICK:
    db  "NICK "
PA_NICK:
    db  0
    ds  32
AA_ANICK:
    db  "ALTNICK "
PA_ANICK:
    db  0
    ds  32
AA_USER:
    db  "USER "
PA_USER:
    db  "user host server :Real Name",0
    ds  256-25
AA_JOIN:
    db  "JOIN ",0
PA_CHANNEL:
    db  "#channel password",0
    ds  52
PA_FONT:
    db  0,0,0,0, 0,0,0,0, 0,0,0, 0, "$"
PA_IC:
    db  "1",0
    ds  3
PA_PC:
    db  "15",0
    ds  2
PA_AIC:
    db  "1",0
    ds  3
PA_APC:
    db  "13",0
    ds  2
PA_TIMEST:
    db  "0",0
    ds  3
;--- Query Nickname
PA_QNICK:
    db  0
    ds  30
AA_PING:
    db  "PING ",0
AA_PONG:
    db  "PONG ",0

;--- Buffer for the remote host name

HOST_NAME:
    ds 256

;--- Generic temporary buffer for data send/receive
;    and for parameter parsing
NB_BU:              equ #C100
B_BU:
    dw  NB_BU
E_BU:
    dw  NB_BU
POINT:
    ds  2
LBUFF:
    ds  2
ADDRES:
    db  0
    ds  256
BUFFER:
    ds  512
BUFFER1:
    ds  512

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
    push    ix
    push    de
    push    hl
    ld  ix,WorkNTOA
    push    af
    push    af
    and %00000111
    ld  (ix+0),a                        ; Type
    pop af
    and %00011000
    rrca
    rrca
    rrca
    ld  (ix+1),a                        ; Finishing
    pop af
    and %11100000
    rlca
    rlca
    rlca
    ld  (ix+6),a                        ; Flags: Z(zero), P(+ sign), R(range)
    ld  (ix+2),b                        ; Number of final characters
    ld  (ix+3),c                        ; Padding character
    xor a
    ld  (ix+4),a                        ; Total length
    ld  (ix+5),a                        ; Number length
    ld  a,10
    ld  (ix+7),a                        ; Divisor = 10
    ld  (ix+13),l                       ; User buffer
    ld  (ix+14),h
    ld  hl,BufNTOA
    ld  (ix+10),l                       ; Internal buffer
    ld  (ix+11),h

ChkTipo:
    ld  a,(ix+0)                        ; Set divisor to 2 or 16,
    or  a                               ; or leave it to 10
    jr  z,ChkBoH
    cp  5
    jp  nc,EsBin
EsHexa:
    ld  a,16
    jr  GTipo
EsBin:
    ld  a,2
    ld  d,0
    res 0,(ix+6)                        ; If binary, range is 0-255
GTipo:
    ld  (ix+7),a

ChkBoH:
    ld  a,(ix+0)                        ; Checks if a final "H" or "B"
    cp  7                               ; is desired
    jp  z,PonB
    cp  4
    jr  nz,ChkTip2
PonH:
    ld  a,"H"
    jr  PonHoB
PonB:
    ld  a,"B"
PonHoB:
    ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+5)

ChkTip2:
    ld  a,d                             ; If the number is 0, never add sign
    or  e
    jr  z,NoSgn
    bit 0,(ix+6)                        ; Checks range
    jr  z,SgnPos
ChkSgn:
    bit 7,d
    jr  z,SgnPos
SgnNeg:
    push    hl                          ; Negates number
    ld  hl,0                            ; Sign=0:no sign; 1:+; 2:-
    xor a
    sbc hl,de
    ex  de,hl
    pop hl
    ld  a,2
    jr  FinSgn
SgnPos:
    bit 1,(ix+6)
    jr  z,NoSgn
    ld  a,1
    jr  FinSgn
NoSgn:
    xor a
FinSgn:
    ld  (ix+12),a

ChkDoH:
    ld  b,4
    xor a
    cp  (ix+0)
    jp  z,EsDec
    ld  a,4
    cp  (ix+0)
    jp  nc,EsHexa2
EsBin2:
    ld  b,8
    jr  EsHexa2
EsDec:
    ld  b,5

EsHexa2:
    push    de
Divide:
    push    bc
    push    hl                          ; DE/(IX+7)=DE, remaining A
    ld  a,d
    ld  c,e
    ld  d,0
    ld  e,(ix+7)
    ld  hl,0
    ld  b,16
BucDiv:
    rl  c
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

ChkRest9:
    cp  10                              ; Converts the remaining
    jp  nc,EsMay9                       ; to a character
EsMen9:
    add a,"0"
    jr  PonEnBuf
EsMay9:
    sub 10
    add a,"A"

PonEnBuf:
    ld  (hl),a                          ; Puts character in the buffer
    inc hl
    inc (ix+4)
    inc (ix+5)
    djnz    Divide
    pop de

ChkECros:
    bit 2,(ix+6)                        ; Checks if zeros must be removed
    jr  nz,ChkAmp
    dec hl
    ld  b,(ix+5)
    dec b                               ; B=num. of digits to check
Chk1Cro:
    ld  a,(hl)
    cp  "0"
    jr  nz,FinECeros
    dec hl
    dec (ix+4)
    dec (ix+5)
    djnz    Chk1Cro
FinECeros:
    inc hl

ChkAmp:
    ld  a,(ix+0)                        ; Puts "#", "&H" or "&B" if necessary
    cp  2
    jr  z,PonAmpH
    cp  3
    jr  z,PonAlm
    cp  6
    jr  nz,PonSgn
PonAmpB:
    ld  a,"B"
    jr  PonAmpHB
PonAlm:
    ld  a,"#"
    ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+5)
    jr  PonSgn
PonAmpH:
    ld  a,"H"
PonAmpHB:
    ld  (hl),a
    inc hl
    ld  a,"&"
    ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+4)
    inc (ix+5)
    inc (ix+5)

PonSgn:
    ld  a,(ix+12)                       ; Puts sign
    or  a
    jr  z,ChkLon
SgnTipo:
    cp  1
    jr  nz,PonNeg
PonPos:
    ld  a,"+"
    jr  PonPoN
    jr  ChkLon
PonNeg:
    ld  a,"-"
PonPoN:
    ld  (hl),a
    inc hl
    inc (ix+4)
    inc (ix+5)

ChkLon:
    ld  a,(ix+2)                        ; Puts padding if necessary
    cp  (ix+4)
    jp  c,Invert
    jr  z,Invert
PonCars:
    sub (ix+4)
    ld  b,a
    ld  a,(ix+3)
Pon1Car:
    ld  (hl),a
    inc hl
    inc (ix+4)
    djnz    Pon1Car

Invert:
    ld  l,(ix+10)
    ld  h,(ix+11)
    xor a                               ; Inverts the string
    push    hl
    ld  (ix+8),a
    ld  a,(ix+4)
    dec a
    ld  e,a
    ld  d,0
    add hl,de
    ex  de,hl
    pop hl                              ; HL=initial buffer, DE=final buffer
    ld  a,(ix+4)
    srl a
    ld  b,a
BucInv:
    push    bc
    ld  a,(de)
    ld  b,(hl)
    ex  de,hl
    ld  (de),a
    ld  (hl),b
    ex  de,hl
    inc hl
    dec de
    pop bc
    ld  a,b                             ; *** This part was missing on the
    or  a                               ; *** original routine
    jr  z,ToBufUs                       ; ***
    djnz    BucInv
ToBufUs:
    ld  l,(ix+10)
    ld  h,(ix+11)
    ld  e,(ix+13)
    ld  d,(ix+14)
    ld  c,(ix+4)
    ld  b,0
    ldir
    ex  de,hl

ChkFin1:
    ld  a,(ix+1)                        ; Checks if "$" or 00 finishing is desired
    and %00000111
    or  a
    jr  z,Fin
    cp  1
    jr  z,PonDolar
    cp  2
    jr  z,PonChr0

PonBit7:
    dec hl
    ld  a,(hl)
    or  %10000000
    ld  (hl),a
    jr  Fin

PonChr0:
    xor a
    jr  PonDo0
PonDolar:
    ld  a,"$"
PonDo0:
    ld  (hl),a
    inc (ix+4)

Fin:
    ld  b,(ix+5)
    ld  c,(ix+4)
    pop hl
    pop     de
    pop ix
    pop af
    ret

WorkNTOA:
    ds  16
BufNTOA:
    ds  10


;--- EXTNUM16
;      Extracts a 16-bit number from a zero-finished ASCII string
;    Input:  HL = ASCII string address
;    Output: BC = Extracted number
;            Cy = 1 if error (invalid string)
EXTNUM16:
    call    EXTNUM
    ret c
    jp  c,INVPAR                        ; Error if >65535

    ld  a,e
    or  a                               ; Error if the last char is not 0
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
EXTNUM:
    push    hl
    push    ix
    ld  ix,ACA
    res 0,(ix)
    set 1,(ix)
    ld  bc,0
    ld  de,0
BUSNUM:
    ld  a,(hl)                          ; Jumps to FINEXT if no numeric character
    ld  e,a                             ; IXh = last read character
    cp  "0"
    jr  c,FINEXT
    cp  "9"+1
    jr  nc,FINEXT
    ld  a,d
    cp  5
    jr  z,FINEXT
    call    POR10

SUMA:
    push    hl                          ; BC = BC + A 
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

BIT17:
    set 0,(ix)
    ret
ACA:
    db  0                               ; b0: num>65535. b1: more than 5 digits

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

POR10:
    push    de
    push    hl                          ; BC = BC * 10 
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

; Initialize SCREEN 0 MODE 80 / 26.5
; 
INISCREEN:
    DI
lla1:
    in  a,(#99)                         ; Read Status Register (Hopefully S0 is selected)
    and #80                             ; VSYNC Interrupt?
    jr  z,lla1                          ; Loop until it is
    ld  hl,SETI
    call    LRVD                        ; Transfer initialization parameters to VDP
    ld  a,(fntsour)
    cp  1
    jr  z,lla_nsf                       ; If external font used no need to copy from rom
    ; Using BIOS Font, so need to copy it
; ROM PGT => VRAM PGT (symbol tab)
; [HL] - ROM PGT
; [DE] - VRAM PGT
; [BC] - lenght blok PGT
    ld  hl,#1BBF
    ld  DE,#1000
    ld  BC,2048
    ld  a,e                             ; LB VRAM destination
    out (#99),a
    ld  a,d                             ; HB VRAM destination
    or  #40                             ; set 6th bit, write
    out (#99),a                         ; Adress set
LDirmv:
    push    de
    push    bc                          ; Save pointer and counter
    ld  a,#00                           ; slot bios 0
    bios    RDSLT                       ; Read from bios char table
    pop bc
    pop de                              ; Restore pointer and counter
    out (#98),a                         ; Send to VRAM
    inc hl
    dec bc                              ; Adjust pointer and counter
    ld  a,b
    or  c
    jr  nz,LDirmv                       ; If counter not zero, loop
lla_nsf:
; Clear VRAM Color Table (0)
; [DE] - VRAM
; [BC] - lengt
    ld  de,#A00
    ld  bc,#270
    ld  a,e
    out (#99),a
    ld  a,d
    or  #40
    out (#99),a                         ; Will write in VRAM starting @ 0x00A00
LDirCT:
    xor a
    out (#98),a                         ; Send 0
    dec bc                              ; Adjust counter
    ld  a,b
    or  c
    jr  nz,LDirCT                       ; If counter not zero, loop
; --- "space" (" ") #20 => VRAM PNT Pattern Table
; [DE] = VRAM
; [BC] = lenght
    ld  de,0                            ; Start address of pattern table is 0
    ld  bc,1920                         ; We are using 24 rows * 80 = 1920 patterns
    ld  a,e
    out (#99),a
    ld  a,d
    or  #40
    out (#99),a                         ; Set to write VRAM starting at 0x00000
LDiPNT:
    ld  a,#20
    out (#98),a                         ; Pattern of space
    dec bc
    ld  a,b
    or  c
    jr  nz,LDiPNT                       ; If counter not zero, loop
; set BIOS width 80
    ld  a,80
    ld  (#F3B0),a                       ; LinLen variable
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
    out (#99),a                         ; First update R14 that handles the VRAM banks with A value
    ld  c,#98                           ; Out address for OTIR
    ld  a,e
    out (#99),a                         ; LSB of VRAM address
    ld  a,d
    or  #40
    out (#99),a                         ; MSB of VRAM address with 7th bit set to indicate write operation
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
    ret


;--- CFILENAME - Converts from DOS2 to DOS1 file name
; input HL = File.ini output DE = "FILE    INI" (8+3)
CFILENAME:
    ld  c,8+3                           ; Will initialize DE with '.', 11 characters
    push    hl                          ; Save HL
    ld  l,e
    ld  h,d                             ; DE -> HL
    ld  b,c                             ; Counter in B
Cfn1:
    ld  (hl)," "                        ; '.'
    inc hl
    djnz    Cfn1                        ; Do it until finished
    ld  hl,8
    add hl,de                           ; Point should be at most in the 8th position
    ld  (point),hl                      ; Save in POINT
    pop hl                              ; Restore HL
Cfn2:
    ld  a,(hl)                          ; Get from destination
    or  a
    ret z                               ; Done if terminator
    cp  "."                             ; Not done yet, is it the extension separator?
    jr  nz,Cfn3                         ; If not, it is a character
;--- It is the extension separator
    inc hl                              ; increment source
    ld  de,(point)                      ; get end of position back in DE
    ld  c,3                             ; Now just get the extension
    jr  Cfn2                            ; Back to the loop
Cfn3:
    and %11011111                       ; Clear 6th bit, forcing uppercase on characters
    ex  de,hl                           ; Swap source and destination
    ld  (hl),a                          ; Save uppercased in destination
    inc hl                              ; Increment destination
    ex  de,hl                           ; DE is Destination again
    dec c                               ; Decrement counter
    inc hl                              ; Increment source
    jr  nz,Cfn2                         ; Back to loop if not at the limit
    ret                                 ; otherwise, done

;--- LOADFONT - Loads Cutomized Font
LOADFONT:
    ld  hl,FCB+1+8+3                    ; Jump Drive and FCB file name
    ld  b,28                            ; Count of FCB bytes after that
    xor a                               ; Will set it all to 0's
LFontt:
    ld  (hl),a
    inc hl
    djnz    LFontt                      ; Loop until done
    ld  hl,PA_FONT                      ; Font File Name from .INI
    ld  de,FCB+1                        ; Will go to the second byte of FCB on
    call    CFILENAME                   ; Conver the name and put it beginning on the second byte of FCB
    ld  de,FCB
    ld  c,_FOPEN
    call    DOS                         ; Now try to open the file
    or  a
    jr  z,LFont1                        ; If success continue
    ;--- Error!
    ld  a,2
    ld  (fferr),a                       ; Indicate custom font not loaded
    jr  LFont2                          ; And done
LFont1:
    ld  de,#9000                        ; prebuffer PGT
    ld  c,_SDMA
    call    DOS                         ; Is the disk transfer address
    ld  hl,1
    ld  (FCB+14),hl                     ; Record = 1 byte
    ld  de,FCB
    ld  hl,2048                         ; size font, will read as much as 2048 bytes...
    ld  c,_RBREAD
    call    DOS                         ; Read data
    ld  (fferr),a                       ; Save return (0 ok otherwise error)
    ld  de,2048                         ; 2KB in DE
    xor a                               ; clear flags
    sbc hl,de                           ; Subtract size read from 2KB
    jr  z,LFont2                        ; If 2KB it is ok
    ; Not 2KB!
    ld  a,3
    ld  (fferr),a                       ; Invalid file, flag font error
LFont2:
    ld  de,FCB
    ld  c,_FCLOSE
    call    DOS                         ; Close file
    ld  a,(fferr)
    or  a
    ret nz                              ; If error occurred, then done
    ;--- File loaded ok, so now let's transfer it to VRAM
    ld  hl,#9000                        ; Source
    ld  bc,2048                         ; Size
    di
    xor a
    out (#99),a
    ld  a,#10+#40                       ; 0x40 -> Writing   0x10-> A12 = 1, so 000
    out (#99),a                         ; writing to VRAM @0x01000
LFont3:
    ld  a,(hl)
    out (#98),a
    inc hl
    dec bc
    ld  a,b
    or  c
    jr  nz,LFont3                       ; Loop sending all 2048 bytes
    ld  a,1
    ld  (fntsour),a                     ; Ok, font has been loaded
    ret

; Clear screeen buffer (global)
CLS_G:
;clear PNT
    ld  c," "                           ; Will fill with space
    ld  hl,#8000                        ; Starting at 0x8000
    ld  de,80*28                        ; For 80 columns / 28 lines
CLSg1:
    ld  (hl),c                          ; Write in memory
    inc hl
    dec de                              ; Adjust pointer and counter
    ld  a,e
    or  d
    jr  nz,CLSg1                        ; Repeat until counter is 0
;clear  CT
    ld  hl,#8A00                        ; Now starting at 0x8A000
    ld  de,10*28                        ; For 10 columns / 28 lines
CLSg2:
    ld  (hl),c                          ; Write in memory
    inc hl
    dec de                              ; Adjust pointer and counter
    ld  a,e
    or  d
    jr  nz,CLSg2                        ; Repeat until counter is 9
    ret

; Print text string that is NULL or $ terminated on TW (text windows)
; input
;   IX - WCB 
;   HL - start text string
PRINT_TW:
    ld  a,(hl)
    or  a
    ret z                               ; Done if 0
    cp  "$"
    ret z                               ; Done if $
    push    hl                          ; Save pointer
    call    OUTC_TW                     ; Print Char
    pop hl                              ; Restore pointer
    inc hl                              ; Adjust pointer
    jr  PRINT_TW                        ; And loop

; Get time and date and put it on screen, in the first line
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
    ld  (second),a                      ; Pretty straight forward so far
; convert to ascii
; -------------- 2013.07.01 20:38| <- right top corner of screen
    ld  iy,year
    ld  hl,#8000+80-20                  ; First position of screen buffer where we will put date and time
    ld  (hl)," "                        ; Print a space
    inc hl                              ; Next position, where year will be printed
    ld  de,(year)                       ; Number to convert
    ld  bc,#0400 + "0"                  ; B -> 4 characters to convert, C -> pad with 0 character
    xor a                               ; Decimal Format
    call    NUMTOASC                    ; Print number in screen buffer
    ld  hl,#8000+80-15                  ; After year
    ld  (hl),"."
    inc hl                              ; Print space and advacne pointer
    ld  bc,#0200 + "0"                  ; B -> 2 characters to convert, C -> pad with 0 character
    ld  d,0
    ld  e,(iy+3)                        ; DE -> Month
    call    NUMTOASC                    ; Print number in screen buffer
    inc hl
    inc hl
    ld  (hl),"."
    inc hl                              ; Jump month, add a space, adjust pointer
    ld  bc,#0200 + "0"                  ; B -> 2 characters to convert, C -> pad with 0 character
    ld  e,(iy+2)                        ; DE -> day
    call    NUMTOASC                    ; Print number in screen buffer
    inc hl
    inc hl
    ld  (hl)," "
    inc hl                              ; Jump month, add a space, adjust pointer
    ld  bc,#0200 + "0"                  ; B -> 2 characters to convert, C -> pad with 0 character
    ld  e,(iy+5)                        ; DE -> Hours
    call    NUMTOASC                    ; Print number in screen buffer
    inc hl
    inc hl
    ld  (hl),":"
    inc hl                              ; Jump hours, add a :, adjust pointer
    ld  bc,#0200 + "0"                  ; B -> 2 characters to convert, C -> pad with 0 character
    ld  e,(iy+4)                        ; DE -> Minutes
    call    NUMTOASC                    ; Print number in screen buffer
    inc hl
    inc hl
    ld  (hl),":"
    inc hl                              ; Jump minutes, add a :, adjust pointer
    ld  bc,#0200 + "0"                  ; B -> 2 characters to convert, C -> pad with 0 character
    ld  e,(iy+6)                        ; DE -> Seconds
    call    NUMTOASC                    ; Print number in screen buffer
; load to VRAM
    ld  hl,#8000+80-20                  ; The Time/Date region of screen buffer
    ld  b,80                            ; Will send 80 character
    ld  c,#98                           ; Port to send data to VRAM
    di
    ld  a,80-20
    out (#99),a                         ; VRAM LSB
    ld  a,#40
    out (#99),a                         ; VRAM MSB and 6th bit set to indicate memory write
    otir                                ; move all data
    ei
    ret

; Load Color Table buffer to VDP RAM;
LOAD_SA:
    ld  b,240                           ; 240 * 8 = 1920 bits that is for 24 lines of 80 characters/patterns
    ld  hl,#8A0A                        ; This is the buffered color table
    di
    ld  a,#0A
    out (#99),a
    ld  a,#0A+#40
    out (#99),a                         ; Start VDP Write to VRAM @ 0x00A0A
    ld  c,#98
    otir                                ; And transfer it all
    ; Original author did not re-enable interrupts here
    ret

; Load PNT buffer to VDP RAM
;
LOAD_S:
; 80*27 = 2080  #0826
    di
    ld  hl,fulls                        ; The address of screen buffer
    ld  de,0
    xor a
    ld  b,0
    out (#99),a                         ; Write 0
    ld  a,#80 + 14
    out (#99),a                         ; R#14, base address, 0x00 (A16-A14 -> 0)
    ld  c,#98                           ; port for OTIR
    ld  a,e
    out (#99),a                         ; write 0
    ld  a,d
    or  #40                             ; write 0 and set 6th bit, meaning write to 0x00000
    out (#99),a                         ; And set the operation
lds1:
    in  a,(#99)                         ; Hopefully we are reading S#0...
    and #80
    jr  z,lds1                          ; Wait VSYNC interrupt, so screen won't tear because we are updating
    otir    ; out[BC] <- [HL], inc hl, dec b until b=0
;256  #100
lds2:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
;512  #200
lds3:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
lds4:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
;1024 #400
lds5:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
lds6:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
lds7:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
lds8:
    in  a,(#99)                         ; Read S#0 for... no reason?
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
;2048 #800
lds9:
    in  a,(#99)                         ; Read S#0 for... no reason?
;#800
    ld  b,#70
    otir                                ; out[BC] <- [HL], inc hl, dec b until b=0
    ei
    ret

; Send a buffer pointed by HL to VDP port #1
; Number of bytes to transfer is the first byte in the buffer
; And the remaining is just sent to VDP port #1
LRVD:
    ld  b,(hl)                          ; Get the # of bytes to transfer
    inc hl                              ; Next
lrvd1:
    ld  a,(hl)                          ; Get data
    inc hl                              ; Increment pointer
    out (#99),a                         ; Send to VRAM
    djnz    lrvd1                       ; Decrement counter, if not zero, loop
    ret


;
; Out character to current cursor position in window
;   ix - WCB
;
;
OUTC_TW:
; special character
    cp  #0D
    jp  z,otc0D
    cp  #0A
    jp  z,otc0A
    cp  #08
    jp  z,otc08
    cp  #09
    jp  z,otc09
; regular character
;
; test corret position cursor
    ex  af,af'
    ld  d,(ix+WIN_H_SIZE)               ; h size
    ld  a,(ix+WIN_H_POS)                ; h pos
    cp  d
    jp  m,otcw_5                        ; if x position <= max x check y position
    ; Exceeded column count
    ld  a,(ix+WIN_AUTO_LF)
    or  a
    ret z                               ; no auto line feed, so won't print anything else
; next string
    xor a 
    ld  (ix+WIN_H_POS),a                ; back to column 0
    inc (ix+WIN_V_POS)                  ; ++y, next line
otcw_5:
; test correct vertica position
    ld  a,(ix+WIN_V_POS)                ; v pos
    ld  c,(ix+WIN_V_SIZE)               ; v max
    cp  c
    jp  p,otcw_4                        ; y posit > max y
    jp  otcw_1                          ; y position is ok
otcw_4:
    ; y posit > max y
    ld  a,(ix+WIN_AUTO_SCROLL)
    or  a
    jr  nz,otcw_0                       ; If auto-scroll, do scroll
    ret                                 ; no auto-scroll, do not print past last line
otcw_0:
    ; If here, scroll-up window
    call    SCRLU_TW
; output symbol
otcw_1:
    ld  hl,TMUV                         ; tabl multiples of 80
    ld  b,0
    ld  c,(ix+WIN_V_POS)                ; y position
    rlc c                               ; *2
    add hl,bc                           ; HL will point to Y * 80
    ld  e,(hl)
    inc hl
    ld  d,(hl)                          ; de = y * 80
    ld  l,(ix+WINDOW_VR_ADD_LSB)        ; VRAM Start Address LSB
    ld  h,(ix+WINDOW_VR_ADD_MSB)        ; VRAM Start Address MSB
    add hl,de                           ; Add the line count * 80, so RAM address at start of line
    ld  c,(ix+WIN_H_POS)                ; x position
    add hl,bc                           ; And now HL has the address of current character
    set 7,h
    ex  af,af'                          ; Restore character
    ld  (hl),a                          ; Save it in memory...
    ld  b,a                             ; And put it in B
;--- increment posit cursor
    inc (ix+WIN_H_POS)                  ; New x position
    ld  a,(ix+WIN_WRITE_TO_VRAM)        ; Write to VRAM as well or just buffering?
    or  a
    ret z                               ; If not active, won't update VRAM
    di
    ld  a,(IX)
    out (#99),a                         ; First WCB byte tells if it is from main or expansion VRAM
    ld  a,#80 + 45
    out (#99),a                         ; So it goes to R#45
    ld  a,(IX+1)
    out (#99),a                         ; Second WCB byte is the high address (A16 to A14) count
    ld  a,#80 + 14
    out (#99),a                         ; So it goes to R#14
    ld  a,l
    out (#99),a                         ; LSB of VRAM address is the same as RAM buffer address
    ld  a,h
    and #7F
    or  #40                             ; MSB of VRAM address is the same as RAM buffer address except bit 7, and set bit 6 as it is write operatioin
    out (#99),a                         ; So now we can write at it
    ld  a,b
    out (#98),a                         ; It was saved in B, send the pattern to VRAM
    ld  (hl),a                          ; Not sure why do this again...??? It was already written to the buffer
    ei
    ret


; scroll up text windows
; clear end string
; ix - WCB
SCRLU_TW:
    ld  h,(ix+WINDOW_VR_ADD_MSB)
    ld  l,(ix+WINDOW_VR_ADD_LSB)        ; VRAM Address Start
    ld  b,0
    ld  c,80                            ; 80 characters per line
    ld  a,(ix+WIN_V_SIZE)               ; Vertical Size (Max Lines) in A
scrlu1:
    cp  2
    jp  m,srldu_1                       ; end scroll if < 2
    ld  d,h
    ld  e,l                             ; Address in DE
    ld  c,80
    add hl,bc                           ; Address + a line
    ld  c,(ix+WIN_H_SIZE)               ; Horizontal Size (Max Columns) in C
    push    hl                          ; Save HL
    set 7,h
    set 7,d                             ; Seting 7th bit adjust address to point to our screen buffer in memory
    ldir                                ; What are we doing? Copying the columns from the second line to the first line
    pop hl                              ; Restore HL so it has the address again
    dec a                               ; Decrement line counter
    jr  scrlu1                          ; And do again (so it will move all lines from line 2 to Max Lines to line 1 to (Max Lines - 1)
srldu_1:                                ; clear last line
    ld  b,(ix+WIN_H_SIZE)               ; Horizontal size
    ld  a," "                           ; space
    set 7,h                             ; Adjust address in from VRAM to RAM Bufffer
srldu_2:
    ld  (hl),a
    inc hl
    djnz    srldu_2                     ; And clear last line
    ; Done in RAM
    ld  a,(ix+WIN_WRITE_TO_VRAM)
    or  a
    call    nz,LOAD_S                   ; If needed to update on screen (VRAM), reload screen
    dec (ix+WIN_V_POS)                  ; Adjust cursor vertical position
    ret

;--- Carriage Return
otc0D:
    ld  a,(ix+WIN_CR_CLR_CURS_ON)
    or  a
    jr  nz,otc0D1                       ; If there is no need to clear what is in front of cursor, skip to simply adjust cursor
otc0D0:
    ; If here, going to clear what is front of cursor before moving position
    ld  a,(ix+WIN_H_POS)                ; X position in A
    ld  c,(ix+WIN_H_SIZE)               ; Max Columns in C
    cp  c
    jp  p,otc0D1                        ; If X < Max just reset cursor X position
    ld  a," "
    ex  af,af'
    call    otcw_1                      ; Print a space in current position
    jr  otc0D0
otc0D1:
    xor a
    ld  (ix+WIN_H_POS),a                ; x = 0
    ret

;--- Line Feed
otc0A:
    ld  a,(ix+WIN_V_POS)                ; y_cur
    ld  b,(ix+WIN_V_SIZE)               ; y_size
    inc (ix+WIN_V_POS)                  ; y = y+1
    cp  b
    ret c                               ; If less than limit, done
    ; reached the limt
    ld  a,(ix+WIN_AUTO_SCROLL)
    or  a
    jr  nz,SCRLU_TW                     ; If window is auto scroll, scroll
    dec (ix+WIN_V_POS)                  ; Otherwise simple ignore and do not increase line
    ret

;--- TAB
otc09:
    ld  a," "
    ex  af,af'
    call    otcw_1                      ; Print a space
    ld  a,(ix+WIN_H_POS)
    and 7                               ; Check if X position is a multiple of 8 (bits 0, 1 and 2 not set)
    jr  nz,otc09                        ; If not, repeat until it is
    ret

;--- Back Space
otc08:
    ld  a,(ix+WIN_H_POS)                ; Current X
    dec a                               ; x = x-1
    jp  m,otc08_1                       ; < 0, might have more things to do if auto line feed window
    ld  (ix+WIN_H_POS),a                ; Ok, it was valid, so adjust x and done
    ret
otc08_1:
    ld  a,(ix+WIN_AUTO_LF)
    or  a
    ret z                               ; If no Auto-LF done
    ld  a,(ix+WIN_H_SIZE)               ; Horizontal size
    dec a
    ld  (ix+WIN_H_POS),a                ; max h position, wrapped around
    ld  a,(ix+WIN_V_POS)                ; Vertical position
    dec a                               ; y = y-1
    jp  m,otc08_2                       ; < 0, might have more things to do if auto scrolling window
    ld  (ix+WIN_V_POS),a                ; update Y position
    ret
otc08_2:
    ld  a,(ix+WIN_AUTO_SCROLL)          ; Auto scroll?
    or  a
    ret z                               ; If yes, do not return, and scroll down the text
    ;OPJ --> Doesn't seem to work, if need to scroll up, with execute CURSOR?
    ;        Seems that Window Auto Scrolling on backspace at 0x0 will not work, not that it is used anyway, we just backspace in a single line...
;   Scroll down text windows
;   clear 1st string
;   ix - WCB
SCRLD_TW:
    ld  a,(ix+WIN_V_SIZE)               ; v max
    cp  2
    jp  m,srldw_1                       ; v max < 2 - end scroll
    dec a
    ld  bc,80
    ld  h,(ix+WINDOW_VR_ADD_MSB)
    ld  l,(ix+WINDOW_VR_ADD_LSB)        ; HL (V)RAM Address
srldw1:
    dec a
    jr  z,srldw0                        ; If all lines, ok
    add hl,bc                           ; Otherwise keep adding 80
    jr  srldw1                          ; And loop
srldw0:
    ; hl - last-1 string
    ld  a,(ix+WIN_V_SIZE)
    dec a                               ; A = Last Line
    ld  d,h
    ld  e,l                             ; Save address in DE
    add hl,bc                           ; One more line to HL
    ex  de,hl                           ; So HL has Last Line, DE Last Line - 1
srldw2:
    ld  c,(ix+WIN_H_SIZE)               ; horizontal size in C
    push    hl                          ; Save HL
    set 7,h
    set 7,d                             ; Adjust it to RAM
    ldir                                ; 1 str transfer
    pop hl                              ; Restore HL
    ld  d,h
    ld  e,l
    ld  c,80
    or  a
    sbc hl,bc                           ; Adjust pointers so they are back to Line and Line - 1, but next pair
    dec a                               ; Adjust line count
    jr  nz,srldw2                       ; And repeat until done
;
srldw_1:    ; clear 1st string
    ld  h,(ix+WINDOW_VR_ADD_MSB)
    ld  l,(ix+WINDOW_VR_ADD_LSB)        ; (V)RAM address in HL
    ld  b,(ix+WIN_H_SIZE)               ; Horizontal Size in B
    ld  a," "                           ; space
    set 7,h                             ; Adjust to RAM address
srlw_2:
    ld  (hl),a
    inc hl
    djnz    srlw_2                      ; Will fill first line with spaces
; --- OPJ -> Not sure this is working... it is not updating screen, it is not returning, and is executing cursor function...?
;   jr  LOAD_S
;   ret

CURSOR:
; in hl - absolute byte of screen in VRAM
    ex  de,hl                           ; Save in DE as
    call    CURSOFF                     ; CURSOFF uses HL
    ex  de,hl                           ; Back in HL
    xor a                               ; Clear flag, so C is 0
    rr  h                               ; Adjust address so rightmost bit of H goes to C and leftmost bit of H is now 0
    rr  l                               ; Rightmost bit of H goes to L leftmost bit, rightmost bit of L in C
    rra                                 ; Carry is 0, A has the rightmost bit of L in its leftmost bit
    rr  h
    rr  l
    rra                                 ; Repeating this, two rightmost bits of L in the two leftmost bits of A
    rr  h
    rr  l
    rra                                 ; Repeating this, three rightmost bits of L in the two leftmost bits of A
    rra
    rra
    rra
    rra
    rra                                 ; and now the three rightmost bits of L in A 3 rightmost bits, why the heck not use ld a,l and and a,7?
                                        ; Because we want HL shifted :) as the color attribute map maps 8 patterns at a time in a byte,
                                        ; and shifting three times to the right divides per 8
    ld  de,#0A00                        ; offset for screen layout color bit setting regular or alternate
    add hl,de
    ld  (oldcur),hl
    ld  b,a                             ; A has the bit we want to change the value, now in B
    di
    ld  a,l
    out (#99),a
    ld  a,h
    and #7F                             ; Reset 8th bit so address is proper for VRAM
    or  #40
    out (#99),a                         ; Want to write in VRAM address in color table as we calculated and is in HL
    set 7,h                             ; Set 8th bit so it is proper for RAM
    inc b                               ; Adjust the count, so we will set the right bit attribute
    xor a
    scf                                 ; Carry start as 1
cur1:
    rra
    djnz    cur1                        ; will move the 1 bit to the correct position that is related to our layout / pattern color bit
    ld  (oldcur+2),a                    ; Save it in oldcur+2
    or  (hl)                            ; and mask with what is in the RAM buffer
    out (#98),a                         ; finally sending it to VDP/VRAM
    ret

; cursor off 
CURSOFF:
    ld  hl,(oldcur)                     ; absolute coordinate CT
    di
    ld  a,l
    out (#99),a
    ld  a,h
    and #7F                             ; Clear RAM bit
    or  #40
    out (#99),a                         ; write to VRAM cursor coordinate 
    set 7,h                             ; Set RAM bit, now getting it from RAM
    ld  a,(oldcur+2)                    ; this is the content for the cursor coordinate
    cpl                                 ; invert to fit the attribute
    and (hl)                            ; mask with the content in ram
    out (#98),a                         ; And send it
    ret

; output string from WCB in ix to the Screen
; ix+WIN_L_STR_ADD - start out
; ix+WIN_RAM_B_END - end of buffer
;
; Will print up to B_END or H_SIZE characters
OUTSTRW:
    ld  l,(ix+WIN_L_STR_ADD_LSB)
    ld  h,(ix+WIN_L_STR_ADD_MSB)        ; start from the last string printed
    ld  e,(ix+WIN_RAM_B_END_LSB)
    ld  d,(ix+WIN_RAM_B_END_MSB)        ; end buffer
    exx                                 ; preserve original registers (except AF) by using shadow registers
    ld  l,(ix+WINDOW_VR_ADD_LSB)        ;
    ld  h,(ix+WINDOW_VR_ADD_MSB)        ; VRAM Start Address in HL
    set 7,h                             ; Convert it to ram? Or different VRAM page?
    ld  b,(ix+WIN_H_SIZE)               ; H size in B'
    exx                                 ; back to regular registers
ostrw3:
    xor a                               ; Clear flags
    ld  a,(hl)                          ; Byte from string
    sbc hl,de                           ; start - end
    jr  c,ostrw1                        ; if start < end, all good, string character
    ld  a," "                           ; otherwise print " "
ostrw1:
    add hl,de                           ; restore HL
    inc hl                              ; increment pointer
    exx                                 ; preserve original registers (except AF) by using shadow registers
    ld  (hl),a                          ; Copy back to VRAM buffer in HL'
    inc hl                              ; Increment HL', VRAM pointer
    dec b                               ; Decrement B', column count
    exx                                 ; back to regular registers
    jr  nz,ostrw3                       ; AF was always selected, so, if not end of line, keep going
    ; End of line, so dump the line to VRAM
    ld  l,(ix+WINDOW_VR_ADD_LSB)
    ld  h,(ix+WINDOW_VR_ADD_MSB)
    ld  b,(ix+WIN_H_SIZE)
    di
    ld  a,l
    out (#99),a
    ld  a,h
    or  #40
    out (#99),a                         ; Set VDP to receive writes to VRAM @ VR_ADD
    set 7,h                             ; Convert the VRAM to RAM buffer address
    ld  c,#98                           ; Out port to VRAM writes
    otir                                ; And write to screen
    ; Original author did not re-enable interrupts
    ret

;   Init Text Windows
;   CLS windows
;   IX = WCB
CLS_TW:
    ld  h,(ix+WINDOW_VR_ADD_MSB)
    ld  l,(ix+WINDOW_VR_ADD_LSB)        ; VRAM address in HL
    ld  de,fulls                        ; Page 2 start
    add hl,de                           ; HL has segment / window RAM address
    ld  d,(ix+WIN_V_SIZE)               ; Number of lines for this WCB
    ld  a," "                           ; Space
CLSTW2:
    ld  b,(ix+WIN_H_SIZE)               ; Number of columns in B
    push    hl                          ; Save HL, start of RAM screen buffer line we are clearing
CLSTW1:
    ld  (hl),a                          ; Space in there
    inc hl                              ; Increment pointer
    djnz    CLSTW1                      ; and do it until all columns are filled
    pop hl                              ; restore HL
    dec d                               ; decrement number of lines
    jp  z,CLSTW3                        ; if 0, done
    ld  c,80                            ; Otherwise, jump to next line in memory
    add hl,bc
    jr  CLSTW2                          ; Loop next line
CLSTW3:
    ; Done in RAM buffer
    ld  a,(ix+WIN_WRITE_TO_VRAM)        ; Are we sending this to VRAM?
    or  a
    ret z                               ; No, done
    jp  LOAD_S                          ; Yes, reload screen and return from there

; Clear Keyboard buffer 
CLKB:
    ld  c,_CONST
    call    DOS                         ; Anything on keyboard buffer?
    or  a
    ret z                               ; No, return
    ld  c,_INNO
    call    DOS                         ; Get it
    jp  CLKB                            ; Loop until empty

; Will Get Active Segments/Windows, and list then on the screen
BOSegT:
    ld  ix,sWCB1                        ; This is the segment that list currently opened Windows/Segment
    call    CLS_TW                      ; Clear the screen buffer
    ld  a,(ix+WINDOW_COUNT)             ; Check if there are records
    or  a
    ret z                               ; no records
    ld  de,50+4+1                       ; Each Window information start on column 55 of every line
    ld  hl,#9000                        ; Start of Window information buffer
    ld  a,(ix+WIN_LIST_SHIFT)           ; Get the number of records to shift
    inc a                               ; Adjust, for loop
BOS2:
    dec a                               ; Ok, next
    jr  z,BOS1                          ; If already where we want continue
    add hl,de                           ; Otherwise jump to next line
    jr  BOS2                            ; Loop
BOS1:
    ld  a,(ix+WINDOW_COUNT)             ; Window Count
    sub (ix+WIN_LIST_SHIFT)             ; - Shift / Skipped items
    cp  (ix+WIN_V_SIZE)                 ; Compare with line limit
    jr  c,BOS4                          ; If carry, ok
    ld  a,(ix+WIN_V_SIZE)               ; Otherwise the line printed will be the last one, can't overflow
BOS4:
    inc hl                              ; Jump to the first printable character
    ex  de,hl                           ; save in DE for now
    ld  hl,#8000                        ; Start of screen buffer
    ld  bc,(sWCB1+WINDOW_VR_ADD)        ; VRAM address
    add hl,bc                           ; Adjust start
    ex  de,hl                           ; Back, so DE is the screen buffer address, HL is the segment/window printable information
BOS3:
    ld  bc,34                           ; How many characters we are going to copy
    ldir                                ; And move it to the ram buffer
    ld  bc,55-34
    add hl,bc                           ; Skip the rest of that info
    ex  de,hl                           ; place the window information buffer address in DE
    ld  bc,80-34
    add hl,bc                           ; Next screen buffer line position
    ex  de,hl                           ; So screen buffer position back in DE, and window information buffer position in HL
    dec a
    jr  nz,BOS3                         ; If not zero, more itens, so keep copying until zero :)
    ret

;--- Bufferization segment record table
;--- 0x9000 will hold active segments, this way:
;--- Record Position in MAP_TAB
;--- 54 bytes extracted from segment beginning
BFSegT:
    ld  a,(P2_sys)
    call    PUT_P2                      ; Our main App segment is paged
    ld  ix,sWCB1                        ; Window or Nick List control
    ld  de,#9000                        ; Where we store segments information
    ld  (ix+WINDOW_COUNT),0             ; Window Count starts at 0
    ld  (ix+WIN_LIST_BUILD_TMP),0       ; We will use to help our parse count
    ld  hl,MAPTAB                       ; Segment table in HL
BFS1:
    ld  a,(hl)
    or  a
    jr  nz,BFS2                         ; entry not empty, check it
    ; Empty
    inc hl                              ; jump segment
BFS3:
    inc hl                              ; Next Record
    inc (ix+WIN_LIST_BUILD_TMP)         ; parse count
    ld  a,78
    cp  (ix+WIN_LIST_BUILD_TMP)
    jr  nc,BFS1                         ; parse until 80 records were parsed
;--- Done Scanning
    ld  a,(ix+WINDOW_COUNT)             ; Total Windows
    dec a
    sub (ix+WIN_V_SIZE)                 ; maximum lines
    jr  nc,BFS4
    ; If here, carry, so fit a single page
    ld  (ix+WIN_LIST_SHIFT),0           ; no shift
    jr  BFS5
BFS4:
    ; Ok, more than the # of lines we can fit
    inc a                               ; Return to the correct value
    cp  (ix+WIN_LIST_SHIFT)
    jr  nc,BFS5                         ; Increased or same as before
    ld  (ix+WIN_LIST_SHIFT),a           ; New value if no longer point to a valid entry
BFS5:
    ld  a,(ix+WINDOW_COUNT)
    cp  (ix+WIN_LIST_ITEM_SEL)          ; item selected > number of itens ?
    ret nc                              ; nope, leave as is
    ld  (ix+WIN_LIST_ITEM_SEL),a        ; Yes, so then selection is the last item now
    ret
;--- Segment is in use
BFS2:
    inc hl
    ld  a,(hl)                          ; Get Segment
    exx                                 ; Use shadow regs
    ld  hl,BUFFER
    ld  b,(ix+WIN_LIST_BUILD_TMP)       ; parse counter in B
    ld  (hl),b                          ; Now in BUFFER
    call    PUT_P2                      ; Select segment
    inc hl                              ; BUFFER + 1
    ex  de,hl                           ; Save in DE
    ld  hl,#8000                        ; Get from the selected segment
    ld  bc,50+4                         ; 54 bytes
    ldir                                ; Copy
    ld  a,(P2_sys)
    call    PUT_P2                      ; Restore our app segment
    exx                                 ; Restore regular registers
    push    hl                          ; Save HL
    ld  hl,BUFFER                       ; Will get the data extracted
    ld  bc,50+4+1                       ; Total size for the information is 55 bytes
    ldir                                ; And save in address pointed by DE
    pop hl                              ; Restore HL
    inc (ix+WINDOW_COUNT)               ; Increment Window count
    jr  BFS3

CSIA:
    ld  hl,SSIAT+80
    ld  b,10
    xor a
CSIA.1:
    ld  (hl),a                          ; save it in the Byte that manipulates the pattern/character attributes for the selected segment/window
    djnz    CSIA.1                      ; and loop until done
    jp  L_SIA                           ; Load information in VRAM and return from there

; Set segment information attribute
SSIA:
    ld  hl,MAPTAB
    ld  de,SSIAT
    ld  b,80
SSIA1:
    ld  a,(hl)
    cp  %10000000                       ; 8th-bit = 0 -> exist new data on record
    adc a,0                             ; If A < 128, add 1 (carry) to it
    or  %10000000                       ; Set 8th bit
    and %10111111                       ; Clear 7th bit uppercasing it
    ld  (de),a                          ; and put it into SSIAT (this converts the character to the half characters for S/Q/C/H in the custom font)
    inc hl
    inc hl                              ; Next segment
    inc de                              ; Next segment information attribute
    djnz    SSIA1                       ; Loop until all table has been scanned
    ld  l,e
    ld  h,d                             ; 1 byte beyond SSIAT in HL
    ld  b,10
    xor a
SSIA2:
    ; Now need to set the bit in the 80 bits (10 bytes) map below SSIAT that handle the attributes for the SSIAT line/patterns
    ; so the bit set with 1 will highlight that pattern/character
    ld  (hl),a
    inc hl
    djnz    SSIA2                       ; now fill 10 0's after SSIAT, this is the attribut table
    ld  a,(segs)                        ; get current segment
    ld  c,a                             ; in C
    xor a
    ld  b,a                             ; 0 in A and B
    rr  c                               ; rotate C right through carry (which is 0 due to xor A), so, divide by 2 and 1st bit in carry
    rra                                 ; 8th bit of A will be set if 1st bit of C was set prior to division
    rr  c
    rra                                 ; Now C is divided by 4 and 8th bit of A is second bit of segment, and 7th bit is first bit of segment
    rr  c
    rra                                 ; Now C is divided by 8 and 8th bit of A is third bit of segment, 7th bit is second bit of segment, and 6th bit is first bit of segment
    rra
    rra
    rra
    rra
    rra                                 ; And A has the three least significant bits of segment and C is segment / 8
    ex  de,hl                           ; HL has again 1 byte beyond SSIAT, first of the 10 bytes after it
    add hl,bc                           ; And now add seg divided by 8 to it
    ld  b,a                             ; And three LSB of seg (value 0 to 7) in B
    inc b                               ; Add 1 to it (1 to 8)
    xor a
    scf                                 ; A is zero and Carry is set
SSIA3:
    rra
    djnz    SSIA3                       ; This will loop and in the end will have the inverse bit of A in relation to B (if B = 0 - 8th bit, 1 - 7th bit... 7 - 1st bit)
    ld  (hl),a                          ; save it in the Byte that manipulates the pattern/character attributes for the selected segment/window
    ret

; Load segment information to VRAM
L_SIA:
    di
    ld  hl,SSIAT                        ; The Segment information Attribute address
    ld  a,#20
    out (#99),a
    ld  a,#08+#40
    out (#99),a                         ; will write VRAM starting at 0x00820, 26th line
    ld  c,#98
    ld  b,80
    otir                                ; send the 80 bytes comprising the bottom Window Bar
    ld  a,#04
    out (#99),a
    ld  a,#0B+#40
    out (#99),a                         ; now will write at 0x00B04 the 10 bytes which are the attribute, where the bit set is the pattern using alternate color (selected)
    ld  b,10
    otir                                ; Transfer
    ei
    ret

; Clear atribute for channel and nick areas 1-25 string
CLAT_C_N:
    ld  hl,#8A00 + 10                   ; (80/8)
    ld  b,10*24                         ; 24 lines, 10 chars
    xor a
clcn1:
    ld  (hl),a                          ; Save 0
    inc hl                              ; Adjust pointer
    djnz    clcn1                       ; Loop until all are has been cleared
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
SETAT_S:
    ld  a,(ix+WIN_LIST_ITEM_SEL)        ; Selected name from UP string window to Down, if - 0 no select
    or  a
    ret z                               ; if nothing selected, done
    cp  25
    ret nc                              ; we can highlight from 0 to 24, so it should carry
    ld  b,a                             ; Item in B
    ld  hl,#8A00 + 5
    ld  de,10
stats1:
    add hl,de
    djnz    stats1                      ; decrement until reaching the correct memory are for the pattern attributes
    ld  (hl),%00000011                  ; And we have 34 bits to set to 1 to use alternate color on the 34 right-most characters
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
    ld  hl,(sWCB0+WIN_RAM_B_CUR)
    ld  (var3),hl   ; save old buff curs 
    dec hl
    dec hl      
    ld  d,(ix+WIN_V_SIZE)   ; vertical size ( nm str win ); search start string
    ld  bc,3000
ppb0:   ld  a,#0A
    cpdr    ; CP A,(HL) HL=HL-1 BC=BC-1 repeat until CP A,(HL) = 0 or BC=0
    jp  nz,ppb0
    ld  a,(ix+WIN_RAM_B_ADD_LSB)    ;buf
    sub l
    ld  a,(ix+WIN_RAM_B_ADD_MSB)
    sbc a,h 
    jr  nc,ppb3 
    dec d
    jr  nz,ppb0 ; next string..
    inc hl
    jr  ppb4
ppb3:   
    ld  hl,(sWCB0+WIN_RAM_B_ADD)    
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

; Apply the color and time-stamp configurations
APP_PA:
    ld  hl,PA_IC                        ; Ink Color
    call    EXTNUM16                    ; Convert it from ASCII and store in BC
    ld  a,c
    rl  a
    rl  a
    rl  a
    rl  a
    and #F0                             ; Move it to upper nibble 
    ld  c,a                             ; And store back in C
    ld  a,(SETIc)                       ; Get the current Ink/Paper
    and #0F                             ; Leave Paper
    or  c                               ; And use our new Ink
    ld  (SETIc),a                       ; And save it
    ld  hl,PA_PC                        ; Paper Color
    call    EXTNUM                      ; Convert it from ASCII and store in cBC
    ld  a,c
    and #0F                             ; Just the lower nibble matters
    ld  c,a                             ; Save it in C
    ld  a,(SETIc)                       ; Get Current Ink/Paper
    and #F0                             ; We just want the Ink from it
    or  c                               ; Join our paper color
    ld  (SETIc),a                       ; And save it

    ld  hl,PA_AIC                       ; Alternative Ink Color
    call    EXTNUM                      ; Convert it from ASCII and store in cBC
    ld  a,c
    rl  a
    rl  a
    rl  a
    rl  a
    and #F0                             ; Move it to upper nibble 
    ld  c,a                             ; And store back in C
    ld  a,(SETIc+2)                     ; Get the current Alt. Ink/Paper
    and #0F                             ; Leave Paper
    or  c                               ; And use our new Ink
    ld  (SETIc+2),a                     ; And save it
    ld  hl,PA_APC                       ; Alternative Paper Color
    call    EXTNUM                      ; Convert it from ASCII and store in cBC
    ld  a,c
    and #0F                             ; Just the lower nibble matters
    ld  c,a                             ; Save it in C
    ld  a,(SETIc+2)                     ; Get Current Alt. Ink/Paper
    and #F0                             ; We just want the Ink from it
    or  c                               ; Join our paper color
    ld  (SETIc+2),a                     ; And save it

    ld  hl,PA_TIMEST                    ; Get the Time Stamp Format
    call    EXTNUM                      ; Convert it from ASCII and store in cBC
    ld  a,c
    ld  (t_stmp),a                      ; And save it

    ret

; =======================================================================
; Templates and Variable Set 1 (< #8000) (for user interface)
; =======================================================================
SYSMESS1:
    db  "MSX IRC Client by Pasha Zakharov",13,10,"v1.1 by Ducasp (ducasp@gmail.com)",13,10,10,"$"
SM_fntBIOS:
    db  "Using system ROM font",13,10,"$"
SM_fntLOAD:
    db  "Custom font has been loaded",13,10,"$"
SM_fntLERR:
    db  "Custom font can't be loaded. Error - ","$"
SM_D2MAPI:
    db  "MSXDOS2 Mapper initialization - Ok",13,10,"$"
SM_D2M_TOT:
    db  "Total number of 16k RAM segments - ","$"
SM_D2M_FREE:
    db  "Number of free 16k RAM segments  - ","$"
SM_UNAPI3:
    db  "UNAPI found at page 3",13,10,"$"
SM_UNAPIM:
    db  "UNAPI found at Memory Mapper",13,10,"$"
SM_UNAPIR:
    db  "UNAPI found at ROM slot",13,10,"$"
SM_BASICHLP:
    db  10,"[S]  To go to Server Console/Connect",13,10,"[F1] To get Help",13,10,"[Q]  To exit",13,10,"$"
SM_NOREC:
    db  "Can't allocate more windows, close at least one to open another",13,10,"$"
SM_NOSEG:
    db  "No more memory, close a window and try again",13,10,"$"
SM_NOMAPPER:
    db  "Need a Memory Mapper with at least 32k free, failure!",13,10,"$"
SM_DOS1MAP:
    db  "Use of Mapper on MSXDOS(1)",13,10,"$" 
SM_LostSeg:
    db  "This segment is lost",13,10,"$" 
SM_NOSERV:
    db  "Server console already open, choose it using up/down and enter",13,10,"$"
SM_HELP:
    db  "Push F1 for help screen",13,10,"$"
SM_CONNS:
    db  "Push F2 to connect irc server, F3 - disconnect",13,10,"$"
SM_CONNEXIST:
    db  "The connection with a server is already established",13,10,"$"
SM_QNA:
    db  "/QUERY: if insufficient parameters",13,10,"$"

;--- User Parametr's

;--- Parameter Tables
WRDPA:
        dw  WRDPA1,PA_SERVER,WRDPA2,PA_PORT
        dw  WRDPA3,PA_SRVPASS,WRDPA4,PA_NICK
        dw  WRDPA5,PA_USER,WRDPA6,PA_ANICK,WRDPA7,PA_FONT
        dw  WRDPA8,PA_IC,WRDPA9,PA_PC,WRDPA10,PA_AIC
        dw  WRDPA11,PA_APC,WRDPA12,PA_TIMEST,0

; Relate parameters read from Ini File and any flags that must be set in PA_ST
WRDPA1:
    db  7,"server ",%0001
WRDPA2:
    db  5,"port ",%0010
WRDPA3:
    db  8,"srvpass ",%0100
WRDPA4:
    db  5,"nick ",%1000
WRDPA5:
    db  5,"user ",%10000
WRDPA6:
    db  8,"altnick ",%100000
WRDPA7:
    db  5,"font ",%1000000
WRDPA8:
    db  6,"ink_c ",0
WRDPA9:
    db  8,"paper_c ",0
WRDPA10:
    db  7,"aink_c ",0
WRDPA11:
    db  9,"apaper_c ",0
WRDPA12:
    db  11,"timestamp ",0

;--- VDP Initialization settings that are sent at once
SETI:
    db  SETIe - SETI -1                 ; This is the size of settings structure
    db  #04,0 + #80                     ; Register 0  -> 00000100 - M4 Mode flag set
    db  #70,1 + #80                     ; Register 1  -> 01110000 - Display Enabled, Vertical Interrupt, M1 Mode flag set
    db  #08,8 + #80                     ; Register 8  -> 00001000 - VRAM as 64Kx1bit or 64Kx4bits, if some machines do not work this is something to look after...
    db  #80,9 + #80                     ; Register 9  -> 10000000 - 212 scan lines / 26.5 text lines
    db  #03,2 + #80                     ; Register 2  -> 00000011 - Pattern Layout Table High Address A11 and A10 set to 1
    db  #02,4 + #80                     ; Register 4  -> 00000010 - Pattern Generator Table High Address A12 set to 1
    db  #00,10 + #80                    ; Register 10 -> 00000000 - Color Table High Address all 0
    db  #2F,3 + #80                     ; Register 3  -> 00101111 - Color Table Address A11 and A9 to A6 set to 1 - 0xBC0
SETIc:
    db  #1F,7 + #80                     ; Register 7  -> Text color 1 Paper color 15
    db  #1D,12 + #80                    ; Register 12 -> Blink Text color 1 Paper color 12
    db  #70,13 + #80                    ; Register 13 -> on for 1.2s and off for 0s (no blink, just use alternate color)
    db  #00,45 + #80                    ; Register 45 -> Using VRAM
    db  #00,14 + #80                    ; Register 14 -> 0 meaning page 0 (A16, A15 and A14 0) for VRAM transfers
SETIe:


;--- Auxiliary buffer pointers and size indicators
bbuf:
    ds  2
lenb:
    ds  2
bbuf1:
    ds  2
lenb1:
    ds  2
bbuf2:
    ds  2
lenb2:
    ds  2

t_stmp:
    db  0                               ; - If Timestamp is used on chat/server windows
s_ins:
    db  #FF                             ; - Insert active or not
var2:
    dw  0                               ; - used by Ls_help
var3:
    dw  0                               ; - used by PPBC
fntsour:
    db  0                               ; - tells whether a custom font (1) or system font (0) is used
fferr:
    db  0                               ; - holds the custom font loading result / error
point:
    dw  0                               ; - auxiliary variable for CFILENAME
serv1:
    db  0                               ; - server control window/terminal exists
segsRS:
    db  0                               ; - map segment parental server save

; Used for quick 80 Multiplication, just a table to access lines in buffers/vram quickly
; Contains up to 80*29, 30 entries
TMUV:
    dw  0,80,160,240,320,400,480,560,640,720
    dw  800,880,960,1040,1120,1200,1280,1360,1440,1520
    dw  1600,1680,1760,1840,1920,2000,2080,2160,2240,2320

;--- Windows control block
;--- First one in unused, just left it because it is a good explanation of a WCB
;WCB:                                   ; 24 bytes
;   db  0                               ; 0     0 - VRAM 1 - EXPANDED VRAM
;   db  0                               ; 1     00000bbb A16, A15, A14 (n - 16b page)
;   dw  80                              ; 2 3   00hhhhhhlllllllll A13-A0 VRAM
;   db  80                              ; 4     horizontal size 1-80
;   db  24                              ; 5     vertical size   1-26
;   db  0                               ; 6     cursor horizontal position
;   db  0                               ; 7     cursor vertical position
;   db  1                               ; 8     0 - stop when reach last column     1 - auto LF
;   db  1                               ; 9     0 - stop when reach last line       1 - auto scroll
;   db  0                               ; 10    0 - invisible cursor                1 - visible cursor
;   db  1                               ; 11    0 - disable VRAM load, RAM Buffer only
;   dw  #9000                           ; 12    RAM buffer address
;   dw  #C000                           ; 14    Max buffer address
;   dw  #9000                           ; 16    RAM buffer end
;   dw  #9000                           ; 18    Current RAM buffer address
;   db  0                               ; 20    0 - clear new string                1 - not clear
;   db  0                               ; 21    0 - normal                          1- out of buffer
;   dw  #9000                           ; 22    Last string address

;--- Used for help screen               ; 24 bytes
WCB0:
    db  0,0                             ; VRAM, Page 0
    dw  80                              ; Start at second line, thus, address 80
    db  80,24                           ; 80 columns and 24 lines
    db  0,0                             ; Cursor @ 0x0
    db  1,1                             ; Auto LF and Auto Scroll
    db  0                               ; Invisible Cursor
    db  0                               ; Disable VRAM load
    dw  #9000
    dw  #C000
    dw  #9000
    dw  #9000
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #9000

;--- Used for server and query screen   ; 24 bytes
WCB01:
    db  0,0                             ; VRAM, Page 0
    dw  80                              ; Start at second line, thus, address 80
    db  80,24                           ; 80 columns and 24 lines
    db  0,23                            ; Cursor @ 0x23
    db  1,1                             ; Auto LF and Auto Scroll
    db  0                               ; Invisible Cursor
    db  0                               ; Disable VRAM load
    dw  #BFFF
    dw  #C000
    dw  #C000
    dw  #C000
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #BFFF

;--- Used for channel screen            ; 24 bytes
WCB1:
    db  0,0                             ; VRAM, Page 0
    dw  80                              ; Start at second line, thus, address 80
    db  80-16,24                        ; 64 columns and 24 lines, leave room for Nick Windows
    db  0,23                            ; Cursor @ 0x23
    db  1,1                             ; Auto LF and Auto Scroll
    db  0                               ; Invisible Cursor
    db  0                               ; Disable VRAM load
    dw  #BFFF
    dw  #C000
    dw  #C000
    dw  #C000
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #BFFF

;--- Used for nick screen               ; 24 bytes
WCB2:
    db  0,0                             ; VRAM, Page 0
    dw  80+80-15                        ; Start at second line, column 65, thus, address 80 + 65
    db  15,24                           ; 15 columns and 24 lines
    db  0,0                             ; Cursor @ 0x0
    db  0,0                             ; no auto CR LF, no auto scroll
    db  0                               ; Invisible Cursor
    db  0                               ; Disable VRAM load
    dw  #8C00
    dw  #8EFF
    dw  #8C00
    dw  #8C00
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #8C00

;--- Used for input string              ; 24 bytes
WCB3:
    db  0,0                             ; VRAM, Page 0
    dw  80*25                           ; Start at last line, so after 25 lines of 80 characters
    db  80,1                            ; 80 columns and 1 line
    db  0,0                             ; Cursor @ 0x0
    db  1,1                             ; Auto LF and Auto Scroll
    db  1                               ; Show Cursor
    db  1                               ; Enable VRAM load
    dw  #8F00
    dw  #C000
    dw  #8F00
    dw  #8F00
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #8F00

;--- Used for system info window        ; 24 bytes
WCB4:
    db  0,0                             ; VRAM, Page 0
    dw  80*1                            ; Start at second line, thus, address 80
    db  80-32-3,24                      ; 80+80-32-3,24 -> 45 columns and 24 lines
    db  0,0                             ; Cursor @ 0x0
    db  1,1                             ; Auto LF and Auto Scroll
    db  1                               ; Show Cursor
    db  1                               ; Enable VRAM load
    dw  #9000
    dw  #C000
    dw  #9000
    dw  #9000
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #8F00

;--- Used for page select               ; 24 bytes
WCB5:
    db  0,0                             ; VRAM, Page 0
    dw  80+80-32-2                      ; Start at second line, 47th column thus, address 80 + 46
    db  34,24                           ; 34 columns and 24 lines
    db  0,0                             ; Cursor @ 0x0
    db  0,0                             ; No auto CR LF, no auto scroll
    db  1                               ; Show Cursor
    db  0                               ; Disable VRAM load
    dw  #8C00
    dw  #8EFF
    dw  #8C00
    dw  #8C00
    db  1,0                             ; Do not clear new string, room on buffer
    dw  #8C00

;--- File Control Blocks

;--- Initialization File FCB
FCB:    db  0
    db  "MSXIRC  INI"
    db  0,0,0,0,0,0,0,0,0,0
    db  0,0,0,0,0,0,0,0,0,0
    db  0,0,0,0,0,0,0,0

;--- Help File FCB
FCBhelp:
    db  0
    db  "MSXIRC  HLP"
    ds  28

; Segment Descriptor for Help Window
helpdes:
    db  "Help ",0

tsb:
    dw  0                               ; counter
    dw  0                               ; pointer
    ds  512                             ; send buffer

; This is used at load time, a check to make sure file has been fully loaded
chsas:
    dw  1255

;--- Screen buffers
fulls               equ #8000           ; 16kB segment for one channel or private message
;#8000-886F PNT buffer - Reserved for text page of the screen
;#8870-89FF free area for variable parametr
;#8A00-8B0E CT buffer
;#8C00-8DFF = 512 b nick name buffer
;#8E00-8FFF = -512
;#9000-BFFF = 12287 free bytes for text buffer
w0new               equ #8000+2         ; nlnew+1
w1new               equ w0new+2         ; Seems to hold if a new nicklist should be printed on screen or not
sWCB0               equ #8870           ; Hold the active Window on Screen WCB, 24 bytes long
sWCB1               equ #8870+24        ; If needed, hold the Window List or Nick List WCB, 24 bytes long
sWCB2               equ #8870+48        ; This is for the Input box on Server/Channel/Query Windows
oldcur              equ #8870+48+24     ; (3)
segs                equ #8870+48+24+3   ; (1) #88BB
segsR               equ #8870+48+24+3+1 ; (1) - map segment parental server
nlnew               equ #8870+48+24+3+1+1; (1) - flag new nickname list
    END