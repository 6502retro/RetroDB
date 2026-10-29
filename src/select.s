; ---------------------------------------------------------------
; Select Records (the PFS Search): a criterion for any field; the list
; then shows only the records that match every one.
;
;   text      the field contains it (a Date starts with it; a Number,
;             Money or Yes/No field equals it)
;   =text     equals            =      is blank
;   <x  >x  <=x  >=x  <>x       compared with x (numbers by value,
;                               text alphabetically, dates by date)
;   a..b      from a to b (either end may be left out)
;   /x        not: any of the above turned around ( /  is not blank)
; ---------------------------------------------------------------
OP_DEF   = 0
OP_EQ    = 1
OP_LT    = 2
OP_GT    = 3
OP_LE    = 4
OP_GE    = 5
OP_NE    = 6
OP_RANGE = 7
OP_BLANK = 8

        .segment "RODATA"
ctlo:
.repeat MAXFIELDS, I
        .byte <(CRITTXT + I * CRITW)
.endrepeat
cthi:
.repeat MAXFIELDS, I
        .byte >(CRITTXT + I * CRITW)
.endrepeat
; which comparison results each operator accepts (1 less, 2 equal, 4 more)
opmask: .byte 2, 2, 1, 4, 3, 6, 5     ; by operator: -, =, <, >, <=, >=, <>
t_select: .byte "Select Records", 0
s_selh1: .byte "Show only the records whose fields match:", 0
s_selh2: .byte "text  =exact  <10  >=1984  1..9  /not  = blank", 0
b_select: .byte "Select", 0
b_showall: .byte "Show All", 0
s_nonesel: .byte "No records match. Choose Show All|"
           .byte "Records from the View menu to see|"
           .byte "them all again.", 0
al_nonesel: .word t_select, s_nonesel
           .byte 1
           .word b_ok
        .segment "CODE"

; ctptr: X = field -> ptr2 = its criterion
ctptr:  lda ctlo,x
        sta ptr2
        lda cthi,x
        sta ptr2+1
        rts

clearcrit:
        ldx #MAXFIELDS-1
@l:     jsr ctptr
        lda #0
        tay
        sta (ptr2),y
        dex
        bpl @l
        rts

cmd_showall:
        lda #2
        sta redraw
        lda #0
        sta selactive
        jsr showall
        lda #0
        sta sel
        sta top
        rts

; ---------------------------------------------------------------
; the dialog
; ---------------------------------------------------------------
drawsel:
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
        lda #<t_select
        ldy #>t_select
        jsr drawwin
        POS FL_LCOL, 4
        PRT s_selh1
        ldx #0
@f:     stx df_i
        jsr drawcfld
        ldx df_i
        inx
        cpx nfields
        bne @f
        lda #4
        sta cx
        lda fbrow
        sta cy
        dec cy
        PRT s_selh2
        lda fbrow
        sta cy
        lda #50
        sta cx
        lda #<b_select
        ldy #>b_select
        ldx #1
        jsr drawbtn
        lda #59
        sta cx
        lda #<b_showall
        ldy #>b_showall
        ldx #0
        jsr drawbtn
        lda #70
        sta cx
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jmp drawbtn

; drawcfld: X = field
drawcfld:
        stx df_f
        txa
        clc
        adc #5
        sta cy
        sta tf_row
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
        jsr csetf
        lda df_foc
        jmp drawtf

; csetf: X = field -> text box registers for its criterion
csetf:  jsr ctptr
        lda #MAXCRIT
        sta tf_max
        lda #0
        sta tf_filt
        lda #FL_VCOL
        sta tf_col
        txa
        clc
        adc #5
        sta tf_row
        rts

cmd_select:
        lda #2
        sta redraw
        lda nfields
        bne @go
        rts
@go:    lda #0
        sta ffoc
@full:  jsr hidecursor
        jsr drawsel
@loop:  jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        jeq @ok
        cmp #$1B
        bne @k2
        rts
@k2:    cmp #$09
        beq @next
        cmp #$0A
        beq @next
        cmp #$0B
        beq @prev
        ldx ffoc
        jsr csetf
        lda keych
        jsr tfkey
        bcc @loop
        ldx ffoc
        jsr drawcfld
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
        jsr drawcfld
        ldx ffoc
        jsr drawcfld
        jmp @loop
