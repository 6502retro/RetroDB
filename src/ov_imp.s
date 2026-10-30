; ---------------------------------------------------------------
; Overlay 1: import a CSV file (mc_path)
;
; Row 1 holds headings.  Into a database with a form, columns whose
; heading matches a field name (letters and digits, any case) are read
; into that field; into a database with no form yet, each heading makes
; a field, and the data in its column decides the field's type.
; Fields are separated by commas, semicolons or tabs (whichever the
; first line has most of), and may be in double quotes ("" is a quote).
; Lines end in CR, LF or CR LF.  Characters beyond plain ASCII become ?.
; ---------------------------------------------------------------
        .segment "OV1"
        jmp imp_csv

s_impq1:   .byte "Add the file's rows to this|"
           .byte "database, or replace its records|"
           .byte "with them? (Revert to Saved brings|"
           .byte "back the saved database.)", 0
s_impq2:   .byte "Import the file's rows into|"
           .byte "this database?", 0
s_impq3a:  .byte "Make a new database from this|"
           .byte "file? Its ", 0
s_impq3b:  .byte " columns become|fields, and its rows records.", 0
s_impok1:  .byte "Imported ", 0
s_impok2:  .byte " records.", 0
s_impover: .byte "|Some rows did not fit in memory.", 0
s_impok3:  .byte "||Choose Save to keep them.", 0
s_nomatch2: .byte "None of the headings in row 1 of|"
           .byte "that file match the fields of this|"
           .byte "database. Nothing was changed.", 0
s_nohead:  .byte "Row 1 of that file has no|"
           .byte "headings to make fields from.|"
           .byte "Nothing was changed.", 0
s_importing: .byte "Importing", G_DOTS, 0
b_add:     .byte "Add", 0
b_create:  .byte "Create", 0
al_impq1:   .word t_import, s_impq1
            .byte 3
            .word b_add, b_replace, b_cancel
al_impq2:   .word t_import, s_impq2
            .byte 2
            .word b_import, b_cancel
al_impq3:   .word t_import, MSGBUF
            .byte 2
            .word b_create, b_cancel
al_impmsg:  .word t_import, MSGBUF
            .byte 1
            .word b_ok
al_nomatch2: .word t_import, s_nomatch2
            .byte 1
            .word b_ok
al_nohead:  .word t_import, s_nohead
            .byte 1
            .word b_ok

imp_csv:
        lda #2
        sta redraw
        LDAY s_importing
        jsr statusmsg
        MLICALL $C8, mopen_p
        bcc @o
        jmp xerror
@o:     jsr msetrefs
        jsr csv_rewind
        jsr csv_sep             ; which separator?
        bcs @rderr
        jsr csv_rewind
        ; pass 1: the headings, and what kind of data each column holds
        lda #$FF
        ldx #63
@cm:    sta colmap,x
        dex
        bpl @cm
        lda #0
        sta dn
        ldx #MAXFIELDS-1
@zs:    sta im_text,x
        sta im_num,x
        sta im_money,x
        sta im_frac,x
        sta im_len,x
        sta im_notyn,x
        sta im_notdt,x
        dex
        bpl @zs
        lda nfields
        sta im_new              ; 0: make the form from the file
@p1:    jsr readcell
        bcs @p1d
        jsr scancell
        jmp @p1
@p1d:   lda cv_err
        bne @rderr
        ldx #63                 ; any column in use?
@fn:    lda colmap,x
        cmp #$FF
        bne @have
        dex
        bpl @fn
        MLICALL $CC, mclose_p
        LDAY al_nomatch2
        ldx im_new
        bne @nm
        LDAY al_nohead
@nm:    jmp alert
@rderr: pha
        MLICALL $CC, mclose_p
        pla
        jmp xerror
@have:  ; ask
        lda im_new
        bne @old
        jsr mb_reset            ; a new form
        LDAY s_impq3a
        jsr mb_str
        lda dn
        jsr mb_num8
        LDAY s_impq3b
        jsr mb_str
        LDAY al_impq3
        jsr alert
        cmp #0
        bne @cancel
        jsr newform
        lda #0
        sta im_base
        jmp @go
