; ---------------------------------------------------------------
; The form: field tables, and converting fields to and from text.
;
; A field's value is stored in its kind's own way (see defs.inc).
; f2t turns the field at rp into text in TMPSTR; t2f parses TMPSTR into
; the field.  Both take the field in fk_k (kind), fk_o (offset in the
; record) and fk_l (length, for Text); getfk loads them for field X.
; ---------------------------------------------------------------
        .segment "CODE"

; getfk: X = field -> fk_k, fk_o, fk_l  (X is kept)
getfk:  lda fkind,x
        sta fk_k
        lda foff,x
        sta fk_o
        lda flen,x
        sta fk_l
        rts

; kindsize: A = kind, X = Text length -> A = bytes in the record
kindsize:
        cmp #K_TEXT
        bne @n
        inx
        txa
        dex
        rts
@n:     tay
        lda ksize,y
        rts

; kindwidth: A = kind, X = Text length -> A = width on screen
kindwidth:
        cmp #K_TEXT
        bne @n
        txa
        rts
@n:     tay
        lda kwidth,y
        rts

        .segment "RODATA"
;              -  Text Num Money Date Y/N
ksize:  .byte  0, 0,   4,  4,    11,  1
kwidth: .byte  0, 0,   10, 12,   10,  3
kn1:    .byte "Text", 0
kn2:    .byte "Number", 0
kn3:    .byte "Money", 0
kn4:    .byte "Date", 0
kn5:    .byte "Yes/No", 0
knlo:   .byte <kn1, <kn1, <kn2, <kn3, <kn4, <kn5
knhi:   .byte >kn1, >kn1, >kn2, >kn3, >kn4, >kn5
s_yes:  .byte "Yes", 0
s_no:   .byte "No", 0
        .segment "CODE"

; kindname: A = kind -> A/Y name
kindname:
        cmp #NKINDS+1
        bcc @ok
        lda #K_TEXT
@ok:    tax
        lda knlo,x
        ldy knhi,x
        rts

; fdsetup: offsets, sizes and the record size for the current form.
; Carry set if the record would be longer than MAXRECSZ.
fdsetup:
        lda #0
        sta fd_tot
        sta fd_tot+1
        ldx #0
@l:     cpx nfields
        bcs @d
        lda fd_tot
        sta foff,x
        lda fkind,x
        stx fd_x
        pha
        lda flen,x
        tax
        pla
        jsr kindsize
        ldx fd_x
        sta fsize,x
        clc
        adc fd_tot
        sta fd_tot
        bcc @n
        inc fd_tot+1
@n:     inx
        bne @l
@d:     lda fd_tot
        sta recsize
        lda fd_tot+1
        bne @big
        clc
        rts
@big:   lda #MAXRECSZ
        sta recsize
        sec
        rts

; fnameptr: X = field -> ptr1 = its name (length-prefixed, 16 bytes)
fnameptr:
        txa
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<fname
        sta ptr1
        lda #>fname
        adc #0
        sta ptr1+1
        rts

; ---------------------------------------------------------------
; field -> text
; ---------------------------------------------------------------
; f2t: field fk_* of record rp -> TMPSTR (zero-terminated), A = length.
; f2t_mode 0 = for showing ($ on money), 1 = plain (files, editing)
f2t:    lda #0
        sta f2_n
        lda fk_k
        cmp #K_NUMBER
        beq @num
        cmp #K_MONEY
        beq @num
        cmp #K_YESNO
        beq @yn
        ldy fk_o                ; Text and Date: copy
        lda (rp),y
        sta t0
        beq @end
@cp:    iny
        lda (rp),y
        jsr f2_put
        dec t0
        bne @cp
        jmp @end
@yn:    ldy fk_o
        lda (rp),y
        cmp #1
        bne @y2
        LDAY s_yes
        jmp @str
@y2:    cmp #2
        bne @end
        LDAY s_no
@str:   jsr f2_zstr
        jmp @end
@num:   jsr fld2num
        bcs @end                ; blank
        lda fn_neg
        beq @pos
        lda #'-'
        jsr f2_put
