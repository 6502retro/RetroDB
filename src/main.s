; ---------------------------------------------------------------
; MouseDB 1.1 - a forms database for the Apple II
; by 6502Retro.  ProDOS 8 system program, 80-column MouseText UI.
; Built on the RetroInv 2.5 engine.
; ---------------------------------------------------------------
        .setcpu "6502"
        .macpack longbranch
        .include "defs.inc"

; ProDOS loads the file at $2000 and starts it there: LCODE begins
; with a JMP to start.
        .segment "LCODE"
        jmp start

        .segment "CODE"
start:  cld
        sta KBDSTRB
        ; need an enhanced IIe, IIc or IIgs (MouseText + 80 columns)
        lda $FBB3
        cmp #$06
        jne badmachine
        lda $FBC0
        cmp #$EA
        jeq badmachine
        lda #0
        sta curon
        sta hasmouse
        sta inv
        sta kb_head
        sta kb_tail
        lda #$FF
        sta mopen
        jsr initmouse
        jsr auxinit             ; (before the picture: it borrows aux memory)
        jsr fixprefix
        lda auxok
        beq @text               ; no auxiliary memory free: no picture
        sec                     ; LCODE ($2000-$3FFF) -> aux $0800
        jsr lcswap
        jsr unsplash
        sta CLR80STORE          ; show the title picture
        sta CLR80COL
        sta DHIRESOFF
        sta MIXCLR
        sta HIRES
        sta LOWSCR
        sta TXTCLR
        jsr splashwait
        clc                     ; and LCODE back
        jsr lcswap
@text:  ; switch to 80-column MouseText text
        sta TXTSET
        sta LORES
        sta SET80COL
        sta SET80STORE
        sta SETALTCHAR
        sta LOWSCR
        jsr clrscr
        POS 33, 11
        PRTS "Loading"
        lda #G_DOTS
        jsr putch
        lda #0
        sta count
        sta vcount
        sta sel
        sta top
        sta dirty
        sta redraw
        sta named
        sta FINDSTR
        sta selactive
        jsr clearform
        jsr readlast            ; the database used last time
        bcs @ok                 ; none: start with an empty one
        jsr doload
        bcc @ld
        jsr loaderror
        jsr clearform
        lda #0
        sta named
        jmp @ok
@ld:    lda #1
        sta named
@ok:    jsr overwarn
        lda ramfull
        beq @go
        jsr drawall
        lda #<al_ramfull
        ldy #>al_ramfull
        jsr alert
@go:    jmp mainloop

; lcswap: carry set = main $2000-$3FFF -> aux $0800-$27FF (put LCODE
; aside), clear = back again
lcswap: php
        lda #<$2000
        ldx #<$0800
        plp
        php
        bcs @out
        sta A4L                 ; aux $0800 -> main $2000
        lda #>$2000
        sta A4L+1
        stx A1L
        lda #>$0800
        sta A1L+1
        lda #<$27FF
        sta A2L
        lda #>$27FF
        sta A2L+1
        jmp @go
@out:   sta A1L                 ; main $2000 -> aux $0800
        lda #>$2000
        sta A1L+1
        lda #<$3FFF
        sta A2L
        lda #>$3FFF
        sta A2L+1
        stx A4L
        lda #>$0800
        sta A4L+1
@go:    plp
        jmp auxmv

; unsplash: unpack the title picture into $2000-$3FFF.  Tokens: t < $80:
; t+1 literal bytes; t >= $80: (t & $7F) + 3 bytes copied from a 2-byte
; distance back.
unsplash:
        lda #<splashlz
        sta ptr1
        lda #>splashlz
        sta ptr1+1
        lda #<$2000
        sta ptr2
        lda #>$2000
        sta ptr2+1
        ldy #0
@tok:   lda ptr2+1
        cmp #$40
        bcs @d
        jsr @get
        cmp #$80
        bcs @match
        tax
        inx
@lit:   jsr @get
        sta (ptr2),y
        jsr @inc2
        dex
        bne @lit
        beq @tok
@match: and #$7F
        clc
        adc #3
        tax
        jsr @get
        sta t0
        jsr @get
        sta t1
        sec
        lda ptr2
        sbc t0
        sta ptr3
        lda ptr2+1
        sbc t1
        sta ptr3+1
@m:     lda (ptr3),y
        sta (ptr2),y
        inc ptr3
        bne @m2
        inc ptr3+1
@m2:    jsr @inc2
        dex
        bne @m
        beq @tok
@d:     rts
@get:   lda (ptr1),y
        inc ptr1
        bne @g
        inc ptr1+1