@old:   lda count
        bne @addq
        LDAY al_impq2
        jsr alert
        cmp #0
        bne @cancel
        lda #0
        sta im_base
        jmp @go
@addq:  LDAY al_impq1
        jsr alert
        cmp #2
        beq @cancel
        cmp #1
        beq @repl
        lda count               ; Add: after the last record
        sta im_base
        jmp @go
@repl:  lda #0
        sta im_base
        sta count
        jmp @go
@cancel:
        MLICALL $CC, mclose_p
        rts
@go:    ; pass 2: rewind and read the data
        jsr csv_rewind
        bcs @rderr2
        lda im_base
        sta im_hw
        lda #0
        sta ld_over
@p2:    jsr readcell
        bcs @p2d
        jsr storecell
        jmp @p2
@rderr2:
        pha
        MLICALL $CC, mclose_p
        pla
        jsr xerror
        jmp @fin
@p2d:   lda cv_over
        beq @p2c
        sta ld_over
@p2c:   MLICALL $CC, mclose_p
@fin:   lda im_hw
        sta count
        jsr compact
        jsr imp_nest
        jsr treeon
        bcc @ft
        jsr dotree
@ft:    lda #0
        sta selactive
        jsr showall
        lda #0
        sta sel
        sta top
        lda #1
        sta dirty
        ; report
        jsr mb_reset
        LDAY s_impok1
        jsr mb_str
        lda count
        sec
        sbc im_base
        jsr mb_num8
        LDAY s_impok2
        jsr mb_str
        lda ld_over
        beq @rep
        LDAY s_impover
        jsr mb_str
@rep:   LDAY s_impok3
        jsr mb_str
        jsr drawall
        LDAY al_impmsg
        jmp alert

; ---------------------------------------------------------------
; reading CSV
; ---------------------------------------------------------------
; csv_rewind: back to the start of the file.  Carry set on an error.
csv_rewind:
        lda #0
        sta mark_p+2
        sta mark_p+3
        sta mark_p+4
        sta ib_len
        sta ib_pos
        sta cv_eof
        sta cv_err
        sta cv_over
        sta cv_lf
        sta cv_pend
        lda mo_ref
        sta mark_p+1
        MLICALL $CE, mark_p
        bcs @d
        lda #1
        sta cv_row
        sta cv_col
        sta cv_bom
@d:     rts

; cget: the next character in A (CR LF and LF are both CR; a UTF-8 BOM
; at the start is skipped).  Carry set at the end of the file.
cget:   lda cv_pend             ; a character put back?
        beq @rd
        lda cv_pch
        ldx #0
        stx cv_pend
        clc
        rts
@rd:    jsr getbyte
        bcs @end
        ldx cv_bom              ; the start: EF BB BF?
        beq @nb
        ldx #0
        stx cv_bom
        cmp #$EF
        bne @nb
        jsr getbyte
        jsr getbyte
        jmp @rd
@nb:    ldx cv_lf               ; LF after CR: skip it
        beq @n
        ldx #0
        stx cv_lf
        cmp #$0A
        beq @rd
@n:     cmp #$0D
        bne @lf
        inc cv_lf
        clc
        rts
@lf:    cmp #$0A
        bne @ok
        lda #$0D
@ok:    clc
        rts
@end:   cmp #$4C
        beq @e
        sta cv_err
@e:     sec
        rts

; csv_sep: count commas, semicolons and tabs on the first line (outside
; quotes) -> cv_sep
csv_sep:
        lda #0
        sta cv_nc
        sta cv_ns
        sta cv_nt
        sta cv_q
@l:     jsr cget
        bcs @pick
        cmp #'"'
        bne @nq
        lda cv_q
        eor #1
        sta cv_q
        jmp @l
@nq:    ldx cv_q
        bne @l
        cmp #$0D
        beq @pick
        cmp #','
        bne @s
        inc cv_nc
        bne @l
@s:     cmp #';'
        bne @t
        inc cv_ns
        bne @l
@t:     cmp #$09
        bne @l
        inc cv_nt
        bne @l
        jmp @l