@pos:   lda fk_k
        cmp #K_MONEY
        beq @mon
        jsr fmtnum
        LDAY numbuf
        jmp @str
@mon:   jsr fmtmoney0           ; "$d.cc"
        LDAY moneybuf
        ldx f2t_mode
        beq @str
        LDAY moneybuf+1
        jmp @str
@end:   ldx f2_n
        lda #0
        sta TMPSTR,x
        txa
        rts

f2_put: ldx f2_n
        cpx #70
        bcs @d
        sta TMPSTR,x
        inc f2_n
@d:     rts

f2_zstr:
        sta ptr3
        sty ptr3+1
        ldy #0
@l:     lda (ptr3),y
        beq @d
        jsr f2_put
        iny
        bne @l
@d:     rts

; fld2num: the Number/Money field fk_o of rp -> num = magnitude,
; fn_neg = 1 if negative.  Carry set (num = 0) if the field is blank.
fld2num:
        ldy fk_o
        lda (rp),y
        sta num
        iny
        lda (rp),y
        sta num+1
        iny
        lda (rp),y
        sta num+2
        iny
        lda (rp),y
        sta num+3
        lda #0
        sta num+4
        sta fn_neg
        lda num+3
        bpl @pos
        cmp #BLANKHI
        bne @neg
        lda num
        ora num+1
        ora num+2
        bne @neg
        jsr zeronum
        sec
        rts
@neg:   lda #$FF                ; sign-extend, then negate
        sta num+4
        jsr negnum
        lda #1
        sta fn_neg
@pos:   clc
        rts

; negnum: num = -num (40 bits)
negnum: ldx #0
        sec
@l:     lda #0
        sbc num,x
        sta num,x
        inx
        cpx #5
        bne @l
        rts

; isblank: is field fk_* of rp blank?  Z set = blank
isblank:
        ldy fk_o
        lda fk_k
        cmp #K_NUMBER
        beq @n
        cmp #K_MONEY
        beq @n
        lda (rp),y              ; Text/Date length, or Yes/No code
        rts
@n:     iny
        iny
        iny
        lda (rp),y
        cmp #BLANKHI
        bne @d
        dey
        lda (rp),y
        dey
        ora (rp),y
        dey
        ora (rp),y
@d:     rts

; fblank: make field fk_* of rp blank
fblank: ldy fk_o
        lda #0
        sta (rp),y
        lda fk_k
        cmp #K_NUMBER
        beq @n
        cmp #K_MONEY
        bne @d
@n:     lda #0
        iny
        sta (rp),y
        iny
        sta (rp),y
        iny
        lda #BLANKHI
        sta (rp),y
@d:     rts

; ---------------------------------------------------------------
; text -> field
; ---------------------------------------------------------------
; t2f: TMPSTR -> field fk_* of rp.  Spaces at either end are dropped.
; Carry set if the text doesn't fit the kind (the field is left
; unchanged): A = 1 not a number, 2 too large, 3 not a date, 4 not Yes/No
t2f:    jsr trimtmp
        lda fk_k
        cmp #K_NUMBER
        jeq @num
        cmp #K_MONEY
        jeq @mon
        cmp #K_DATE
        jeq @date
        cmp #K_YESNO
        jeq @yn
        ; Text: copy, quotes become apostrophes, control characters go
        ldx #0
        ldy fk_o
@t:     lda TMPSTR,x
        beq @td
        and #$7F
        cmp #$20
        bcc @tn
        cmp #'"'
        bne @tq
        lda #$27
@tq:    sty t1
        pha
        tya
        sec
        sbc fk_o
        cmp fk_l
        pla
        bcs @td
        iny
        sta (rp),y
@tn:    inx
        bne @t
@td:    tya
        sec
        sbc fk_o
        ldy fk_o
        sta (rp),y
        clc
        rts