@g:     rts
@inc2:  inc ptr2
        bne @i
        inc ptr2+1
@i:     rts

        .segment "SPLZ"         ; (memory for records once it is shown)
splashlz: .incbin "../build/splash.lz"
        .segment "CODE"

; clearform: an empty database with no fields
clearform:
        lda #0
        sta nfields
        sta count
        sta vcount
        sta sel
        sta top
        sta selactive
        sta sortdesc
        lda #$FF
        sta sortkey
        jsr fdsetup
        jsr initpool
        jmp formchanged

; formchanged: after the fields change - list columns, Sort menu
formchanged:
        jsr nestf
        jsr calccols
        jmp buildsortmenu

; overwarn: after loading, if the file had more records than fit, or
; doesn't hold the number of records it says, open it as Untitled so a
; Save can't overwrite the file with a shortened copy.
overwarn:
        lda #<al_over
        ldy #>al_over
        ldx ld_over
        bne @w
        lda #<al_short
        ldy #>al_short
        ldx ld_short
        beq @d
@w:     sta ow_p
        sty ow_p+1
        lda #0
        sta named
        jsr drawall
        lda ow_p
        ldy ow_p+1
        jmp alert
@d:     rts

badmachine:
        sta TXTSET
        sta CLR80COL
        sta CLRALTCHAR
        sta CLR80STORE
        sta LOWSCR
        ldx #0
@cl:    lda #$A0
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne @cl
        ldx #0
@m:     lda badmsg,x
        beq @w
        ora #$80
        sta $0528,x
        inx
        bne @m
@w:     lda KBD
        bpl @w
        sta KBDSTRB
        MLICALL $65, quit_parms
        brk

        .segment "RODATA"
badmsg: .byte "NEEDS ENHANCED IIE/IIC/IIGS - PRESS KEY", 0
        .segment "CODE"

; splashwait: until a key, a click, or about five seconds
splashwait:
        lda #0
        sta t0
        sta t1
        lda #5
        sta t2
@l:     jsr spkey
        bmi @key
        inc t0
        bne @l
        jsr pollmouse
        lda mpress
        bne @d
        inc t1
        bne @l
        dec t2
        bne @l
@d:     rts
@key:   sta KBDSTRB
        rts
spkey:  lda KBD
        rts

; ---------------------------------------------------------------
; list columns
; ---------------------------------------------------------------
; calccols: the fields marked "In list", left to right while they fit
LISTW = 78
calccols:
        lda #0
        sta nlcols
        lda #1
        sta cc_x
        ldx #0
@f:     cpx nfields
        jcs @d
        lda flist,x
        jeq @n
        stx cc_f
        lda fkind,x
        pha
        lda flen,x
        tax
        pla
        jsr kindwidth
        ldx cc_f
        ldy #24                 ; widest column: 24, or 30 for the names
        cpx nf_nm               ; of a form with Part Of (room to indent)
        bne @cap
        ldy nf_po
        iny
        beq @cap0
        ldy #30
        bne @cap
@cap0:  ldy #24
@cap:   sty cc_cap
        cmp cc_cap
        bcc @w
        lda cc_cap
@w:     sta cc_w
        jsr fnameptr            ; at least as wide as a short name
        ldy #0
        lda (ptr1),y
        cmp #8
        bcc @nl
        lda #8
@nl:    cmp cc_w
        bcc @nw
        sta cc_w
@nw:    lda cc_x                ; room left?
        clc
        adc cc_w
        cmp #LISTW+1
        bcc @fit
        lda #LISTW
        sec
        sbc cc_x
        bcc @d
        cmp #4
        bcc @d
        sta cc_w
@fit:   ldy nlcols
        lda cc_f
        sta lc_f,y
        lda cc_x
        sta lc_x,y
        lda cc_w
        sta lc_w,y
        inc nlcols
        lda cc_x
        clc
        adc cc_w
        adc #1
        sta cc_x
        ldx cc_f
@n:     inx
        jne @f
@d:     rts

; isnumk: A = kind -> carry set if Number or Money (shown on the right)
isnumk: cmp #K_NUMBER
        beq @y
        cmp #K_MONEY
        beq @y
        clc
        rts
@y:     sec
        rts

; ---------------------------------------------------------------
; main screen
; ---------------------------------------------------------------
drawall:
        jsr clrscr
        jsr drawmenubar
        jsr drawheaders
        jsr drawlist
        jsr drawstatus
        jmp drawhints

drawheaders:
        lda #0
        sta inv
        sta dh_c