@pick:  lda #','
        ldx cv_nc
        cpx cv_ns
        bcs @c1
        lda #';'
        ldx cv_ns
@c1:    cpx cv_nt
        bcs @c2
        lda #$09
@c2:    sta cv_sep
        lda cv_err
        cmp #1                  ; carry set if reading failed
        rts

; readcell: the next cell that has something in it -> c_r (row, 1 =
; headings), c_c (column, 1-63) and TMPSTR.  Carry set at the end.
readcell:
@next:  lda cv_eof
        beq @rd
        sec
        rts
@rd:    lda cv_row
        sta c_r
        lda cv_col
        sta c_c
        jsr rdfield             ; A = 0 separator, 1 end of line, 2 end
        cmp #1
        beq @eol
        bcs @eof
        inc cv_col
        bne @got
        dec cv_col
        jmp @got
@eol:   lda #1
        sta cv_col
        inc cv_row
        bne @got
        inc cv_eof              ; row 256: stop here
        inc cv_over
        jmp @got
@eof:   inc cv_eof
@got:   jsr trimtmp
        lda TMPSTR
        beq @next
        lda c_c
        cmp #64
        bcs @next
        clc
        rts

; rdfield: one field -> TMPSTR; A = what ended it (0 separator, 1 end
; of line, 2 end of file)
rdfield:
        lda #0
        sta cv_len
        sta TMPSTR
        jsr cget
        bcs @eof
        cmp #'"'
        bne @plain
@q:     jsr cget                ; quoted
        bcs @eof
        cmp #'"'
        bne @qa
        jsr cget                ; "" is a quote; " then anything ends it
        bcs @eof
        cmp #'"'
        beq @qa
        jmp @plain
@qa:    cmp #$0D                ; a line break inside quotes: a space
        bne @qb
        lda #' '
@qb:    jsr cv_add
        jmp @q
@pl:    jsr cget
        bcs @eof
@plain: cmp cv_sep
        beq @sep
        cmp #$0D
        beq @eol
        jsr cv_add
        jmp @pl
@sep:   lda #0
        rts
@eol:   lda #1
        rts
@eof:   lda #2
        rts

; cv_add: A -> the end of TMPSTR (up to 70 characters)
cv_add: cmp #$80
        bcc @a
        cmp #$C0                ; UTF-8: one ? per character
        bcc @d
        lda #'?'
@a:     cmp #$09
        bne @b
        lda #' '
@b:     cmp #' '
        bcc @d
        cmp #$7F
        bcs @d
        cmp #'"'                ; (quotes can't go in a database file)
        bne @c
        lda #$27
@c:     ldx cv_len
        cpx #70
        bcs @d
        sta TMPSTR,x
        inx
        stx cv_len
        lda #0
        sta TMPSTR,x
@d:     rts

; ---------------------------------------------------------------
; scancell: pass 1.  Row-1 headings choose the columns; data cells
; tell a new form what kind each field is.
; ---------------------------------------------------------------
scancell:
        lda c_r
        cmp #1
        jeq @head
        lda im_new
        bne @d
        ldx c_c                 ; statistics for a new field
        lda colmap,x
        cmp #$FF
        beq @d
        sta im_x
        jsr eurofix
        jsr isnumt              ; a number?
        bcc @num
        ldx #0                  ; text: how long?
@ln:    lda TMPSTR,x
        beq @lg
        inx
        bne @ln
@lg:    txa
        ldx im_x
        cmp im_len,x
        bcc @lt
        sta im_len,x
@lt:    lda #1
        sta im_text,x
        jsr isyn                ; all Yes/No?  all dates?
        bcc @yn
        ldx im_x
        lda #1
        sta im_notyn,x
@yn:    jsr parsedate
        bcc @d
        ldx im_x
        lda #1
        sta im_notdt,x
@d:     rts
@num:   ldx im_x
        inc im_num,x
        bne @nn
        dec im_num,x
@nn:    lda in_dol
        beq @fr
        lda #1
        sta im_money,x