@mouse: lda mrow
        cmp fbrow
        bne @fhit
        lda mcol
        cmp #50
        bcc @loop
        cmp #58
        bcc @ok
        cmp #59
        bcc @loop
        cmp #69
        bcc @all
        cmp #70
        jcc @loop
        cmp #78
        jcs @loop
        rts
@all:   jsr clearcrit
        jmp cmd_showall
@fhit:  sec
        sbc #5
        jcc @loop
        cmp nfields
        jcs @loop
        tax
        jmp @setf
@ok:    ; any criteria at all?
        ldx #0
@any:   cpx nfields
        bcs @none
        jsr ctptr
        ldy #0
        lda (ptr2),y
        bne @some
        inx
        bne @any
@none:  jmp cmd_showall
@some:  lda #1
        sta selactive
        lda #<s_selecting
        ldy #>s_selecting
        jsr statusmsg
        jsr selectview
        lda #0
        sta sel
        sta top
        lda vcount
        bne @x
        jsr drawall
        lda #<al_nonesel
        ldy #>al_nonesel
        jmp alert
@x:     rts

        .segment "RODATA"
s_selecting: .byte "Selecting", G_DOTS, 0
        .segment "CODE"

; selectview: VIEW = the records that match the criteria
selectview:
        lda #0
        sta vcount
        sta sv_r
@l:     lda sv_r
        cmp count
        bcs @d
        jsr recget
        jsr recmatch
        bcc @n
        ldx vcount
        lda sv_r
        sta VIEW,x
        inc vcount
@n:     inc sv_r
        bne @l
@d:     rts

; ---------------------------------------------------------------
; matching
; ---------------------------------------------------------------
; recmatch: does record rp match every criterion?  carry set = yes
recmatch:
        lda rp
        sta rm_rp
        lda rp+1
        sta rm_rp+1
        lda #0
        sta rm_f
@f:     ldx rm_f
        cpx nfields
        bcs @yes
        jsr ctptr
        ldy #0
        lda (ptr2),y
        beq @n
        jsr fldmatch
        bcc @no
@n:     inc rm_f
        bne @f
@yes:   sec
        rts
@no:    clc
        rts

; rm_back: rp = the record again
rm_back:
        lda rm_rp
        sta rp
        lda rm_rp+1
        sta rp+1
        rts

; fldmatch: field rm_f of the record against its criterion.
; carry set = matches
fldmatch:
        ldx rm_f
        jsr getfk
        ; the criterion -> OPLO (zero-terminated), trimmed
        ldx rm_f
        jsr ctptr
        ldy #0
        lda (ptr2),y
        tax
        lda #0
        sta OPLO,x
@cp:    txa
        beq @cpd
        tay
        lda (ptr2),y
        sta OPLO-1,x
        dex
        jmp @cp
@cpd:   jsr optrim
        lda #0
        sta cm_neg
        lda OPLO
        cmp #'/'
        bne @op
        inc cm_neg
        jsr opshift
        jsr optrim
@op:    ; which operator?
        lda #OP_BLANK
        ldx OPLO
        beq @gotop              ; "/" alone: not blank
        cpx #'='
        bne @o1
        ldx OPLO+1
        beq @gotop              ; "=" alone: blank
        lda #OP_EQ
        ldx #1
        jmp @strip
@o1:    cpx #'<'
        bne @o2
        lda OPLO+1
        ldx #2
        cmp #'='
        beq @le
        cmp #'>'
        beq @ne
        lda #OP_LT
        ldx #1
        jmp @strip
@le:    lda #OP_LE
        jmp @strip
@ne:    lda #OP_NE
        jmp @strip
@o2:    cpx #'>'
        bne @o3
        lda OPLO+1
        ldx #2
        cmp #'='
        beq @ge
        lda #OP_GT
        ldx #1
        jmp @strip
@ge:    lda #OP_GE
        jmp @strip
@o3:    jsr findrange           ; "a..b"?
        bcc @def
        lda #OP_RANGE
        bne @gotop
@def:   lda #OP_DEF
        beq @gotop
@strip: sta cm_op               ; drop the X operator characters
@sx:    jsr opshift
        dex
        bne @sx
        jsr optrim
        lda cm_op
@gotop: sta cm_op
        ; blank tests
        jsr rm_back
        jsr isblank
        php
        lda cm_op
        cmp #OP_BLANK
        bne @nb
        plp
        beq @t                  ; blank: true
        bne @f