@c:     lda dh_c
        cmp nlcols
        bcs @line
        tay
        lda lc_x,y
        sta cx
        lda #2
        sta cy
        ldx lc_f,y
        jsr fnameptr
        jsr fld2tmp
        ldy dh_c
        ldx lc_f,y
        lda fkind,x
        jsr isnumk
        lda #0
        rol a
        sta pf_right
        ldy dh_c
        lda lc_w,y
        jsr prtfit
        inc dh_c
        bne @c
@line:  POS 0, 3
        lda #G_OVER
        ldx #79
        jsr rep
        POS 0, 21
        lda #G_OVER
        ldx #80
        jmp rep

; prtfit: TMPSTR in a column of width A, left (pf_right = 0) or
; right aligned, cut to fit
prtfit: sta pf_w
        ldx #0
@len:   lda TMPSTR,x
        beq @gl
        inx
        bne @len
@gl:    cpx pf_w
        bcc @ok
        ldx pf_w
@ok:    stx pf_n
        lda pf_right
        beq @l
        lda pf_w
        sec
        sbc pf_n
        tax
        jsr spaces
@l:     ldx #0
@p:     cpx pf_n
        beq @pad
        lda TMPSTR,x
        jsr putch
        inx
        bne @p
@pad:   lda pf_right
        bne @d
        lda pf_w
        sec
        sbc pf_n
        tax
        jmp spaces
@d:     rts

drawlist:
        jsr ensurevis
        lda nfields
        bne @have
        jmp drawnoform
@have:  lda #0
        sta dl_r
@r:     lda dl_r
        clc
        adc #LISTTOP
        sta cy
        lda #0
        sta cx
        sta inv
        lda dl_r
        clc
        adc top
        bcs @blank
        cmp vcount
        bcs @blank
        jsr drawrow
        jmp @n
@blank: ldx #79
        jsr spaces
@n:     inc dl_r
        lda dl_r
        cmp #LISTROWS
        bne @r
        jmp drawscroll

drawnoform:
        lda #LISTTOP
        sta cy
@c:     jsr clrrow
        inc cy
        lda cy
        cmp #LISTTOP+LISTROWS
        bne @c
        POS 25, 10
        PRT s_noform1
        POS 15, 12
        PRT s_noform2
        POS 17, 13
        PRT s_noform3
        rts

        .segment "RODATA"
s_noform1: .byte "This database has no form yet.", 0
s_noform2: .byte "Choose Design Form from the File menu to set up its", 0
s_noform3: .byte "fields, or Import from Mouse Calc to start from a sheet.", 0
        .segment "CODE"

; drawrow: A = view position, cy = row
drawrow:
        sta dr_i
        tax
        lda VIEW,x
        jsr recget
        lda #0
        sta cx
        lda dr_i
        cmp sel
        bne @n
        lda #1
        sta inv
@n:     ldx #79
        jsr spaces
        lda #0
        sta dh_c
        sta f2t_mode
@c:     lda dh_c
        cmp nlcols
        bcs @d
        tay
        lda lc_x,y
        sta cx
        ldx lc_f,y
        jsr getfk
        jsr f2t
        jsr tr_indent
        lda fk_k
        jsr isnumk
        lda #0
        rol a
        sta pf_right
        ldy dh_c
        lda lc_w,y
        jsr prtfit
        inc dh_c
        bne @c
@d:     lda #0
        sta inv
        rts

drawscroll:
        lda #0
        sta inv
        POS 79, LISTTOP
        lda #G_SCRUP
        jsr putch
        lda #LISTTOP+1
        sta cy
@t:     lda #79
        sta cx
        lda #G_CHECKER
        jsr putch
        inc cy
        lda cy
        cmp #LISTTOP+LISTROWS-1
        bne @t
        lda #79
        sta cx
        lda #G_SCRDN
        jsr putch
        lda #$FF
        sta thumbrow
        lda vcount
        cmp #2
        bcc @d
        ; thumb = 5 + sel*14/(vcount-1)
        lda #0
        sta t2
        sta t3
        ldx #LISTROWS-3
@m:     clc
        lda t2
        adc sel
        sta t2
        bcc @m2
        inc t3
@m2:    dex
        bne @m
        ldx vcount
        dex
        stx t4
        ldx #0
@dv:    lda t2
        sec
        sbc t4
        tay
        lda t3
        sbc #0
        bcc @dd
        sta t3
        sty t2
        inx
        bne @dv
@dd:    txa
        clc
        adc #LISTTOP+1
        sta cy
        sta thumbrow
        lda #79
        sta cx
        lda #$20
        jsr putsc
@d:     rts

