; ---------------------------------------------------------------
; The record window (New, Edit, Duplicate) and Find
;
; While a record is open, each field is edited as text in EDITTXT
; (57 bytes per field, length-prefixed); OK parses the text back into
; EDITREC with t2f, so a bad number or date is caught before anything
; changes.  Yes/No fields are chosen with the arrows instead.
; ---------------------------------------------------------------
FL_LCOL = 3             ; field names
FL_VCOL = 20            ; values

        .segment "RODATA"
etlo:
.repeat MAXFIELDS, I
        .byte <(EDITTXT + I * EDITW)
.endrepeat
ethi:
.repeat MAXFIELDS, I
        .byte >(EDITTXT + I * EDITW)
.endrepeat
s_fhint: .byte "TAB or ", G_UP, G_DOWN, " next field  ", G_LEFT, G_RIGHT
         .byte " Yes/No  CTRL-X clear", 0
s_ok:    .byte "OK", 0
s_recof: .byte "Record ", 0
s_of:    .byte " of ", 0
s_newr:  .byte "New record", 0
s_empty: .byte "Please fill in at least one field,|"
         .byte "or press ESC to cancel.", 0
al_empty: .word t_alert, s_empty
          .byte 1
          .word b_ok
s_bad1:  .byte "Please type a whole number in|", 0
s_bad1m: .byte "Please type an amount in|", 0
s_bad2:  .byte "The number in ", 0
s_bad2b: .byte "|is too large. The largest is|", 0
s_max1:  .byte "999,999,999.", 0
s_max2:  .byte "$9,999,999.99.", 0
s_bad3:  .byte "Please type a date in|", 0
s_bad3b: .byte "|as YYYY-MM-DD or MM/DD/YYYY,|or leave it blank.", 0
s_bad1b: .byte ", like 42.", 0
s_bad1c: .byte ", like 12.50.", 0
        .segment "CODE"

; etptr: X = field -> ptr2 = its EDITTXT buffer
etptr:  lda etlo,x
        sta ptr2
        lda ethi,x
        sta ptr2+1
        rts

; cleartxt: every field empty
cleartxt:
        ldx #MAXFIELDS-1
@l:     jsr etptr
        lda #0
        tay
        sta (ptr2),y
        dex
        bpl @l
        rts

; rec2txt: record rp -> EDITTXT
rec2txt:
        lda #1
        sta f2t_mode
        ldx #0
@f:     cpx nfields
        bcs @d
        stx rt_f
        jsr getfk
        jsr f2t
        ldx rt_f
        jsr etptr
        jsr tmp2buf
        ldx rt_f
        inx
        bne @f
@d:     lda #0
        sta f2t_mode
        rts

; tmp2buf: TMPSTR -> length-prefixed buffer at ptr2 (max 56)
tmp2buf:
        ldx #0
        ldy #1
@l:     lda TMPSTR,x
        beq @d
        cpx #MAXTEXT
        bcs @d
        sta (ptr2),y
        inx
        iny
        bne @l
@d:     txa
        ldy #0
        sta (ptr2),y
        rts

; buf2tmp: length-prefixed buffer at ptr2 -> TMPSTR
buf2tmp:
        ldy #0
        lda (ptr2),y
        tax
        lda #0
        sta TMPSTR,x
@l:     txa
        beq @d
        tay
        lda (ptr2),y
        sta TMPSTR-1,x
        dex
        jmp @l
@d:     rts

; edit2rec: EDITREC -> (rp)
edit2rec:
        ldy #0
@l:     cpy recsize
        beq @d
        lda EDITREC,y
        sta (rp),y
        iny
        bne @l
@d:     rts

; ffld: X = field -> tf_* registers for its text box
ffld:   jsr etptr
        lda #FL_VCOL
        sta tf_col
        txa
        clc
        adc #5
        sta tf_row
        lda fkind,x
        cmp #K_TEXT
        bne @n
        lda flen,x
        sta tf_max
        lda #0
        sta tf_filt
        rts
@n:     cmp #K_NUMBER
        bne @m
        lda #12
        sta tf_max
        lda #4
        sta tf_filt
        rts
@m:     cmp #K_MONEY
        bne @dt
        inc tf_col              ; after the "$"
        lda #13
        sta tf_max
        lda #5
        sta tf_filt
        rts