@nb:    plp
        beq @f                  ; a blank field matches nothing else
        ; the default operator for each kind
        lda cm_op
        bne @cmp
        lda fk_k
        cmp #K_TEXT
        beq @cont
        cmp #K_DATE
        beq @pref
        lda #OP_EQ
        sta cm_op
@cmp:   jsr prepops             ; operands ready (carry set: unusable)
        bcs @f
        lda cm_op
        cmp #OP_RANGE
        beq @range
        lda OPLO                ; nothing to compare with
        beq @f
        ldx #0
        jsr critcmp
        ldx cm_op
        lda opmask,x
        and cm_res
        bne @t
        beq @f
@range: lda OPLO                ; v >= lo (unless lo is empty)
        beq @r2
        ldx #0
        jsr critcmp
        lda cm_res
        and #6
        beq @f
@r2:    lda OPHI
        beq @t
        ldx #1
        jsr critcmp
        lda cm_res
        and #3
        beq @f
@t:     lda cm_neg
        bne @no
@yes:   sec
        rts
@f:     lda cm_neg
        bne @yes
@no:    clc
        rts
@cont:  jsr rm_back             ; Text: contains
        lda #1
        sta f2t_mode
        jsr f2t
        jsr opisin
        bcs @t
        bcc @f
@pref:  jsr prepops             ; Date: starts with
        bcs @f
        jsr rm_back
        lda #1
        sta f2t_mode
        jsr f2t
        ldx #0
@pl:    lda OPLO,x
        beq @t
        cmp TMPSTR,x
        bne @f
        inx
        bne @pl
        beq @t

; opshift: drop the first character of OPLO (X is kept)
opshift:
        ldy #0
@l:     lda OPLO+1,y
        sta OPLO,y
        beq @d
        iny
        bne @l
@d:     rts

; optrim: drop spaces at both ends of OPLO
optrim: lda OPLO
        cmp #' '
        bne @e
        jsr opshift
        jmp optrim
@e:     ldy #0
@len:   lda OPLO,y
        beq @g
        iny
        bne @len
@g:     dey
        bmi @d
        lda OPLO,y
        cmp #' '
        bne @d
        lda #0
        sta OPLO,y
        beq @g
@d:     rts

; findrange: OPLO "a..b" -> OPLO = a, OPHI = b.  carry set if found
findrange:
        ldx #0
@l:     lda OPLO,x
        beq @no
        cmp #'.'
        bne @n
        lda OPLO+1,x
        cmp #'.'
        beq @y
@n:     inx
        bne @l
@no:    lda #0
        sta OPHI
        clc
        rts
@y:     lda #0
        sta OPLO,x
        ldy #0
@c:     lda OPLO+2,x
        sta OPHI,y
        beq @t
        inx
        iny
        bne @c
@t:     jsr optrim              ; trim both
        ldx #0
@tl:    lda OPHI,x              ; (OPHI: leading spaces)
        cmp #' '
        bne @td
        inx
        bne @tl
@td:    ldy #0
@tc:    lda OPHI,x
        sta OPHI,y
        beq @te
        inx
        iny
        bne @tc
@te:    sec
        rts

; prepops: get the operands ready for comparing with this kind.
; Number/Money: OPV1/OPV2 = the values; Date: OPLO/OPHI as dates;
; Yes/No: OPV1 = the code.  Carry set if an operand can't be used.
prepops:
        lda cm_op
        cmp #OP_RANGE
        beq @two
        lda #0
        sta OPHI
@two:   lda fk_k
        cmp #K_NUMBER
        beq @num
        cmp #K_MONEY
        beq @num
        cmp #K_DATE
        jeq @date
        cmp #K_YESNO
        beq @yn
        clc
        rts
@yn:    jsr toupper1
        ldx #1
        cmp #'Y'
        beq @ys
        inx
        cmp #'N'
        beq @ys
        sec
        rts
@ys:    stx OPV1
        clc
        rts
@num:   lda #<OPLO
        ldy #>OPLO
        ldx #0
        jsr @pnum
        bcs @d
        lda #<OPHI
        ldy #>OPHI
        ldx #4
@pnum:  sta ptr3                ; operand text -> OPV1+X (4 bytes)
        sty ptr3+1
        stx pp_x
        ldy #0
        lda (ptr3),y
        bne @pc
        clc                     ; empty (one end of a range)
        rts
@pc:    ldy #0
@pcl:   lda (ptr3),y
        sta TMPSTR,y
        beq @pcd
        iny
        bne @pcl