drawstatus:
        lda #22
        sta cy
        jsr clrrow
        lda #1
        sta cx
        lda selactive
        beq @all
        lda vcount
        jsr setnum8
        ldx #0
        jsr prnum
        PRTS " selected of "
        lda count
        jsr setnum8
        ldx #0
        jsr prnum
        PRTS " records"
        jmp @tot
@all:   lda count
        jsr setnum8
        ldx #0
        jsr prnum
        PRTS " of "
        lda maxrec
        jsr setnum8
        ldx #0
        jsr prnum
        PRTS " records"
@tot:   jsr totfield            ; total of the first Money field
        bcs @mod
        lda #32
        sta cx
        PRTS "Total "
        ldx st_f
        jsr fnameptr
        jsr fld2tmp
        lda #0
        sta pf_right
        lda TMPSTR
        ldx #0
@tl:    lda TMPSTR,x
        beq @te
        inx
        cpx #14
        bcc @tl
@te:    txa
        jsr prtfit
        PRTS ": "
        jsr viewsum
        ldx st_f
        lda fkind,x
        jsr prsigned40
@mod:   lda dirty
        beq @d
        lda #70
        sta cx
        lda #G_DIAMOND
        jsr putch
        PRTS " Modified"
@d:     rts

; statusmsg: show A/Y on the status line
statusmsg:
        pha
        tya
        pha
        lda #22
        sta cy
        jsr clrrow
        lda #1
        sta cx
        pla
        tay
        pla
        jmp prt

; totfield: st_f = the first Money field (else the first Number field).
; carry set if there is none.
totfield:
        lda #K_MONEY
        jsr @find
        bcc @d
        lda #K_NUMBER
@find:  sta t0
        ldx #0
@l:     cpx nfields
        bcs @no
        lda fkind,x
        cmp t0
        beq @y
        inx
        bne @l
@no:    sec
        rts
@y:     stx st_f
        clc
@d:     rts

; viewsum: sum40 = the total of field st_f over the records in the view
viewsum:
        lda #0
        ldx #4
@z:     sta sum40,x
        dex
        bpl @z
        sta vs_i
@l:     lda vs_i
        cmp vcount
        bcs @d
        tax
        lda VIEW,x
        ldx st_f
        jsr recgetf
        ldx st_f
        jsr getfk
        jsr addfld40
        inc vs_i
        bne @l
@d:     rts

; addfld40: sum40 += field fk_* of rp (signed; blanks count as 0)
addfld40:
        jsr isblank
        beq @d
        ldy fk_o
        lda (rp),y
        clc
        adc sum40
        sta sum40
        iny
        lda (rp),y
        adc sum40+1
        sta sum40+1
        iny
        lda (rp),y
        adc sum40+2
        sta sum40+2
        iny
        lda (rp),y
        tax                     ; sign extension for byte 4
        adc sum40+3
        sta sum40+3
        lda #0
        cpx #$80
        bcc @p
        lda #$FF
@p:     adc sum40+4
        sta sum40+4
@d:     rts

; prsigned40: print sum40 as kind A (Money as $, Number plain)
prsigned40:
        sta ps_k
        ldx #4
@c:     lda sum40,x
        sta num,x
        dex
        bpl @c
        lda num+4
        bpl @p
        jsr negnum
        lda #'-'
        jsr putch
@p:     lda ps_k
        cmp #K_MONEY
        beq @m
        ldx #0
        jmp prnum
@m:     ldx #0
        jmp prmoney

drawhints:
        POS 0, 23
        lda #0
        sta inv
        PRTS {" ",G_OA,"N New  RETURN Edit  ",G_OA,"F Find  ",G_OA,"L Select  ",G_OA,"R Report  ",G_OA,"S Save  ",G_OA,"Q Quit  ESC Menus"}
        rts

; ensurevis: keep sel valid and visible
ensurevis:
        lda vcount
        bne @a
        lda #0
        sta sel
        sta top
        rts
@a:     lda sel
        cmp vcount
        bcc @b
        ldx vcount
        dex
        stx sel
@b:     lda sel
        cmp top
        bcs @c
        sta top
@c:     lda sel
        sec
        sbc top
        cmp #LISTROWS
        bcc @e
        lda sel
        sec
        sbc #LISTROWS-1
        sta top
@e:     lda vcount
        sec
        sbc #LISTROWS
        bcs @f
        lda #0
@f:     cmp top
        bcs @g
        sta top
@g:     rts

; ---------------------------------------------------------------
; the view: which records the list shows
; ---------------------------------------------------------------
; showall: every record, in order
showall:
        ldx #0