@dt:    lda #10
        sta tf_max
        lda #6
        sta tf_filt
        rts

; drawefld: X = field (focused when X = ffoc)
drawefld:
        stx df_f
        txa
        clc
        adc #5
        sta cy
        lda #FL_LCOL
        sta cx
        lda #0
        cpx ffoc
        bne @n
        lda #1
@n:     sta inv
        sta df_foc
        jsr fnameptr
        jsr fld2tmp
        lda #0
        sta pf_right
        lda #MAXNAME
        jsr prtfit
        lda #0
        sta inv
        ldx df_f
        lda fkind,x
        cmp #K_YESNO
        beq @yn
        cmp #K_MONEY
        bne @t
        lda #FL_VCOL
        sta cx
        lda #'$'
        jsr putch
@t:     ldx df_f
        jsr ffld
        lda df_foc
        jmp drawtf
@yn:    lda #FL_VCOL
        sta cx
        lda #G_LEFT
        jsr putch
        jsr space
        lda df_foc
        sta inv
        ldx df_f
        jsr etptr
        jsr buf2tmp
        lda #0
        sta pf_right
        lda #3
        jsr prtfit
        lda #0
        sta inv
        jsr space
        lda #G_RIGHT
        jmp putch

drawform:
        lda #2
        sta wx
        sta wy
        lda #76
        sta ww
        lda nfields
        clc
        adc #4
        sta wh
        adc #2
        sta fbrow
        lda ftitle
        ldy ftitle+1
        jsr drawwin
        ldx #0
@f:     stx df_i
        jsr drawefld
        ldx df_i
        inx
        cpx nfields
        bne @f
        POS 56, 4
        lda ed_rec
        cmp #$FF
        bne @old
        PRT s_newr
        jmp @h
@old:   PRT s_recof
        lda ed_rec
        jsr setnum8
        jsr addnum8x1
        ldx #0
        jsr prnum
        PRT s_of
        lda count
        jsr setnum8
        ldx #0
        jsr prnum
@h:     lda #4
        sta cx
        lda fbrow
        sta cy
        PRT s_fhint
        lda #61
        sta cx
        lda #<s_ok
        ldy #>s_ok
        ldx #1
        jsr drawbtn
        lda #66
        sta cx
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jmp drawbtn

; addnum8x1: num += 1
addnum8x1:
        lda #1
        jmp addnum8

; editrec: A/Y = title.  Edits EDITTXT; OK fills EDITREC.
; Carry clear = OK.
editrec:
        sta ftitle
        sty ftitle+1
        lda #0
        sta ffoc
@full:  jsr hidecursor
        jsr drawform
@loop:  jsr getevent
        cmp #EV_KEY
        beq @key
        jmp @mouse
@key:   lda keych
        cmp #$0D
        bne @k1
        jmp @ok
@k1:    cmp #$1B
        bne @k2
        sec
        rts
@k2:    cmp #$09
        jeq @next
        cmp #$0A
        jeq @next
        cmp #$0B
        jeq @prev
        ldx ffoc
        lda fkind,x
        cmp #K_YESNO
        beq @selkey
        jsr ffld
        lda keych
        jsr tfkey
        bcc @loop
        ldx ffoc
        jsr drawefld
        jmp @loop
@selkey:
        lda keych
        cmp #$08
        beq @sprev
        cmp #$15
        beq @snext
        cmp #' '
        beq @snext
        jsr toupper             ; Y, N, or DELETE/CTRL-X for blank
        cmp #'Y'
        beq @sy
        cmp #'N'
        beq @sn
        cmp #$18
        beq @sb
        cmp #$7F
        beq @sb
        jmp @loop
@sy:    lda #1
        bne @sset
@sn:    lda #2
        bne @sset
@sb:    lda #0
        beq @sset
@snext: jsr ynget
        clc
        adc #1
        cmp #3
        bcc @sset
        lda #0
        beq @sset
@sprev: jsr ynget
        sec
        sbc #1
        bpl @sset
        lda #2
@sset:  jsr ynset
        ldx ffoc
        jsr drawefld
        jmp @loop
@next:  ldx ffoc
        inx
        cpx nfields
        bcc @setf
        ldx #0
        beq @setf
@prev:  ldx ffoc
        dex
        bpl @setf
        ldx nfields
        dex
@setf:  lda ffoc
        stx ffoc
        tax
        jsr drawefld
        ldx ffoc
        jsr drawefld
        jmp @loop