@fr:    lda in_dot
        beq @nl0
        lda #1
        sta im_frac,x
@nl0:   ldy #0                  ; as text, how long?
@nl:    lda TMPSTR,y
        beq @ng
        iny
        bne @nl
@ng:    tya
        cmp im_len,x
        bcc @nd
        sta im_len,x
@nd:    rts
@head:  lda TMPSTR
        beq @d
        lda im_new
        beq @newf
        jsr keytmp              ; match a field name
        ldx #0
@mf:    cpx nfields
        bcs @d
        stx im_x
        jsr fnameptr
        jsr fld2tmp2            ; the field name's key in TMP2
        jsr keycmp
        beq @hit
        ldx im_x
        inx
        bne @mf
@hit:   ldx c_c
        lda im_x
        sta colmap,x
        rts
@newf:  lda dn                  ; a new field, if there's room
        cmp #MAXFIELDS
        jcs @d
        ldx #0                  ; not the same name as another one
@dn:    cpx dn
        bcs @add
        stx im_x
        jsr dnptr
        jsr dkeytmp2
        jsr cpkeytmp
        jsr keycmp
        jeq @d
        ldx im_x
        inx
        bne @dn
@add:   ldx dn
        jsr dnptr               ; the name, cleaned up
        ldx #0
        ldy #0
@nc:    lda TMPSTR,x
        beq @ne
        cpy #MAXNAME
        bcs @ne
        cmp #'|'
        bne @n2
        lda #'/'
@n2:    iny
        sta (ptr2),y
        inx
        bne @nc
@ne:    tya
        ldy #0
        sta (ptr2),y
        ldx c_c
        lda dn
        sta colmap,x
        inc dn
        rts

; isnumt: is TMPSTR a number: [+-][$]digits and commas[.digits]?
; carry clear = yes; in_dol = it had a $, in_dot = it had a point
; eurofix: in a file separated by semicolons, a number like 1.234,50
; has its periods and commas the other way round: swap them in TMPSTR
; (if it holds only digits, $ + - . and ,)
eurofix:
        lda cv_sep
        cmp #';'
        bne @d
        ldx #0
@ck:    lda TMPSTR,x
        beq @sw
        cmp #'0'
        bcc @o
        cmp #'9'+1
        bcc @nx
        rts
@o:     cmp #'$'
        beq @nx
        cmp #'+'
        bcc @d
        cmp #'.'+1              ; + , - .
        bcs @d
@nx:    inx
        bne @ck
@d:     rts
@sw:    ldx #0
@sl:    lda TMPSTR,x
        beq @d
        cmp #'.'
        bne @c
        lda #','
        bne @st
@c:     cmp #','
        bne @n
        lda #'.'
@st:    sta TMPSTR,x
@n:     inx
        bne @sl
        rts

isnumt: lda #0
        sta in_dol
        sta in_dot
        sta in_dig
        ldx #0
        lda TMPSTR
        cmp #'-'
        beq @s
        cmp #'+'
        bne @l
@s:     inx
@l:     lda TMPSTR,x
        beq @end
        cmp #'$'
        bne @c
        lda in_dig              ; only before the digits
        ora in_dot
        bne @no
        inc in_dol
        bne @n
@c:     cmp #','
        bne @p
        lda in_dot
        bne @no
        beq @n
@p:     cmp #'.'
        bne @dg
        lda in_dot
        bne @no
        inc in_dot
        bne @n
@dg:    cmp #'0'
        bcc @no
        cmp #'9'+1
        bcs @no
        inc in_dig
@n:     inx
        bne @l
@end:   lda in_dig
        beq @no
        clc
        rts
@no:    sec
        rts

; isyn: is TMPSTR Yes, No, Y, N, True or False (any case)?  carry clear = yes
isyn:   ldx #0
@up:    lda TMPSTR,x
        jsr toupper
        sta TMP2,x
        cmp #0
        beq @go
        inx
        cpx #6
        bcc @up
        bcs @no                 ; too long
@go:    ldy #0
@word:  ldx #0
@c:     lda s_ynw,y
        beq @no                 ; end of the list
        cmp #' '
        beq @end
        cmp TMP2,x
        bne @skip
        iny
        inx
        bne @c