@l:     cpx count
        bcs @d
        txa
        sta VIEW,x
        inx
        bne @l
@d:     stx vcount
        rts

; rebuildview: all records, or those matching the selection
rebuildview:
        lda selactive
        beq showall
        jmp selectview

; viewdel: record A was deleted: drop it from the view, renumber the rest
viewdel:
        sta vd_r
        ldx #0
        ldy #0
@l:     cpx vcount
        bcs @d
        lda VIEW,x
        cmp vd_r
        beq @n
        bcc @k
        sec
        sbc #1
@k:     sta VIEW,y
        iny
@n:     inx
        bne @l
@d:     sty vcount
        rts

; ---------------------------------------------------------------
; main loop
; ---------------------------------------------------------------
mainloop:
        jsr drawall
        lda #0
        sta redraw
@ev:    jsr getevent
        cmp #EV_KEY
        beq @key
        jsr mainclick
        jmp @after
@key:   jsr mainkey
@after: lda redraw
        beq @ev
        cmp #2
        beq mainloop
        cmp #3
        bne @list
        jsr selrows             ; the selection moved
        jmp @r0
@list:  jsr drawlist
        jsr drawstatus
@r0:    lda #0
        sta redraw
        jmp @ev

; selrows: redraw the rows of oldsel and sel (the whole list if the
; list has to scroll)
selrows:
        lda top
        pha
        jsr ensurevis
        pla
        cmp top
        bne @all
        lda oldsel
        jsr @row
        lda sel
        jsr @row
        jmp drawscroll
@all:   jmp drawlist
@row:   sta sr_v
        sec
        sbc top
        bcc @d
        cmp #LISTROWS
        bcs @d
        clc
        adc #LISTTOP
        sta cy
        lda sr_v
        cmp vcount
        bcs @d
        jmp drawrow
@d:     rts

mainkey:
        lda keych
        jsr toupper
        sta keych
        cmp #$0B
        beq @up
        cmp #$0A
        beq @down
        cmp #$08
        beq @pgup
        cmp #$15
        beq @pgdn
        cmp #$0D
        bne @k1
        lda #CMD_EDIT
        jmp docmd
@k1:    cmp #$1B
        bne @k2
        lda #1
        ldx #1
        jsr menuloop
        jmp domenucmd
@k2:    lda keyoa               ; commands need Open-Apple (or Solid-Apple)
        beq @d
        ldx #0
@kl:    lda keytab,x
        beq @d
        cmp keych
        beq @kf
        inx
        inx
        bne @kl
@kf:    lda keytab+1,x
        jmp docmd
@d:     rts
@up:    lda sel
        beq @d
        sta oldsel
        dec sel
        jmp @mv1
@down:  ldx sel
        inx
        cpx vcount
        bcs @d
        lda sel
        sta oldsel
        stx sel
@mv1:   lda #3                  ; just the two rows, if they're on screen
        sta redraw
        rts
@pgup:  lda sel
        sec
        sbc #LISTROWS
        bcs @pu
        lda #0
@pu:    sta sel
        jmp @mv
@pgdn:  lda sel
        clc
        adc #LISTROWS
        bcs @pd1
        cmp vcount
        bcc @pd
@pd1:   ldx vcount
        beq @d
        dex
        txa
@pd:    sta sel
@mv:    lda #1
        sta redraw
        rts

        .segment "RODATA"
keytab: .byte 'N', CMD_NEWREC, 'E', CMD_EDIT, 'D', CMD_DELETE, 'C', CMD_DUP
        .byte 'F', CMD_FIND, 'G', CMD_FINDNEXT, 'S', CMD_SAVE
        .byte 'R', CMD_REPORT, 'Q', CMD_QUIT, '?', CMD_ABOUT, '/', CMD_ABOUT
        .byte 'I', CMD_IMPORT, 'X', CMD_EXPORT, 'O', CMD_OPEN
        .byte 'L', CMD_SELECT, 'A', CMD_SHOWALL, 0
        .segment "CODE"

mainclick:
        lda mrow
        bne @nm
        lda mcol
        jsr menuhit
        cmp #$FF
        beq @d
        ldx #0
        jsr menuloop
        jmp domenucmd
@nm:    cmp #LISTTOP
        bcc @d
        cmp #LISTTOP+LISTROWS
        bcs @d
        lda mcol
        cmp #79
        beq @scroll
        lda mrow
        sec
        sbc #LISTTOP
        clc
        adc top
        bcs @d
        cmp vcount
        bcs @d
        cmp sel
        beq @open
        ldx sel
        stx oldsel
        sta sel
        lda #3
        sta redraw