@mouse: lda mrow
        cmp fbrow
        bne @fhit
        lda mcol
        cmp #61
        bcc @lp
        cmp #65
        bcc @ok
        cmp #66
        bcc @lp
        cmp #74
        bcs @lp
        sec
        rts
@lp:    jmp @loop
@fhit:  lda mrow
        sec
        sbc #5
        bcc @lp
        cmp nfields
        bcs @lp
        tax
        lda ffoc
        stx ffoc
        tax
        jsr drawefld
        ldx ffoc
        jsr drawefld
        ldx ffoc                ; clicks on a Yes/No choice change it
        lda fkind,x
        cmp #K_YESNO
        bne @lp
        lda mcol
        cmp #FL_VCOL
        bcc @lp
        cmp #FL_VCOL+2
        bcs @mn
        jmp @sprev
@mn:    cmp #FL_VCOL+7
        bcs @lp
        jmp @snext
@ok:    ; parse every field into EDITREC
        lda #<EDITREC
        sta rp
        lda #>EDITREC
        sta rp+1
        lda #0
        sta ok_any
        ldx #0
@pf:    cpx nfields
        bcs @pd
        stx ok_f
        jsr etptr
        jsr buf2tmp
        ldx ok_f
        jsr getfk
        jsr t2f
        bcs @bad
        jsr isblank
        beq @pn
        inc ok_any
@pn:    ldx ok_f
        inx
        bne @pf
@pd:    lda ok_any
        bne @good
        lda #<al_empty
        ldy #>al_empty
        jsr alert
        jmp @full
@good:  clc
        rts
@bad:   sta ok_err
        lda ok_f
        sta ffoc
        jsr baderr
        jsr alert
        jmp @full

; baderr: message for t2f error ok_err in field ok_f -> A/Y alert
baderr: jsr mb_reset
        lda ok_err
        cmp #2
        beq @big
        cmp #3
        beq @date
        ldx ok_f                ; not a number
        lda fkind,x
        cmp #K_MONEY
        beq @bm
        lda #<s_bad1
        ldy #>s_bad1
        jsr mb_str
        jsr @name
        lda #<s_bad1b
        ldy #>s_bad1b
        jmp @fin
@bm:    lda #<s_bad1m
        ldy #>s_bad1m
        jsr mb_str
        jsr @name
        lda #<s_bad1c
        ldy #>s_bad1c
        jmp @fin
@big:   lda #<s_bad2
        ldy #>s_bad2
        jsr mb_str
        jsr @name
        lda #<s_bad2b
        ldy #>s_bad2b
        jsr mb_str
        ldx ok_f
        lda fkind,x
        cmp #K_MONEY
        beq @m2
        lda #<s_max1
        ldy #>s_max1
        jmp @fin
@m2:    lda #<s_max2
        ldy #>s_max2
        jmp @fin
@date:  lda #<s_bad3
        ldy #>s_bad3
        jsr mb_str
        jsr @name
        lda #<s_bad3b
        ldy #>s_bad3b
@fin:   jsr mb_str
        lda #<al_error
        ldy #>al_error
        rts
@name:  ldx ok_f
        jsr fnameptr
        jmp mb_fld

; ynget: the Yes/No choice of field ffoc: A = 0 blank, 1 Yes, 2 No
ynget:  ldx ffoc
        jsr etptr
        ldy #0
        lda (ptr2),y
        beq @d
        iny
        lda (ptr2),y
        cmp #'Y'
        beq @y
        lda #2
        rts
@y:     lda #1
@d:     rts

; ynset: A = 0/1/2 -> the text of field ffoc
ynset:  pha
        ldx ffoc
        jsr etptr
        pla
        ldy #0
        cmp #1
        beq @y
        cmp #2
        beq @n
        tya
        sta (ptr2),y
        rts
@y:     lda #3
        sta (ptr2),y
        ldx #0
@yl:    lda s_yes,x
        iny
        sta (ptr2),y
        inx
        cpx #3
        bne @yl
        rts
@n:     lda #2
        sta (ptr2),y
        iny
        lda #'N'
        sta (ptr2),y
        iny
        lda #'o'
        sta (ptr2),y
        rts

; ---------------------------------------------------------------
; Find
; ---------------------------------------------------------------
        .segment "RODATA"