@end:   lda TMP2,x              ; the word ended: did the text?
        beq @yes
        iny
        jmp @word
@skip:  iny                     ; to the next word
        lda s_ynw,y
        cmp #' '
        bne @skip
        iny
        jmp @word
@yes:   clc
        rts
@no:    sec
        rts

s_ynw:  .byte "YES NO Y N TRUE FALSE ", 0

; keytmp: TMPSTR -> its letters and digits, in capitals (in place)
keytmp: ldx #0
        ldy #0
@n:     lda TMPSTR,x
        beq @z
        jsr toupper
        cmp #'0'
        bcc @nn
        cmp #'9'+1
        bcc @k
        cmp #'A'
        bcc @nn
        cmp #'Z'+1
        bcs @nn
@k:     sta TMPSTR,y
        iny
@nn:    inx
        bne @n
@z:     sta TMPSTR,y
        rts

; fld2tmp2: length-prefixed name at ptr1 -> its key in TMP2
fld2tmp2:
        ldy #0
        lda (ptr1),y
        sta t0
        ldx #0
@l:     cpy t0
        beq @z
        iny
        lda (ptr1),y
        jsr toupper
        cmp #'0'
        bcc @l
        cmp #'9'+1
        bcc @k
        cmp #'A'
        bcc @l
        cmp #'Z'+1
        bcs @l
@k:     sta TMP2,x
        inx
        bne @l
@z:     lda #0
        sta TMP2,x
        rts

; dkeytmp2: the name at ptr2 -> its key in TMP2
dkeytmp2:
        lda ptr2
        sta ptr1
        lda ptr2+1
        sta ptr1+1
        jmp fld2tmp2

; cpkeytmp: the key of TMPSTR (a heading) -> TMPSTR (keytmp, on a copy)
cpkeytmp:
        ldx #0
@c:     lda TMPSTR,x
        sta IMHEAD,x
        beq @k
        inx
        bne @c
@k:     jsr keytmp
        rts