@d:     rts
@open:  lda #CMD_EDIT
        jmp docmd
@scroll:
        lda mrow
        cmp #LISTTOP
        bne @s1
        lda #$0B
        bne @sk
@s1:    cmp #LISTTOP+LISTROWS-1
        bne @s2
        lda #$0A
        bne @sk
@s2:    cmp thumbrow
        bcc @s3
        lda #$15
        bne @sk
@s3:    lda #$08
@sk:    sta keych
        jmp mainkey

domenucmd:
        cmp #$FF
        bne docmd
        rts                     ; (the menu put the screen back)

; docmd: A = command
docmd:  pha
        jsr notab_inval
        pla
        cmp #CMD_SORT0
        bcc @t
        cmp #CMD_SORT0+MAXFIELDS
        bcs @t
        sec
        sbc #CMD_SORT0
        jmp cmd_sort
@t:     cmp #CMD_SORT0+MAXFIELDS
        bcc @t2
        sec
        sbc #MAXFIELDS
@t2:    asl a
        tax
        lda #2
        sta redraw
        lda cmdtab+1,x
        pha
        lda cmdtab,x
        pha
        rts

        .segment "RODATA"
cmdtab: .word cmd_about-1, cmd_newdb-1, cmd_open-1, cmd_save-1
        .word cmd_saveas-1, cmd_revert-1, cmd_design-1, cmd_import-1
        .word cmd_export-1, cmd_quit-1, cmd_newrec-1, cmd_edit-1
        .word cmd_dup-1, cmd_delete-1, cmd_delsel-1, cmd_find-1
        .word cmd_findnext-1
        .word cmd_select-1, cmd_showall-1, cmd_report-1
        .segment "CODE"

; ---------------------------------------------------------------
; record commands
; ---------------------------------------------------------------
cmd_about:
        lda #<al_about
        ldy #>al_about
        jmp alert

; needform: carry set (and Design Form opened) if there are no fields
needform:
        lda nfields
        bne @ok
        jsr cmd_design
        sec
        rts
@ok:    clc
        rts

; isfull: carry set (with a message) if no more records fit
isfull: lda count
        cmp maxrec
        bcc @ok
        lda #<al_full
        ldy #>al_full
        jsr alert
        sec
        rts
@ok:    clc
        rts

cmd_newrec:
        jsr needform
        bcs @x
        jsr isfull
        bcs @x
        jsr cleartxt
        lda #<t_new
        ldy #>t_new
        jmp addrec
@x:     rts

cmd_dup:
        lda vcount
        beq @x
        jsr isfull
        bcs @x
        ldx sel
        lda VIEW,x
        jsr recget
        jsr rec2txt
        ldx nf_no               ; the copy gets a No. of its own
        cpx #$FF
        beq @t
        jsr etptr
        lda #0
        tay
        sta (ptr2),y
@t:     lda #<t_dup
        ldy #>t_dup
        jmp addrec
@x:     rts

; addrec: edit EDITTXT as a new record (title A/Y); on OK add it
addrec: ldx #$FF
        stx ed_rec
        jsr editrec
        bcs @x
        lda count
        jsr recgetw
        jsr edit2rec
        jsr assignno
        jsr recput
        ldx vcount
        lda count
        sta VIEW,x
        stx sel
        inc vcount
        inc count
        lda #1
        sta dirty
        jsr notab_inval
        jsr retree
@x:     lda #2
        sta redraw
        rts

cmd_edit:
        lda vcount
        beq @x
        ldx sel
        lda VIEW,x
        sta ed_rec
        jsr recget
        jsr rec2txt
        lda #<t_edit
        ldy #>t_edit
        jsr editrec
        bcs @x
        lda ed_rec
        jsr recgetw
        jsr edit2rec
        jsr recput
        lda #1
        sta dirty
        jsr notab_inval
        jsr retree
@x:     lda #2
        sta redraw
        rts

cmd_delete:
        lda vcount
        jeq @x
        jsr mb_reset
        lda #<s_delq
        ldy #>s_delq
        jsr mb_str
        ldx sel
        lda VIEW,x
        jsr mb_recname
        ldx sel                 ; records inside it?
        lda VIEW,x
        jsr kids
        beq @nk
        pha
        lda #<s_kids1
        ldy #>s_kids1
        jsr mb_str
        pla
        jsr mb_num8
        lda #<s_kids2
        ldy #>s_kids2
        jsr mb_str
@nk:    lda #<al_delete
        ldy #>al_delete
        jsr alert
        cmp #0
        bne @x
        ldx sel
        lda VIEW,x
        jsr delrec
        jsr unlink
        jsr retree
        lda #1
        sta dirty