@yn:    lda TMPSTR
        beq @ys
        jsr toupper
        ldx #1
        cmp #'Y'
        beq @ys2
        cmp #'T'
        beq @ys2
        cmp #'1'
        beq @ys2
        inx
        cmp #'N'
        beq @ys2
        cmp #'F'
        beq @ys2
        cmp #'0'
        beq @ys2
        lda #4
        sec
        rts
@ys:    ldx #0
@ys2:   txa
        ldy fk_o
        sta (rp),y
        clc
        rts
@num:   lda TMPSTR
        jeq @blank
        jsr signtmp             ; sptr = digits, fn_neg
        jsr zeronum
        ldy #0
        sty t4                  ; digits seen
@nd:    lda (sptr),y
        beq @nend
        cmp #','
        beq @nn
        cmp #'0'
        bcc @bad1
        cmp #'9'+1
        bcs @bad1
        sec
        sbc #'0'
        sta pm_d
        lda num+3
        ora num+4
        bne @big                ; far too many digits
        sty pm_y
        jsr mul10
        lda pm_d
        jsr addnum8
        ldy pm_y
        inc t4
@nn:    iny
        bne @nd
@nend:  lda t4
        beq @bad1
        jsr capval
        bcs @big
        jmp @store
@bad1:  lda #1
        sec
        rts
@big:   lda #2
        sec
        rts
@mon:   lda TMPSTR
        beq @blank
        jsr signtmp
        ldy #0                  ; at least one digit, nothing odd
@md:    lda (sptr),y
        beq @mok
        cmp #'0'
        bcc @mc
        cmp #'9'+1
        bcc @mdig
@mc:    cmp #'.'
        beq @mnx
        cmp #','
        beq @mnx
        cmp #'$'
        beq @mnx
        cmp #'E'
        beq @mnx
        cmp #'e'
        beq @mnx
        cmp #'+'
        beq @mnx
        cmp #'-'
        beq @mnx
        bne @bad1
@mdig:  inc t4
@mnx:   iny
        bne @md
@mok:   lda t4
        beq @bad1
        jsr parsemoney
        bcs @big
        jmp @store
@blank: jsr fblank
        clc
        rts
@store: lda fn_neg              ; num (positive) -> signed 32 bits
        beq @sp
        lda num
        ora num+1
        ora num+2
        ora num+3
        beq @sp                 ; -0 is 0
        jsr negnum
@sp:    ldy fk_o
        lda num
        sta (rp),y
        iny
        lda num+1
        sta (rp),y
        iny
        lda num+2
        sta (rp),y
        iny
        lda num+3
        sta (rp),y
        clc
        rts
@date:  lda TMPSTR
        beq @blank
        jsr parsedate
        bcc @dok
        lda #3
        rts
@dok:   ldy fk_o                ; TMP2 (length-prefixed) -> field
        ldx #0
@dc:    lda TMP2,x
        sta (rp),y
        iny
        inx
        cpx #11
        bne @dc
        clc
        rts

; signtmp: sptr = TMPSTR after a leading "$", "-" or "-$"; fn_neg
signtmp:
        lda #0
        sta fn_neg
        sta t4
        ldx #0
@l:     lda TMPSTR,x
        cmp #'-'
        beq @m
        cmp #'$'
        beq @s
        cmp #' '
        bne @d
@s:     inx
        bne @l
@m:     inc fn_neg
        inx
        bne @l
@d:     txa
        clc
        adc #<TMPSTR
        sta sptr
        lda #>TMPSTR
        adc #0
        sta sptr+1
        rts

; trimtmp: drop spaces at both ends of TMPSTR
trimtmp:
        ldx #0
@l:     lda TMPSTR,x
        cmp #' '
        bne @g
        inx
        bne @l
@g:     ldy #0
@c:     lda TMPSTR,x
        sta TMPSTR,y
        beq @e
        inx
        iny
        bne @c
@e:     dey
        bmi @d
        lda TMPSTR,y
        cmp #' '
        bne @d
        lda #0
        sta TMPSTR,y
        beq @e
@d:     rts

