; ---------------------------------------------------------------
; RetroDB 1.1 - definitions
; ---------------------------------------------------------------

MLI       = $BF00
DEVNUM    = $BF30
DEVCNT    = $BF31
DEVLST    = $BF32
MACHID    = $BF98
NODEV     = $BF10       ; DEVADR entry for slot 0 drive 1 = "no device"
DEVADR32  = $BF26       ; slot 3 drive 2 (/RAM)

KBD       = $C000
CLR80STORE= $C000
SET80STORE= $C001
CLR80COL  = $C00C
SET80COL  = $C00D
CLRALTCHAR= $C00E
SETALTCHAR= $C00F
KBDSTRB   = $C010
TXTCLR    = $C050
TXTSET    = $C051
MIXCLR    = $C052
LOWSCR    = $C054
HISCR     = $C055
LORES     = $C056
HIRES     = $C057
DHIRESOFF = $C05F
BUTN0     = $C061
BUTN1     = $C062
AUXMOVE   = $C311
A1L       = $3C         ; AUXMOVE source start
A2L       = $3E         ; AUXMOVE source end (inclusive)
A4L       = $42         ; AUXMOVE destination

; mouse firmware entry-table offsets
SETMOUSE  = $12
READMOUSE = $14
POSMOUSE  = $16
CLAMPMOUSE= $17
INITMOUSE = $19

; zero page
ptr1      = $60
ptr2      = $62
ptr3      = $64
sptr      = $66
cx        = $68
cy        = $69
inv       = $6A
t0        = $6B
t1        = $6C
t2        = $6D
t3        = $6E
t4        = $6F
rp        = $70         ; current record
rp2       = $72         ; second record (sorting)
rq        = $74         ; scratch pointer
num       = $84         ; 5 bytes (40-bit)
num2      = $89         ; 5 bytes
mrom      = $7C         ; 2 bytes ($Cn00)
mjmp      = $7E         ; 2 bytes

; ---------------------------------------------------------------
; the form: up to 16 fields of seven kinds
; ---------------------------------------------------------------
MAXFIELDS = 16
K_TEXT    = 1           ; 1+len bytes, length-prefixed
K_NUMBER  = 2           ; 4 bytes, signed whole number
K_MONEY   = 3           ; 4 bytes, signed cents
K_DATE    = 4           ; 1+10 bytes, YYYY, YYYY-MM or YYYY-MM-DD
K_YESNO   = 5           ; 1 byte, 0 blank, 1 Yes, 2 No
K_NO      = 6           ; 2 bytes, record number 1-999 (0 blank)
K_PARTOF  = 7           ; 2 bytes, the No. of the record it is in
NKINDS    = 7
MAXTEXT   = 56          ; longest Text field
MAXNAME   = 15          ; longest field name
MAXRECSZ  = 255         ; longest record
MAXCRIT   = 30          ; longest selection criterion
EDITW     = 57          ; bytes per field in EDITTXT (1 + MAXTEXT)
CRITW     = 31
BLANKHI   = $80         ; Number/Money blank = $80000000
MAXNUM    = 999999999   ; largest Number, and largest Money in cents
MAXCENTS  = MAXNUM

MAXREC    = 250
PTRLO     = $0800       ; record pointer tables, MAXREC bytes each
PTRHI     = $0900
PTRBK     = $0A00       ; 0 = main memory, 1 = auxiliary memory
VIEW      = $0B00       ; the records shown in the list (logical indexes)
LINEBUF   = $0C00       ; file lines (256)
INBUF     = $0D00       ; Mouse Calc input buffer (256)
DIRBUF    = $0D00       ; directory block ($0D00-$0EFF)
CELLBUF   = $0E00       ; Mouse Calc cell body
OBUF      = $0E00       ; Mouse Calc output buffer
SCRATCH   = $0F00
TMPSTR    = SCRATCH     ; 72 bytes
DIGITS    = SCRATCH+72  ; 52
ENBUF     = SCRATCH+124 ; 24
TMP2      = SCRATCH+148 ; 72
ROWSKIP   = SCRATCH+220 ; 32 bytes: rows of an imported sheet to leave out
PREFIXBUF = $0300       ; page 3 ($0300-$03CF) is free under ProDOS:
mc_path   = $0342       ; 66 bytes each
colmap    = $0384       ; 64 bytes
        .import __LCODE_RUN__, __LCODE_SIZE__
        .import __XBSS_RUN__, __XBSS_SIZE__
        .import __SPLZ_RUN__, __SPLZ_SIZE__
POOLA     = __XBSS_RUN__ + __XBSS_SIZE__  ; main memory left after LCODE
POOLA_END = $4000
TBASE     = __SPLZ_RUN__                  ; nesting tables (nest.s), over
                                          ; the title picture once shown
TBSIZE    = 3 * 250 + 128 + 64            ; NOLO NOHI DEPTH NOMAP FAKEREC
POOLB     = TBASE + TBSIZE                ; main memory after the program
AUXPOOL   = $0800       ; record pool in auxiliary memory
AUXPOOL_END = $C000
FILEBUF   = $BB00       ; ProDOS file buffer, $BB00-$BEFF
POOLB_END = $BB00

LISTTOP   = 4
LISTROWS  = 17

EV_KEY    = 1
EV_MOUSE  = 2

; glyph codes understood by putch (MouseText)
G_OA      = $01
G_CA      = $02
G_RET     = $03
G_UP      = $04
G_DOWN    = $05
G_LEFT    = $06
G_RIGHT   = $07
G_CHECK   = $08
G_DOTS    = $09
G_PTR     = $0A
G_BLOCK   = $0B
G_OVER    = $0C
G_RBAR    = $0D       ; line on right edge of cell (left window border)
G_LBAR    = $0E       ; line on left edge of cell (right window border)
G_CHECKER = $0F
G_DIAMOND = $10
G_SCRUP   = $11
G_SCRDN   = $12

; commands
CMD_ABOUT    = 0
CMD_NEWDB    = 1
CMD_OPEN     = 2
CMD_SAVE     = 3
CMD_SAVEAS   = 4
CMD_REVERT   = 5
CMD_DESIGN   = 6
CMD_IMPORT   = 7
CMD_EXPORT   = 8
CMD_QUIT     = 9
CMD_NEWREC   = 10
CMD_EDIT     = 11
CMD_DUP      = 12
CMD_DELETE   = 13
CMD_DELSEL   = 14
CMD_FIND     = 15
CMD_FINDNEXT = 16
CMD_SORT0    = 17       ; 17..32: sort by field 0..15
CMD_SELECT   = 33
CMD_SHOWALL  = 34
CMD_REPORT   = 35
NCMDS        = 36

.macro POS xx, yy
        lda #xx
        sta cx
        lda #yy
        sta cy
.endmacro

.macro PRT str
        lda #<(str)
        ldy #>(str)
        jsr prt
.endmacro

.macro PRTS s
        jsr prti
        .byte s, 0
.endmacro

.macro MLICALL cmd, parms
        jsr MLI
        .byte cmd
        .word parms
.endmacro

.macro LDAY addr
        lda #<(addr)
        ldy #>(addr)
.endmacro