@x:     lda #2
        sta redraw
        rts

; mb_recname: append record A's first non-blank field to MSGBUF
mb_recname:
        sta mr_r
        lda #0
        sta mr_f
        sta f2t_mode
@f:     ldx mr_f
        cpx nfields
        bcs @d
        lda mr_r
        jsr recget
        ldx mr_f
        jsr getfk
        lda fk_k                ; (not the No.)
        cmp #K_NO
        beq @nx
        jsr f2t
        bne @got
@nx:    inc mr_f
        bne @f
@got:   cmp #36
        bcc @c
        lda #0
        sta TMPSTR+36
@c:     lda #<TMPSTR
        ldy #>TMPSTR
        jmp mb_str
@d:     rts

; delrec: remove record A; its slot goes to the end of the table
delrec: sta dl_d
        tax
        lda PTRLO,x
        sta t2
        lda PTRHI,x
        sta t3
        lda PTRBK,x
        sta t4
@sh:    inx
        cpx count
        bcs @last
        lda PTRLO,x
        sta PTRLO-1,x
        lda PTRHI,x
        sta PTRHI-1,x
        lda PTRBK,x
        sta PTRBK-1,x
        jmp @sh
@last:  dex
        lda t2
        sta PTRLO,x
        lda t3
        sta PTRHI,x
        lda t4
        sta PTRBK,x
        dec count
        jsr notab_inval
        lda dl_d
        jmp viewdel

cmd_delsel:
        lda vcount
        jeq @x
        jsr mb_reset
        lda #<s_delsel1
        ldy #>s_delsel1
        ldx selactive
        bne @s
        lda #<s_delall1
        ldy #>s_delall1
@s:     jsr mb_str
        lda vcount
        jsr setnum8
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr mb_str
        lda #<s_delsel2
        ldy #>s_delsel2
        ldx selactive
        bne @s2
        lda #<s_delall2
        ldy #>s_delall2
@s2:    jsr mb_str
        lda #<al_delsel
        ldy #>al_delsel
        jsr alert
        cmp #0
        bne @x
        lda vcount
        sta ds_n
@l:     ldx vcount              ; the view is in record order: delete
        beq @done               ; from the last one back
        dex
        lda VIEW,x
        jsr delrec
        jmp @l
@done:  jsr unlink
        lda #0
        sta selactive
        jsr treeon
        bcc @nt
        jsr dotree
@nt:    jsr showall
        lda #0
        sta sel
        sta top
        lda #1
        sta dirty
        jsr drawall
        jsr mb_reset
        lda #<s_deld1
        ldy #>s_deld1
        jsr mb_str
        lda ds_n
        jsr setnum8
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jsr mb_str
        lda #<s_deld2
        ldy #>s_deld2
        jsr mb_str
        lda #<al_error
        ldy #>al_error
        jsr alert
@x:     lda #2
        sta redraw
        rts

doquit: jsr clrscr
        jsr raminstall
        sta TXTSET
        sta CLRALTCHAR
        sta CLR80STORE
        sta CLR80COL
        sta LOWSCR
        MLICALL $65, quit_parms
        brk

loaderror:
        pha
        jsr drawall
        jsr mb_reset
        lda #<s_loaderr
        ldy #>s_loaderr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<al_error
        ldy #>al_error
        jmp alert

saveerror:
        pha
        jsr drawstatus          ; clear "Saving..."
        jsr mb_reset
        lda #<s_saveerr
        ldy #>s_saveerr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<s_kept
        ldy #>s_kept
        jsr mb_str
        lda #<al_error
        ldy #>al_error
        jmp alert

; mb_errtext: A = ProDOS error code (or $80 = not a MouseDB file)
mb_errtext:
        cmp #$80
        bne @e0
        lda #<s_notdb
        ldy #>s_notdb
        jmp mb_str
@e0:    cmp #$2B
        bne @e1
        lda #<s_wp
        ldy #>s_wp
        jmp mb_str
@e1:    cmp #$48
        bne @e2
        lda #<s_full
        ldy #>s_full
        jmp mb_str
@e2:    cmp #$27
        bne @e3
        lda #<s_io
        ldy #>s_io
        jmp mb_str
@e3:    pha
        lda #<s_perr
        ldy #>s_perr
        jsr mb_str
        pla
        jmp mb_hex

        .segment "RODATA"