; parsedate: TMPSTR -> TMP2 as YYYY, YYYY-MM or YYYY-MM-DD
; (length-prefixed).  Reads YYYY-MM-DD, YYYY/MM/DD, MM/DD/YYYY,
; M/D/YYYY, MM/YYYY and YYYY.  Carry set if it isn't a date.
parsedate:
        lda #0
        sta pd_g
        ldx #2
@z:     sta pd_v,x
        sta pd_vh,x
        sta pd_n,x
        dex
        bpl @z
        ldx #0
@l:     lda TMPSTR,x
        jeq @end
        cmp #'-'
        beq @sep
        cmp #'/'
        beq @sep
        cmp #'.'
        beq @sep
        cmp #'0'
        bcc @bad
        cmp #'9'+1
        bcs @bad
        and #$0F
        sta pd_d
        ldy pd_g
        lda pd_n,y
        cmp #4
        bcs @bad                ; more than four digits
        lda pd_n,y
        clc
        adc #1
        sta pd_n,y
        lda pd_v,y              ; v = v*10 + d (16 bits)
        sta t0
        lda pd_vh,y
        sta t1
        asl t0
        rol t1
        lda t0
        sta t2
        lda t1
        sta t3
        asl t0
        rol t1
        asl t0
        rol t1
        clc
        lda t0
        adc t2
        sta t0
        lda t1
        adc t3
        sta t1
        clc
        lda t0
        adc pd_d
        sta pd_v,y
        lda t1
        adc #0
        sta pd_vh,y
        inx
        bne @l
@sep:   ldy pd_g
        lda pd_n,y
        beq @bad                ; empty group
        cpy #2
        bcs @bad                ; more than three groups
        inc pd_g
        inx
        jne @l
@bad:   sec
        rts
@end:   ldy pd_g
        lda pd_n,y
        beq @bad
        lda #$FF
        sta pd_y
        sta pd_m
        sta pd_dd
        cpy #0
        bne @g2
        ldx #0                  ; YYYY
        jsr @isyear
        bcs @bad
        jmp @chk
@g2:    cpy #1
        bne @g3
        ldx #0                  ; YYYY-MM or MM/YYYY
        lda pd_n
        cmp #4
        bne @g2b
        jsr @isyear
        lda pd_v+1
        sta pd_m
        lda pd_n+1
        jmp @mlen
@g2b:   ldx #1
        jsr @isyear
        bcs @bad
        lda pd_v
        sta pd_m
        lda pd_n
@mlen:  cmp #3
        bcs @bad
        jmp @chk
@g3:    ldx #0                  ; YYYY-MM-DD or MM/DD/YYYY
        lda pd_n
        cmp #4
        bne @g3b
        jsr @isyear
        lda pd_v+1
        sta pd_m
        lda pd_v+2
        sta pd_dd
        lda pd_n+1
        cmp #3
        jcs @bad2
        lda pd_n+2
        cmp #3
        jcs @bad2
        jmp @chk
@g3b:   ldx #2
        jsr @isyear
        bcs @bad2
        lda pd_v
        sta pd_m
        lda pd_v+1
        sta pd_dd
        lda pd_n
        cmp #3
        bcs @bad2
        lda pd_n+1
        cmp #3
        bcs @bad2
@chk:   lda pd_y                ; year must have been found
        cmp #$FF
        beq @bad2
        lda pd_m
        cmp #$FF
        beq @out
        cmp #1
        bcc @bad2
        cmp #13
        bcs @bad2
        lda pd_dd
        cmp #$FF
        beq @out
        cmp #1
        bcc @bad2
        cmp #32
        bcs @bad2
@out:   ldx #0                  ; build the text in TMP2
        lda pd_yv
        sta num
        lda pd_yv+1
        sta num+1
        lda #0
        sta num+2
        sta num+3
        sta num+4
        jsr fmtnum
@oy:    lda numbuf,x
        sta TMP2+1,x
        inx
        cpx #4
        bne @oy
        lda pd_m
        cmp #$FF
        beq @olen
        jsr @two
        lda pd_dd
        cmp #$FF
        beq @olen
        jsr @two
@olen:  stx TMP2
        clc
        rts