t_find:   .byte "Find", 0
s_findl:  .byte "Find:", 0
s_findh:  .byte "Looks in every field of the list", 0
b_find:   .byte "Find", 0
s_nomatch: .byte "No record matches that text.", 0
al_nomatch: .word t_find, s_nomatch
            .byte 1
            .word b_ok
        .segment "CODE"

cmd_find:
@full:  jsr hidecursor
        lda #20
        sta wx
        lda #8
        sta wy
        lda #40
        sta ww
        lda #7
        sta wh
        lda #<t_find
        ldy #>t_find
        jsr drawwin
        POS 22, 11
        PRT s_findl
        POS 22, 13
        PRT s_findh
        POS 44, 15
        lda #<b_find
        ldy #>b_find
        ldx #1
        jsr drawbtn
        POS 51, 15
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jsr drawbtn
@fld:   jsr @setf
        lda #1
        jsr drawtf
@loop:  jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        beq @go
        cmp #$1B
        beq @x
        pha
        jsr @setf
        pla
        jsr tfkey
        bcc @loop
        jmp @fld
@mouse: lda mrow
        cmp #15
        bne @loop
        lda mcol
        cmp #44
        bcc @loop
        cmp #50
        bcc @go
        cmp #51
        bcc @loop
        cmp #59
        bcs @loop
@x:     lda #2
        sta redraw
        rts
@go:    lda #2
        sta redraw
        lda FINDSTR
        beq @x
        jmp dosearch
@setf:  lda #<FINDSTR
        sta ptr2
        lda #>FINDSTR
        sta ptr2+1
        lda #20
        sta tf_max
        lda #0
        sta tf_filt
        lda #28
        sta tf_col
        lda #11
        sta tf_row
        rts

cmd_findnext:
        lda FINDSTR
        bne dosearch
        jmp cmd_find

; dosearch: from sel+1, wrapping, for FINDSTR in any field
dosearch:
        lda #2
        sta redraw
        lda vcount
        beq @nf
        sta fs_n
        lda sel
        sta fs_i
        lda #0
        sta f2t_mode
@l:     inc fs_i
        lda fs_i
        cmp vcount
        bcc @c
        lda #0
        sta fs_i
@c:     ldx #0
@f:     cpx nfields
        bcs @nr
        stx fs_f
        ldx fs_i
        lda VIEW,x
        jsr recget
        ldx fs_f
        jsr getfk
        jsr f2t
        lda #<FINDSTR
        sta ptr3
        lda #>FINDSTR
        sta ptr3+1
        jsr instr
        bcs @found
        ldx fs_f
        inx
        bne @f
@nr:    dec fs_n
        bne @l
@nf:    lda #<al_nomatch
        ldy #>al_nomatch
        jmp alert
@found: lda fs_i
        sta sel
        rts

; instr: is the length-prefixed text at ptr3 inside TMPSTR
; (zero-terminated)?  Any case.  carry set = found
instr:  ldx #0
@len:   lda TMPSTR,x
        beq @g
        inx
        bne @len
@g:     stx is_hl
        ldy #0
        lda (ptr3),y
        sta is_nl
        beq @no
        lda is_hl
        sec
        sbc is_nl
        bcc @no
        sta is_last
        lda #0
        sta is_st
@outer: ldx #0
@inner: txa
        clc
        adc is_st
        tay
        lda TMPSTR,y
        jsr toupper
        sta is_c
        txa
        tay
        iny
        lda (ptr3),y
        jsr toupper
        cmp is_c
        bne @nx
        inx
        cpx is_nl
        bne @inner
        sec
        rts
@nx:    lda is_st
        cmp is_last
        beq @no
        inc is_st
        jmp @outer
@no:    clc
        rts

        .segment "XBSS"
EDITTXT:  .res MAXFIELDS*EDITW
        .segment "BSS"
EDITREC:  .res 256
ftitle:   .res 2
ffoc:     .res 1
fbrow:    .res 1
df_f:     .res 1
df_foc:   .res 1
df_i:     .res 1
rt_f:     .res 1
ok_f:     .res 1
ok_any:   .res 1
ok_err:   .res 1
fs_n:     .res 1
fs_i:     .res 1
fs_f:     .res 1
is_hl:    .res 1
is_nl:    .res 1
is_last:  .res 1
is_st:    .res 1
is_c:     .res 1