@pcd:   lda fk_o
        pha
        lda #0
        sta fk_o
        clc
        lda #<OPV1
        adc pp_x
        sta rp
        lda #>OPV1
        adc #0
        sta rp+1
        jsr t2f
        pla
        sta fk_o
        php
        jsr rm_back
        plp
        bcs @d
        ldx pp_x                ; a blank operand can't be compared
        lda OPV1+3,x
        cmp #BLANKHI
        bne @ok
        lda OPV1,x
        ora OPV1+1,x
        ora OPV1+2,x
        bne @ok
        sec
        rts
@ok:    clc
@d:     rts
@date:  lda #<OPLO
        ldy #>OPLO
        jsr @pdate
        lda #<OPHI
        ldy #>OPHI
@pdate: sta ptr3                ; a date operand in another style
        sty ptr3+1              ; becomes YYYY-MM-DD
        ldy #0
        lda (ptr3),y
        beq @dd
@dc:    lda (ptr3),y
        sta TMPSTR,y
        beq @dp
        iny
        bne @dc
@dp:    jsr parsedate
        bcs @dd                 ; not a date: compared as typed
        ldx TMP2
        ldy #0
@dl:    lda TMP2+1,y
        sta (ptr3),y
        iny
        dex
        bne @dl
        lda #0
        sta (ptr3),y
@dd:    clc
        rts

toupper1:
        lda OPLO
        jmp toupper

; critcmp: compare the field with operand X (0 OPLO/OPV1, 1 OPHI/OPV2)
; -> cm_res = 1 less, 2 equal, 4 more
critcmp:
        stx cc_k
        lda fk_k
        cmp #K_NUMBER
        beq @num
        cmp #K_MONEY
        beq @num
        cmp #K_YESNO
        beq @yn
        jsr rm_back             ; Text and Date: as text, any case
        lda #1
        sta f2t_mode
        jsr f2t
        lda #<OPLO
        ldy #>OPLO
        ldx cc_k
        beq @t
        lda #<OPHI
        ldy #>OPHI
@t:     sta ptr3
        sty ptr3+1
        ldy #0
@tl:    lda TMPSTR,y
        jsr toupper
        sta t0
        lda (ptr3),y
        jsr toupper
        cmp t0
        bne @tne
        cmp #0
        beq @eq
        iny
        bne @tl
@tne:   bcc @less               ; operand < value: value is more
        bcs @more0
@more0: lda #1                  ; value < operand
        bne @set
@less:  lda #4
        bne @set
@eq:    lda #2
@set:   sta cm_res
        rts
@yn:    jsr rm_back
        ldy fk_o
        lda (rp),y
        cmp OPV1
        beq @eq
        bcc @lt
        lda #4
        bne @set
@lt:    lda #1
        bne @set
@num:   jsr rm_back             ; signed 32-bit: value - operand
        lda cc_k
        asl a
        asl a
        tax
        ldy fk_o
        lda (rp),y
        cmp OPV1,x
        bne @nd
        iny
        lda (rp),y
        cmp OPV1+1,x
        bne @nd
        iny
        lda (rp),y
        cmp OPV1+2,x
        bne @nd
        iny
        lda (rp),y
        cmp OPV1+3,x
        beq @eq
@nd:    ldy fk_o
        sec
        lda (rp),y
        sbc OPV1,x
        iny
        lda (rp),y
        sbc OPV1+1,x
        iny
        lda (rp),y
        sbc OPV1+2,x
        iny
        lda (rp),y
        sbc OPV1+3,x
        bvc @nv
        eor #$80
@nv:    bmi @lt
        lda #4
        bne @set

; opisin: is OPLO inside TMPSTR (any case)?  carry set = yes
opisin: ldx #0
@l:     lda OPLO,x
        sta OPNEED+1,x
        beq @g
        inx
        bne @l
@g:     stx OPNEED
        lda #<OPNEED
        sta ptr3
        lda #>OPNEED
        sta ptr3+1
        jmp instr

        .segment "BSS"
CRITTXT:  .res MAXFIELDS*CRITW
OPLO:     .res 34
OPHI:     .res 34
OPV1:     .res 4
OPV2:     .res 4
OPNEED:   .res 36
rm_rp:    .res 2
rm_f:     .res 1
cm_neg:   .res 1
cm_op:    .res 1
cm_res:   .res 1
cc_k:     .res 1
pp_x:     .res 1
sv_r:     .res 1