; keycmp: Z set if the keys in TMPSTR and TMP2 are the same.
; (cpkeytmp's copy of the heading is put back in TMPSTR afterwards.)
keycmp: ldx #0
@l:     lda TMPSTR,x
        cmp TMP2,x
        bne @ne
        cmp #0
        beq @eq
        inx
        bne @l
@eq:    jsr @back
        lda #0
        rts
@ne:    jsr @back
        lda #1
        rts
@back:  lda im_new              ; a new form: heading text back
        bne @r
        ldx #0
@b:     lda IMHEAD,x
        sta TMPSTR,x
        beq @r
        inx
        bne @b
@r:     rts

; newform: make the form from the headings found in pass 1
newform:
        ldx #0
@f:     cpx dn
        bcs @size
        lda #1
        sta dlist,x
        lda #$FF
        sta dsrc,x
        lda im_text,x
        beq @nt
        lda #K_DATE             ; text: every entry a date?  Yes/No?
        ldy im_notdt,x
        beq @k
        lda #K_YESNO
        ldy im_notyn,x
        beq @k
        lda #K_TEXT
        bne @k
@nt:    lda #K_TEXT
        ldy im_num,x
        beq @k
        lda #K_NUMBER
        ldy im_money,x
        bne @mon
        ldy im_frac,x
        beq @k
@mon:   lda #K_MONEY
@k:     sta dkind,x
        lda im_len,x            ; Text: the longest entry, and room for
        clc                     ; ten more characters
        adc #10
        cmp #MAXTEXT+1
        bcc @l2
        lda #MAXTEXT
@l2:    stx im_x
        jsr dsetlen
        ldx im_x
        inx
        bne @f
@size:  jsr nestkinds           ; "No." and "Part Of" columns
        jsr dsize               ; too long?  shorten the longest Text
        bcs @shrink
        cmp #MAXRECSZ
        bcc @ok
        beq @ok
@shrink:
        lda #0
        sta im_w
        lda #$FF
        sta im_x
        ldx #0
@sl:    cpx dn
        bcs @sd
        lda dkind,x
        cmp #K_TEXT
        bne @sn
        stx t4
        jsr dlenval
        ldx t4
        cmp im_w
        bcc @sn
        beq @sn
        sta im_w
        stx im_x
@sn:    inx
        bne @sl
@sd:    ldx im_x
        cpx #$FF
        beq @ok                 ; (can't happen: 16 fields fit)
        lda im_w
        sec
        sbc #1
        jsr dsetlen
        jmp @size
@ok:    jmp dapply

; storecell: pass 2: put a data cell into its record
storecell:
        lda c_r
        cmp #2
        bcc @d
        ldx c_c
        lda colmap,x
        cmp #$FF
        beq @d
        sta sc_f
        lda c_r                 ; record im_base + row - 2
        sec
        sbc #2
        clc
        adc im_base
        bcs @over
        cmp maxrec
        bcc @in
@over:  lda #1
        sta ld_over
@d:     rts
@in:    sta sc_i
@init:  lda im_hw               ; make blank records up to this one
        cmp sc_i
        beq @blk
        bcs @put
@blk:   jsr recgetw
        jsr blankrec
        jsr recput
        inc im_hw
        jmp @init
@put:   lda sc_i
        ldx sc_f
        jsr recgetf
        ldx sc_f
        jsr getfk
        lda fk_k
        cmp #K_NUMBER
        beq @eu
        cmp #K_MONEY
        bne @t2f
@eu:    jsr eurofix
@t2f:   jsr t2f
        bcc @ok
        jsr fblank
@ok:    jmp recput

; blankrec: every field of record rp blank
blankrec:
        ldx #0
@l:     cpx nfields
        bcs @d
        stx br_x
        jsr getfk
        jsr fblank
        ldx br_x
        inx
        bne @l
@d:     rts

; compact: from im_base on, drop records that are blank, keeping the
; rest in the file's order
compact:
        lda im_base
        sta cp_o
        sta cp_i
@l:     lda cp_i
        cmp count
        bcs @d
        jsr recget
        jsr recblank
        bcs @n
        ldx cp_i                ; swap slot cp_i into position cp_o
        ldy cp_o
        lda PTRLO,x
        pha
        lda PTRLO,y
        sta PTRLO,x
        pla
        sta PTRLO,y
        lda PTRHI,x
        pha
        lda PTRHI,y
        sta PTRHI,x
        pla
        sta PTRHI,y
        lda PTRBK,x
        pha
        lda PTRBK,y
        sta PTRBK,x
        pla
        sta PTRBK,y
        inc cp_o
@n:     inc cp_i
        bne @l
@d:     lda cp_o
        sta count
        rts

; recblank: carry set if every field of record rp is blank
recblank:
        ldx #0
@l:     cpx nfields
        bcs @y
        jsr getfk
        jsr isblank
        bne @no
        inx
        bne @l
@y:     sec
        rts
@no:    clc
        rts

        .segment "OV1BSS"
c_r:     .res 1
c_c:     .res 1
im_new:  .res 1
im_hw:   .res 1
im_x:    .res 1
im_w:    .res 1
im_text: .res MAXFIELDS
im_num:  .res MAXFIELDS
im_money: .res MAXFIELDS
im_frac: .res MAXFIELDS
im_len:  .res MAXFIELDS
im_notyn: .res MAXFIELDS
im_notdt: .res MAXFIELDS
IMHEAD:  .res 72
sc_f:    .res 1
sc_i:    .res 1
br_x:    .res 1
cp_o:    .res 1
cp_i:    .res 1
cv_row:  .res 1
cv_col:  .res 1
cv_eof:  .res 1
cv_err:  .res 1
cv_over: .res 1
cv_lf:   .res 1
cv_bom:  .res 1
cv_pend: .res 1
cv_pch:  .res 1
cv_sep:  .res 1
cv_len:  .res 1
cv_nc:   .res 1
cv_ns:   .res 1
cv_nt:   .res 1
cv_q:    .res 1
in_dol:  .res 1
in_dot:  .res 1
in_dig:  .res 1