t_new:     .byte "New Record", 0
t_edit:    .byte "Edit Record", 0
t_dup:     .byte "Duplicate Record", 0
t_alert:   .byte "MouseDB", 0
s_saving:  .byte "Saving", G_DOTS, 0
s_delq:    .byte "Delete this record?||", 0
s_kids1:   .byte "||It holds ", 0
s_kids2:   .byte " records. They stay,|no longer part of anything.", 0
s_delsel1: .byte "Delete the ", 0
s_delsel2: .byte " selected|records? This can't be undone.", 0
s_delall1: .byte "Delete all ", 0
s_delall2: .byte " records?|This can't be undone.", 0
s_deld1:   .byte "Deleted ", 0
s_deld2:   .byte " records.", 0
s_loaderr: .byte "Could not open the database.||", 0
s_saveerr: .byte "Could not save the database.||", 0
s_kept:    .byte "|The file on disk was not changed.", 0
s_wp:      .byte "The disk is write-protected.", 0
s_full:    .byte "The disk is full.", 0
s_io:      .byte "Disk I/O error.", 0
s_perr:    .byte "ProDOS error $", 0
s_notdb:   .byte "It isn't a MouseDB database.", 0
s_about:   .byte "MouseDB 1.1 for the Apple II||"
           .byte "A forms database in the spirit|"
           .byte "of PFS:File, by 6502Retro", 0
s_fullm:   .byte "The database is full. Start a|"
           .byte "second one with New Database.", 0
s_ramfull: .byte "/RAM has files on it, so MouseDB|"
           .byte "is keeping records in main memory|"
           .byte "only, and fewer of them fit.", 0
s_revq:    .byte "Discard your changes and reload|"
           .byte "the database from disk?", 0
b_ok:      .byte "OK", 0
b_cancel:  .byte "Cancel", 0
b_delete:  .byte "Delete", 0
b_revert:  .byte "Revert", 0
b_save:    .byte "Save", 0
b_dont:    .byte "Don't Save", 0

al_about:  .word t_alert, s_about
           .byte 1
           .word b_ok
al_full:   .word t_alert, s_fullm
           .byte 1
           .word b_ok
al_revert: .word t_alert, s_revq
           .byte 2
           .word b_revert, b_cancel
al_ramfull: .word t_alert, s_ramfull
           .byte 1
           .word b_ok
al_delete: .word t_delrec, MSGBUF
           .byte 2
           .word b_delete, b_cancel
al_delsel: .word t_delsel, MSGBUF
           .byte 2
           .word b_delete, b_cancel
al_over:   .word t_alert, s_over
           .byte 1
           .word b_ok
s_over:    .byte "This database has more records|"
           .byte "than fit, so only the first ones|"
           .byte "were loaded. It is open as Untitled,|"
           .byte "so saving can't shorten the file.", 0
al_short:  .word t_alert, s_short
           .byte 1
           .word b_ok
s_short:   .byte "This file doesn't hold the number|"
           .byte "of records it says, so it may be|"
           .byte "damaged. It is open as Untitled,|"
           .byte "so the file is left as it is.", 0
al_error:  .word t_alert, MSGBUF
           .byte 1
           .word b_ok
t_delrec:  .byte "Delete Record", 0
t_delsel:  .byte "Delete Selected", 0

        .segment "BSS"
count:    .res 1
vcount:   .res 1
sel:      .res 1
top:      .res 1
dirty:    .res 1
redraw:   .res 1
maxrec:   .res 1
thumbrow: .res 1
selactive: .res 1
sortkey:  .res 1
sortdesc: .res 1
dl_r:     .res 1
dr_i:     .res 1
dh_c:     .res 1
ow_p:     .res 2
nlcols:   .res 1
lc_f:     .res MAXFIELDS
lc_x:     .res MAXFIELDS
lc_w:     .res MAXFIELDS
cc_x:     .res 1
cc_cap:   .res 1
cc_w:     .res 1
cc_f:     .res 1
pf_w:     .res 1
pf_n:     .res 1
pf_right: .res 1
st_f:     .res 1
vs_i:     .res 1
sum40:    .res 5
ps_k:     .res 1
vd_r:     .res 1
dl_d:     .res 1
ds_n:     .res 1
mr_r:     .res 1
mr_f:     .res 1
ed_rec:   .res 1
oldsel:   .res 1
sr_v:     .res 1
FINDSTR:  .res 22

        .include "screen.s"
        .include "num.s"
        .include "mouse.s"
        .include "ui.s"
        .include "menu.s"
        .include "mem.s"
        .include "fields.s"
        .include "form.s"
        .include "design.s"
        .include "select.s"
        .include "report.s"
        .include "file.s"
        .include "dbfile.s"
        .include "mcalc.s"
        .include "nest.s"