@bad2:  sec
        rts
; @two: "-" and A as two digits at TMP2+1+X
@two:   pha
        lda #'-'
        sta TMP2+1,x
        inx
        pla
        ldy #'0'
@tl:    cmp #10
        bcc @tg
        sbc #10
        iny
        bne @tl
@tg:    pha
        tya
        sta TMP2+1,x
        inx
        pla
        ora #'0'
        sta TMP2+1,x
        inx
        rts
; @isyear: group X is a four-digit year 1000-2999?  carry clear = yes
@isyear:
        lda pd_n,x
        cmp #4
        bne @ny
        lda pd_vh,x             ; 1000 = $03E8, 2999 = $0BB7
        cmp #>1000
        bcc @ny
        bne @y1
        lda pd_v,x
        cmp #<1000
        bcc @ny
@y1:    lda pd_vh,x
        cmp #>2999
        bcc @yy
        bne @ny
        lda pd_v,x
        cmp #<(2999+1)
        bcs @ny
@yy:    lda pd_v,x
        sta pd_yv
        lda pd_vh,x
        sta pd_yv+1
        lda #0
        sta pd_y
        clc
        rts
@ny:    sec
        rts

; ---------------------------------------------------------------
; comparing (sorting)
; ---------------------------------------------------------------
; fless: carry set if field fk_* of rp2 sorts before that of rp.
; Blank fields come first.
fless:  lda rp
        sta rq
        lda rp+1
        sta rq+1
        jsr isblank             ; rp blank?
        php
        lda rp2
        sta rp
        lda rp2+1
        sta rp+1
        jsr isblank             ; rp2 blank?
        php
        lda rq
        sta rp
        lda rq+1
        sta rp+1
        pla
        and #2
        sta fl_b2               ; Z bit of rp2
        pla
        and #2                  ; Z bit of rp
        bne @rpb
        lda fl_b2               ; rp has a value
        bne @yes                ; rp2 blank: before
        beq @cmp
@rpb:   clc                     ; rp blank: nothing is before it
        rts
@yes:   sec
        rts
@cmp:   lda fk_k
        cmp #K_NUMBER
        beq @num
        cmp #K_MONEY
        beq @num
        cmp #K_YESNO
        beq @yn
        clc                     ; Text/Date: ptr1 = rp2 field, ptr2 = rp
        lda rp2
        adc fk_o
        sta ptr1
        lda rp2+1
        adc #0
        sta ptr1+1
        clc
        lda rp
        adc fk_o
        sta ptr2
        lda rp+1
        adc #0
        sta ptr2+1
        jmp strless
@yn:    ldy fk_o                ; Yes before No
        lda (rp2),y
        cmp (rp),y
        bcs @no
        sec
        rts
@no:    clc
        rts
@num:   ldy fk_o                ; signed: rp2 < rp ?
        sec
        lda (rp2),y
        sbc (rp),y
        iny
        lda (rp2),y
        sbc (rp),y
        iny
        lda (rp2),y
        sbc (rp),y
        iny
        lda (rp2),y
        sbc (rp),y
        bvc @nv
        eor #$80
@nv:    asl a                   ; carry = sign = (rp2 < rp)
        rts

        .segment "BSS"
nfields:  .res 1
recsize:  .res 1
fkind:    .res MAXFIELDS
flen:     .res MAXFIELDS
fsize:    .res MAXFIELDS
foff:     .res MAXFIELDS
flist:    .res MAXFIELDS
fname:    .res MAXFIELDS*16
fk_k:     .res 1
fk_o:     .res 1
fk_l:     .res 1
f2t_mode: .res 1
f2_n:     .res 1
fn_neg:   .res 1
fd_tot:   .res 2
fd_x:     .res 1
fl_b2:    .res 1
pd_g:     .res 1
pd_d:     .res 1
pd_v:     .res 3
pd_vh:    .res 3
pd_n:     .res 3
pd_y:     .res 1
pd_yv:    .res 2
pd_m:     .res 1
pd_dd:    .res 1
