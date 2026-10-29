; ---------------------------------------------------------------
; Nesting: record numbers and Part Of links.
;
; A form may have one No. field (K_NO) and one Part Of field
; (K_PARTOF).  Both hold a 2-byte number, 0 = blank.  MouseDB gives
; every record a No. from 1 to 999 that it keeps for good; Part Of
; holds the No. of the record this one is inside, to any depth.
;
; NOLO/NOHI cache each record's No. (by record index) so a Part Of can
; be turned into the parent's name quickly.  The cache is rebuilt when
; it is needed after anything that moves records (notab_inval).
;
; Sort > By Part Of puts the records in tree order: each record is
; followed by the records inside it, and DEPTH holds how deep each one
; is, for indenting the list.
; ---------------------------------------------------------------
MAXNO   = 999
TR_IND  = 2             ; indent per level in the list
TR_MAXD = 10            ; deepest indent shown

        .segment "CODE"

; nestf: nf_no, nf_po = the No. and Part Of fields ($FF none);
; nf_nm = the field that names a record (the first Text field)
nestf:  lda #$FF
        sta nf_no
        sta nf_po
        sta nf_nm
        ldx #0
@l:     cpx nfields
        bcs @d
        lda fkind,x
        cmp #K_NO
        bne @p
        ldy nf_no
        iny
        bne @n
        stx nf_no
@p:     cmp #K_PARTOF
        bne @t
        ldy nf_po
        iny
        bne @n
        stx nf_po
@t:     cmp #K_TEXT
        bne @n
        ldy nf_nm
        iny
        bne @n
        stx nf_nm
@n:     inx
        bne @l
@d:     jmp notab_inval

; fixkinds: the kinds at (rq), X of them: one No. at most, one Part Of
; at most, and a Part Of only with a No.; any others become Number
fixkinds:
        stx fx_n
        lda #0
        sta fx_no
        sta fx_po
        ldy #0
@l:     cpy fx_n
        bcs @p2
        lda (rq),y
        cmp #K_NO
        bne @n
        lda fx_no
        beq @k
        lda #K_NUMBER
        sta (rq),y
        bne @n
@k:     inc fx_no
@n:     iny
        bne @l
@p2:    ldy #0
@l2:    cpy fx_n
        bcs @d
        lda (rq),y
        cmp #K_PARTOF
        bne @n2
        lda fx_no
        beq @num
        lda fx_po
        bne @num
        inc fx_po
        bne @n2
@num:   lda #K_NUMBER
        sta (rq),y
@n2:    iny
        bne @l2
@d:     rts

; treeon: carry set if the list is in Part Of (tree) order
treeon: ldx sortkey
        cpx #$FF
        beq @no
        lda fkind,x
        cmp #K_PARTOF
        bne @no
        sec
        rts
@no:    clc
        rts

; ---------------------------------------------------------------
; reading a field without disturbing rp or the record caches
; ---------------------------------------------------------------
; peekfld: A = record index, X = field -> PBUF (that field's bytes)
peekfld:
        tay
        lda fsize,x
        sta pk_len
        clc
        lda PTRLO,y
        adc foff,x
        sta A1L
        lda PTRHI,y
        adc #0
        sta A1L+1
        lda PTRBK,y
        bne @aux
        ldy #0
@l:     cpy pk_len
        beq @d
        lda (A1L),y
        sta PBUF,y
        iny
        bne @l
@d:     rts
@aux:   lda #<PBUF
        sta A4L
        lda #>PBUF
        sta A4L+1
        clc
        lda A1L
        adc pk_len
        sta A2L
        lda A1L+1
        adc #0
        sta A2L+1
        lda A2L
        bne @a
        dec A2L+1
@a:     dec A2L
        clc
        jmp auxmv

; getno / getpo: A = record index -> pk_v = its No. / Part Of (0 if none)
getno:  ldx nf_no
        jmp getv
getpo:  ldx nf_po
getv:   cpx #$FF
        beq @z
        jsr peekfld
        lda PBUF
        sta pk_v
        lda PBUF+1
        sta pk_v+1
        rts
@z:     lda #0
        sta pk_v
        sta pk_v+1
        rts

; pokev: A = record index, X = field, pk_v -> that field (saved)
pokev:  stx pv_f
        ldx pv_f
        jsr recgetf
        ldx pv_f
        ldy foff,x
        lda pk_v
        sta (rp),y
        iny
        lda pk_v+1
        sta (rp),y
        jmp recput

; ---------------------------------------------------------------
; the number cache
; ---------------------------------------------------------------
notab_inval:
        lda #0
        sta notab_ok
        rts

notab_build:
        lda notab_ok
        bne @d
        lda #0
        sta nb_i
@l:     lda nb_i
        cmp count
        bcs @ok
        jsr getno
        ldx nb_i
        lda pk_v
        sta NOLO,x
        lda pk_v+1
        sta NOHI,x
        inc nb_i
        bne @l
@ok:    lda #1
        sta notab_ok
@d:     rts

; findno: fn_v = a No. -> carry clear and A = its record, or carry set
findno: lda fn_v
        ora fn_v+1
        beq @no
        jsr notab_build
        ldx #0
@l:     cpx count
        bcs @no
        lda NOLO,x
        cmp fn_v
        bne @n
        lda NOHI,x
        cmp fn_v+1
        beq @y
@n:     inx
        bne @l
@no:    sec
        rts
@y:     txa
        clc
        rts

; nextno: fn_v = a No. no record has (one more than the largest, or
; the smallest free one once 999 is taken)
nextno: jsr notab_build
        lda #0
        sta fn_v
        sta fn_v+1
        ldx #0
@m:     cpx count
        bcs @md
        lda NOHI,x
        cmp fn_v+1
        bcc @mn
        bne @mb
        lda NOLO,x
        cmp fn_v
        bcc @mn
@mb:    lda NOLO,x
        sta fn_v
        lda NOHI,x
        sta fn_v+1
@mn:    inx
        bne @m
@md:    lda fn_v+1              ; max < 999: max + 1
        cmp #>MAXNO
        bcc @inc
        bne @free
        lda fn_v
        cmp #<MAXNO
        bcs @free
@inc:   inc fn_v
        bne @d
        inc fn_v+1
@d:     rts
@free:  jsr bm_clear            ; the smallest number not in use
        ldx #0
@b:     cpx count
        bcs @s
        lda NOLO,x
        sta fn_v
        lda NOHI,x
        sta fn_v+1
        stx nb_i
        jsr bm_set
        ldx nb_i
        inx
        bne @b
@s:     lda #1
        sta fn_v
        lda #0
        sta fn_v+1
@sl:    jsr bm_test
        beq @d
        inc fn_v
        bne @sl
        inc fn_v+1
        bne @sl

; bitmap of numbers in use (fn_v)
bm_clear:
        lda #0
        ldx #127
@l:     sta NOMAP,x
        dex
        bpl @l
        rts
; bm_pos: X = byte, A = bit mask of fn_v (fn_v 1-999); carry set if out
bm_pos: lda fn_v+1
        cmp #4
        bcs @d
        lda fn_v
        sta t0
        lda fn_v+1
        lsr a
        ror t0
        lsr a
        ror t0
        lsr a
        ror t0
        ldx t0
        lda fn_v
        and #7
        tay
        lda bm_bits,y
        clc
@d:     rts
bm_set: jsr bm_pos
        bcs @d
        ora NOMAP,x
        sta NOMAP,x
@d:     rts
; bm_test: Z clear if fn_v is in use (or out of range)
bm_test:
        jsr bm_pos
        bcs @out
        and NOMAP,x
        rts
@out:   lda #1
        rts

        .segment "RODATA"
bm_bits: .byte 1, 2, 4, 8, 16, 32, 64, 128
        .segment "CODE"

; numberfix: every record a No. of its own: blanks, numbers out of
; range and repeats get new ones.  dirty is set if anything changed.
numberfix:
        lda nf_no
        cmp #$FF
        jeq @d
        jsr bm_clear
        lda #0
        sta nx_i
        sta nx_max
        sta nx_max+1
@p1:    lda nx_i
        cmp count
        bcs @p2
        jsr getno
        lda pk_v
        sta fn_v
        lda pk_v+1
        sta fn_v+1
        ora fn_v
        beq @bad
        lda fn_v+1              ; over 999?
        cmp #>MAXNO
        bcc @in
        bne @bad
        lda fn_v
        cmp #<(MAXNO+1)
        bcs @bad
@in:    jsr bm_test
        bne @bad
        jsr bm_set
        lda fn_v+1              ; the largest so far
        cmp nx_max+1
        bcc @n1
        bne @mx
        lda fn_v
        cmp nx_max
        bcc @n1
@mx:    lda fn_v
        sta nx_max
        lda fn_v+1
        sta nx_max+1
        jmp @n1
@bad:   lda #0                  ; blank it; pass 2 gives it a number
        sta pk_v
        sta pk_v+1
        lda nx_i
        ldx nf_no
        jsr pokev
@n1:    inc nx_i
        bne @p1
@p2:    lda #0
        sta nx_i
@p2l:   lda nx_i
        cmp count
        bcs @done
        jsr getno
        lda pk_v
        ora pk_v+1
        bne @n2
        jsr nx_new
        lda fn_v
        sta pk_v
        lda fn_v+1
        sta pk_v+1
        lda nx_i
        ldx nf_no
        jsr pokev
        lda #1
        sta dirty
@n2:    inc nx_i
        bne @p2l
@done:  jmp notab_inval
@d:     rts
; nx_new: fn_v = a free number (nx_max + 1, or the smallest free)
nx_new: lda nx_max+1
        cmp #>MAXNO
        bcc @inc
        bne @free
        lda nx_max
        cmp #<MAXNO
        bcs @free
@inc:   inc nx_max
        bne @c
        inc nx_max+1
@c:     lda nx_max
        sta fn_v
        lda nx_max+1
        sta fn_v+1
        jmp bm_set
@free:  lda #1
        sta fn_v
        lda #0
        sta fn_v+1
@l:     jsr bm_test
        beq @got
        inc fn_v
        bne @l
        inc fn_v+1
        bne @l
@got:   jmp bm_set

; unlink: a Part Of that names no record (or the record itself) is
; cleared; used after records are deleted
unlink: lda nf_po
        cmp #$FF
        beq @d
        jsr notab_inval
        lda #0
        sta nx_i
@l:     lda nx_i
        cmp count
        bcs @x
        jsr getpo
        lda pk_v
        ora pk_v+1
        beq @n
        lda pk_v
        sta fn_v
        lda pk_v+1
        sta fn_v+1
        jsr findno
        bcs @clr
        cmp nx_i
        bne @n
@clr:   lda #0
        sta pk_v
        sta pk_v+1
        lda nx_i
        ldx nf_po
        jsr pokev
@n:     inc nx_i
        bne @l
@x:     jmp notab_inval
@d:     rts

; kids: A = record -> A = how many records are directly inside it
kids:   sta kd_r
        lda #0
        sta kd_n
        lda nf_po
        cmp #$FF
        beq @d
        lda kd_r
        jsr getno
        lda pk_v
        sta kd_v
        lda pk_v+1
        sta kd_v+1
        ora kd_v
        beq @d
        lda #0
        sta nx_i
@l:     lda nx_i
        cmp count
        bcs @d
        jsr getpo
        lda pk_v
        cmp kd_v
        bne @n
        lda pk_v+1
        cmp kd_v+1
        bne @n
        inc kd_n
@n:     inc nx_i
        bne @l
@d:     lda kd_n
        rts

; assignno: the record at rp gets a new No. if its No. is blank
assignno:
        ldx nf_no
        cpx #$FF
        beq @d
        ldy foff,x
        lda (rp),y
        iny
        ora (rp),y
        bne @d
        lda rp                  ; (nextno doesn't use rp)
        pha
        lda rp+1
        pha
        jsr nextno
        pla
        sta rp+1
        pla
        sta rp
        ldx nf_no
        ldy foff,x
        lda fn_v
        sta (rp),y
        iny
        lda fn_v+1
        sta (rp),y
@d:     rts

; isinside: is No. fn_v the record with No. in_self, or inside it?
; carry set = yes (or a loop was found)
isinside:
        lda #0
        sta in_n
@l:     lda fn_v
        ora fn_v+1
        beq @no
        lda fn_v
        cmp in_self
        bne @up
        lda fn_v+1
        cmp in_self+1
        beq @yes
@up:    jsr findno
        bcs @no
        jsr getpo
        lda pk_v
        sta fn_v
        lda pk_v+1
        sta fn_v+1
        inc in_n
        lda in_n
        cmp #MAXREC
        bcc @l
@yes:   sec
        rts
@no:    clc
        rts

; ---------------------------------------------------------------
; names
; ---------------------------------------------------------------
; pname: A = record -> TMPSTR = its name (its first Text field, or
; "No. n" when that is blank)
pname:  sta pn_r
        ldx nf_nm
        cpx #$FF
        beq @num
        jsr peekfld
        ldx PBUF
        beq @num
        cpx #60
        bcc @c
        ldx #60
@c:     lda #0
        sta TMPSTR,x
@cl:    lda PBUF,x
        sta TMPSTR-1,x
        dex
        bne @cl
        rts
@num:   lda pn_r
        jsr getno
        lda pk_v
        sta fn_v
        lda pk_v+1
        sta fn_v+1
        ldx #0
        jmp nonum

; nonum: TMPSTR+X = "No. " fn_v (zero-terminated)
nonum:  ldy #0
@p:     lda s_nodot,y
        beq @n
        sta TMPSTR,x
        inx
        iny
        bne @p
@n:     stx nn_x
        jsr v2num
        jsr fmtnum
        ldx nn_x
        ldy #0
@c:     lda numbuf,y
        sta TMPSTR,x
        beq @d
        inx
        iny
        bne @c
@d:     rts

; v2num: num = fn_v
v2num:  lda fn_v
        sta num
        lda fn_v+1
        sta num+1
        lda #0
        sta num+2
        sta num+3
        sta num+4
        rts

        .segment "RODATA"
s_nodot: .byte "No. ", 0
        .segment "CODE"

; f2t_nest: f2t for No. and Part Of fields (fk_*, rp) -> TMPSTR
; (f2_n characters so far).  A Part Of is shown as the name of the
; record it is inside, except in plain mode.
f2t_nest:
        ldy fk_o
        lda (rp),y
        sta fn_v
        iny
        lda (rp),y
        sta fn_v+1
        ora fn_v
        beq @end
        lda fk_k
        cmp #K_PARTOF
        bne @num
        lda f2t_mode
        bne @num
        lda rp                  ; the parent's name
        pha
        lda rp+1
        pha
        jsr findno
        bcs @miss
        jsr pname
        jmp @back
@miss:  ldx #0                  ; no such record: "No. n?"
        jsr nonum
        lda #'?'
        sta TMPSTR,x
        inx
        lda #0
        sta TMPSTR,x
@back:  pla
        sta rp+1
        pla
        sta rp
        ldx #0
@ln:    lda TMPSTR,x
        beq @lend
        inx
        bne @ln
@lend:  stx f2_n
        txa
        rts
@num:   jsr v2num
        jsr fmtnum
        ldx #0
@c:     lda numbuf,x
        sta TMPSTR,x
        beq @e
        inx
        bne @c
@e:     stx f2_n
        txa
        rts
@end:   lda #0
        sta TMPSTR
        sta f2_n
        rts

; t2f_nest: TMPSTR -> No./Part Of field.  Blank is 0; otherwise a
; number from 1 to 999 (a leading "No." or "#" is allowed).
t2f_nest:
        ldx #0
@sk:    lda TMPSTR,x            ; skip "No.", "#" and spaces
        jeq @blank
        jsr toupper
        cmp #'N'
        beq @s
        cmp #'O'
        beq @s
        cmp #'.'
        beq @s
        cmp #'#'
        beq @s
        cmp #' '
        bne @dig
@s:     inx
        bne @sk
@dig:   lda #0
        sta fn_v
        sta fn_v+1
@dl:    lda TMPSTR,x
        beq @got
        cmp #','
        beq @dn
        cmp #'0'
        jcc @bad
        cmp #'9'+1
        jcs @bad
        and #$0F
        sta t1
        lda fn_v+1              ; too big already?
        cmp #4
        bcs @big
        lda fn_v                ; fn_v = fn_v * 10 + digit
        sta t2
        lda fn_v+1
        sta t3
        asl t2                  ; *2
        rol t3
        lda t2
        sta fn_v
        lda t3
        sta fn_v+1
        asl t2                  ; *8
        rol t3
        asl t2
        rol t3
        clc
        lda t2
        adc fn_v
        sta fn_v
        lda t3
        adc fn_v+1
        sta fn_v+1
        clc
        lda fn_v
        adc t1
        sta fn_v
        bcc @dn
        inc fn_v+1
@dn:    inx
        bne @dl
@got:   lda fn_v
        ora fn_v+1
        beq @blank
        lda fn_v+1
        cmp #>MAXNO
        bcc @st
        bne @big
        lda fn_v
        cmp #<(MAXNO+1)
        bcs @big
@st:    ldy fk_o
        lda fn_v
        sta (rp),y
        iny
        lda fn_v+1
        sta (rp),y
        clc
        rts
@blank: ldy fk_o
        lda #0
        sta (rp),y
        iny
        sta (rp),y
        clc
        rts
@bad:   lda #1
        sec
        rts
@big:   lda #2
        sec
        rts

; ---------------------------------------------------------------
; tree order (Sort > By Part Of)
; ---------------------------------------------------------------
TRORD   = LINEBUF       ; new order: old record indexes
TRTMP   = INBUF         ; table copy while permuting
TRPAR   = CELLBUF       ; each record's parent (record index, $FF none)

dotree: lda nf_no
        cmp #$FF
        beq @x
        lda nf_po
        cmp #$FF
        bne @go
@x:     rts
@go:    jsr notab_inval
        jsr notab_build
        lda #0
        sta tr_i
@pl:    lda tr_i                ; parents, and DEPTH = unplaced
        cmp count
        bcs @pd
        tax
        lda #$FF
        sta DEPTH,x
        sta TRPAR,x
        txa
        jsr getpo
        lda pk_v
        sta fn_v
        lda pk_v+1
        sta fn_v+1
        jsr findno
        bcs @pn
        cmp tr_i
        beq @pn
        ldx tr_i
        sta TRPAR,x
@pn:    inc tr_i
        bne @pl
@pd:    lda #0
        sta tr_k
        sta tr_i                ; roots first, in the present order
@rl:    lda tr_i
        cmp count
        bcs @rd
        tax
        lda TRPAR,x
        and DEPTH,x
        cmp #$FF
        bne @rn
        txa
        jsr tr_root
@rn:    inc tr_i
        bne @rl
@rd:    lda #0                  ; then any caught in a loop
        sta tr_i
@cl:    lda tr_i
        cmp count
        bcs @perm
        tax
        lda DEPTH,x
        cmp #$FF
        bne @cn
        txa
        jsr tr_root
@cn:    inc tr_i
        bne @cl
@perm:  LDAY PTRLO
        jsr tr_perm
        LDAY PTRHI
        jsr tr_perm
        LDAY PTRBK
        jsr tr_perm
        LDAY DEPTH
        jsr tr_perm
        jmp notab_inval

; tr_root: A = a record placed at depth 0, then everything inside it
tr_root:
        sta tr_r
        sta tr_cur
        tax
        lda #0
        sta DEPTH,x
        txa
        jsr tr_emit
        lda #0
        sta tr_pos
@find:  ldx tr_pos              ; the next unplaced child of tr_cur
@f:     cpx count
        bcs @up
        lda TRPAR,x
        cmp tr_cur
        bne @fn
        lda DEPTH,x
        cmp #$FF
        beq @got
@fn:    inx
        bne @f
@got:   stx tr_j
        ldy tr_cur
        lda DEPTH,y
        cmp #$FE
        bcs @dp
        adc #1
@dp:    sta DEPTH,x
        txa
        jsr tr_emit
        lda tr_j
        sta tr_cur
        lda #0
        sta tr_pos
        jmp @find
@up:    lda tr_cur              ; no more: back up to the parent
        cmp tr_r
        beq @d
        tax
        inx
        stx tr_pos
        tax
        lda TRPAR,x
        sta tr_cur
        jmp @find
@d:     rts

tr_emit:
        ldx tr_k
        sta TRORD,x
        inc tr_k
        rts

; tr_perm: A/Y = a table: table[k] = old table[TRORD[k]]
tr_perm:
        sta rq
        sty rq+1
        ldy #0
@c:     cpy count
        bcs @p
        lda (rq),y
        sta TRTMP,y
        iny
        bne @c
@p:     ldy #0
@l:     cpy count
        bcs @d
        ldx TRORD,y
        lda TRTMP,x
        sta (rq),y
        iny
        bne @l
@d:     rts

; retree: in tree order, put the records back in order after a change,
; keeping the same record selected
retree: jsr treeon
        bcc @d
        lda #$FF
        sta rt_have
        lda vcount
        beq @go
        ldx sel
        lda VIEW,x
        tax
        lda PTRLO,x
        sta rt_lo
        lda PTRHI,x
        sta rt_hi
        lda PTRBK,x
        sta rt_bk
        lda #0
        sta rt_have
@go:    jsr dotree
        jsr rebuildview
        lda rt_have
        bne @d
        ldy #0
@l:     cpy vcount
        bcs @d
        ldx VIEW,y
        lda PTRLO,x
        cmp rt_lo
        bne @n
        lda PTRHI,x
        cmp rt_hi
        bne @n
        lda PTRBK,x
        cmp rt_bk
        bne @n
        sty sel
        rts
@n:     iny
        bne @l
@d:     rts

; tr_indent: in tree order, indent the name column of drawrow (the
; first Text field, or else the first column) by the depth of record dr_i
tr_indent:
        ldy dh_c
        lda lc_f,y
        cmp nf_nm
        beq @go
        lda nf_nm
        cmp #$FF
        bne @d
        lda dh_c
        bne @d
@go:
        jsr treeon
        bcc @d
        ldx dr_i
        lda VIEW,x
        tax
        lda DEPTH,x
        cmp #TR_MAXD
        bcc @m
        lda #TR_MAXD
@m:     asl a
        sta ti_n
        beq @d
        ldx #0
@len:   lda TMPSTR,x
        beq @gl
        inx
        bne @len
@gl:    txa                     ; keep it within 70 characters
        clc
        adc ti_n
        cmp #70
        bcc @ok
        lda #70
        sec
        sbc ti_n
        tax
        lda #0
        sta TMPSTR,x
@ok:    txa                     ; move right by ti_n, from the end
        tay
@mv:    lda TMPSTR,y
        sty t0
        pha
        tya
        clc
        adc ti_n
        tay
        pla
        sta TMPSTR,y
        ldy t0
        dey
        bpl @mv
        ldx ti_n
        lda #' '
@sp:    dex
        sta TMPSTR,x
        bne @sp
@d:     rts

; ---------------------------------------------------------------
; the record window
; ---------------------------------------------------------------
; ef_val: the EDITTXT of field X as a number -> fn_v (0 if blank)
ef_val: jsr etptr
        lda #0
        sta fn_v
        sta fn_v+1
        ldy #0
        lda (ptr2),y
        sta t4
        ldy #1
@l:     dey
        cpy t4
        iny
        bcs @d
        lda (ptr2),y
        cmp #'0'
        bcc @n
        cmp #'9'+1
        bcs @n
        and #$0F
        pha
        lda fn_v                ; *10
        asl a
        sta t2
        lda fn_v+1
        rol a
        sta t3
        lda t2
        asl a
        sta t0
        lda t3
        rol a
        sta t1
        asl t0
        rol t1
        clc
        lda t0
        adc t2
        sta fn_v
        lda t1
        adc t3
        sta fn_v+1
        pla
        clc
        adc fn_v
        sta fn_v
        bcc @n
        inc fn_v+1
@n:     iny
        bne @l
@d:     rts

; ef_setval: fn_v -> the EDITTXT of field ffoc (blank if 0)
ef_setval:
        ldx ffoc
        jsr etptr
        lda fn_v
        ora fn_v+1
        bne @n
        tay
        sta (ptr2),y
        rts
@n:     jsr v2num
        jsr fmtnum
        ldx #0
        ldy #1
@c:     lda numbuf,x
        beq @e
        sta (ptr2),y
        inx
        iny
        bne @c
@e:     txa
        ldy #0
        sta (ptr2),y
        rts

; ef_drawnest: draw No. / Part Of field df_f (focused if df_foc)
ef_drawnest:
        lda #FL_VCOL
        sta cx
        ldx df_f
        lda fkind,x
        cmp #K_NO
        bne @po
        lda df_foc
        sta inv
        jsr etptr
        jsr buf2tmp
        lda TMPSTR
        bne @nn
        LDAY s_newno
        jsr strtmp
@nn:    lda #0
        sta pf_right
        lda #8
        jsr prtfit
        lda #0
        sta inv
        rts
@po:    lda #G_LEFT
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
        jsr putch
        lda #FL_VCOL+9
        sta cx
        ldx #47
        jsr spaces
        lda #FL_VCOL+9
        sta cx
        ldx df_f
        jsr ef_val
        lda fn_v
        ora fn_v+1
        bne @v
        LDAY s_pnone
        jmp @s
@v:     jsr findno
        bcc @f
        LDAY s_pmiss
@s:     jsr strtmp
        jmp @p
@f:     jsr pname
@p:     lda #0
        sta pf_right
        lda #47
        jmp prtfit

; ef_pokey: A = a key in a Part Of field
ef_pokey:
        sta ek_c
        cmp #$08
        beq @prev
        cmp #$15
        beq @next
        cmp #' '
        beq @next
        cmp #$18
        beq @clr
        ldx ffoc
        jsr etptr
        ldy #0
        lda (ptr2),y
        tay
        lda ek_c
        cmp #$7F
        beq @del
        cmp #'0'
        bcc @d
        cmp #'9'+1
        bcs @d
        cpy #3
        bcs @d
        iny
        sta (ptr2),y
        tya
        ldy #0
        sta (ptr2),y
        jmp @draw
@del:   tya
        beq @d
        dey
        tya
        ldy #0
        sta (ptr2),y
        jmp @draw
@clr:   lda #0
        sta fn_v
        sta fn_v+1
        jsr ef_setval
        jmp @draw
@prev:  lda #$FF
        bne @st
@next:  lda #1
@st:    jsr ef_step
@draw:  ldx ffoc
        jmp drawefld
@d:     rts

; ef_step: A = +1/-1: the next record this one can be part of
ef_step:
        sta es_d
        jsr notab_build
        ldx ffoc
        jsr ef_val
        lda #0
        sta in_self
        sta in_self+1
        lda ed_rec
        cmp #$FF
        beq @ns
        jsr getno
        lda pk_v
        sta in_self
        lda pk_v+1
        sta in_self+1
@ns:    jsr findno              ; es_p = the record now chosen ($FF none)
        bcc @hp
        lda #$FF
@hp:    sta es_p
@nx:    lda es_d
        bmi @back
        ldx es_p                ; forward: none -> 0 -> ... -> none
        inx
        cpx count
        bcc @try
        bcs @none
@back:  ldx es_p
        cpx #$FF
        bne @b1
        ldx count
@b1:    dex
        cpx #$FF
        beq @none
        cpx count
        bcs @none
@try:   stx es_p
        lda NOLO,x
        sta fn_v
        sta es_v
        lda NOHI,x
        sta fn_v+1
        sta es_v+1
        ora fn_v
        beq @nx
        jsr isinside
        bcs @nx
        lda es_v
        sta fn_v
        lda es_v+1
        sta fn_v+1
        jmp ef_setval
@none:  lda #0
        sta fn_v
        sta fn_v+1
        jmp ef_setval

; ef_check: after OK, the Part Of in EDITREC must name another record
; that isn't inside this one.  Carry set = no, A/Y = the message.
ef_check:
        ldx nf_po
        cpx #$FF
        beq @ok
        ldy foff,x
        lda EDITREC,y
        sta fn_v
        sta es_v
        lda EDITREC+1,y
        sta fn_v+1
        sta es_v+1
        ora fn_v
        beq @ok
        jsr findno
        bcs @miss
        lda ed_rec
        cmp #$FF
        beq @ok
        jsr getno
        lda pk_v
        sta in_self
        lda pk_v+1
        sta in_self+1
        lda es_v
        sta fn_v
        lda es_v+1
        sta fn_v+1
        jsr isinside
        bcs @loop
@ok:    clc
        rts
@miss:  LDAY al_pmiss
        jmp @bad
@loop:  LDAY al_ploop
@bad:   ldx nf_po
        stx ffoc
        sec
        rts

        .segment "RODATA"
s_newno:  .byte "(new)", 0
s_pnone:  .byte "(not part of another record)", 0
s_pmiss:  .byte "(no record has this No.)", 0
s_pmiss2: .byte "No record has the No. typed in|"
          .byte "Part Of. Choose one with ", G_LEFT, " and ", G_RIGHT, ",|"
          .byte "or clear it with CTRL-X.", 0
s_ploop:  .byte "A record can't be part of itself,|"
          .byte "or of a record that is inside it.", 0
al_pmiss: .word t_alert, s_pmiss2
          .byte 1
          .word b_ok
al_ploop: .word t_alert, s_ploop
          .byte 1
          .word b_ok
        .segment "CODE"

; ---------------------------------------------------------------
; Select: No. and Part Of criteria.  A criterion that starts with a
; number compares numbers; for Part Of, words are looked for in the
; name of the record it is inside.  The field is copied to FAKEREC as a
; Number or Text value and matched like one.
; ---------------------------------------------------------------
fm_nest:
        lda rm_rp
        sta rp
        sta fmn_rp
        lda rm_rp+1
        sta rp+1
        sta fmn_rp+1
        ldy fk_o
        lda (rp),y
        sta fn_v
        iny
        lda (rp),y
        sta fn_v+1
        lda fk_k                ; numbers or words?
        cmp #K_NO
        beq @num
        ldx rm_f
        jsr ctptr
        ldy #0
        lda (ptr2),y
        sta t4
        ldy #1
@sc:    dey
        cpy t4
        iny
        bcs @num
        lda (ptr2),y
        cmp #'0'
        bcc @sn
        cmp #'9'+1
        bcc @num
        cmp #'A'
        bcs @text
@sn:    iny
        bne @sc
@num:   lda fn_v
        sta FAKEREC
        lda fn_v+1
        sta FAKEREC+1
        ldx #0
        ora fn_v
        bne @nb
        ldx #BLANKHI
@nb:    lda #0
        sta FAKEREC+2
        stx FAKEREC+3
        lda #K_NUMBER
        bne @go
@text:  lda #0
        sta f2t_mode
        jsr f2t                 ; the parent's name
        tax
        cpx #60
        bcc @tl
        ldx #60
@tl:    stx FAKEREC
@tc:    txa
        beq @tk
        lda TMPSTR-1,x
        sta FAKEREC,x
        dex
        bne @tc
@tk:    lda #60
        sta fk_l
        lda #K_TEXT
@go:    sta fk_k
        lda #0
        sta fk_o
        lda #<FAKEREC
        sta rm_rp
        sta rp
        lda #>FAKEREC
        sta rm_rp+1
        sta rp+1
        jsr fm_body
        php
        lda fmn_rp
        sta rm_rp
        sta rp
        lda fmn_rp+1
        sta rm_rp+1
        sta rp+1
        plp
        rts

; ---------------------------------------------------------------
; Mouse Calc
; ---------------------------------------------------------------
; wr_nest: a No. or Part Of as a number cell (nothing if blank)
wr_nest:
        ldy fk_o
        lda (rp),y
        sta fn_v
        iny
        lda (rp),y
        sta fn_v+1
        ora fn_v
        beq @d
        lda #0
        sta en_neg
        lda #$80
        jsr cell_begin
        jsr v2num
        jsr fmtnum
        lda #0
        sta en_frac
        jsr enc_dec
        jmp cell_end
@d:     rts

; nestkinds: a new form made from a sheet: a column headed "No." or
; "Part Of" (holding numbers, or nothing) becomes that kind of field
nestkinds:
        ldx #0
@l:     cpx dn
        bcs @fix
        lda dkind,x
        cmp #K_NUMBER
        beq @c
        cmp #K_TEXT
        bne @n
@c:     stx nk_x
        jsr dnptr
        LDAY s_keyno
        jsr namekey
        bne @p
        lda #K_NO
        bne @set
@p:     LDAY s_keypo
        jsr namekey
        bne @n0
        lda #K_PARTOF
@set:   ldx nk_x
        sta dkind,x
@n0:    ldx nk_x
@n:     inx
        bne @l
@fix:   LDAY dkind
        sta rq
        sty rq+1
        ldx dn
        jmp fixkinds

; namekey: is the name at ptr2 (length-prefixed) the zero-terminated
; key A/Y, counting only letters and digits, in any case?  Z set = yes
namekey:
        sta ptr3
        sty ptr3+1
        ldy #0
        lda (ptr2),y
        sta nk_len
        lda #0
        sta nk_i                ; in the name
        sta nk_j                ; in the key
@l:     lda nk_i
        cmp nk_len
        bcs @end
        inc nk_i
        ldy nk_i
        lda (ptr2),y
        jsr toupper
        cmp #'0'
        bcc @l
        cmp #'9'+1
        bcc @ch
        cmp #'A'
        bcc @l
        cmp #'Z'+1
        bcs @l
@ch:    ldy nk_j
        cmp (ptr3),y
        bne @no
        inc nk_j
        jmp @l
@end:   ldy nk_j
        lda (ptr3),y
        rts                     ; Z set if the key is used up too
@no:    lda #1
        rts

        .segment "RODATA"
s_keyno: .byte "NO", 0
s_keypo: .byte "PARTOF", 0
        .segment "CODE"

; imp_nest: after an import.  Rows added to records that already have
; numbers keep their links: their No. and Part Of move up past the
; largest No. in use.  Then every record gets a No. of its own.
imp_nest:
        lda nf_no
        cmp #$FF
        beq @fix
        lda im_base
        beq @fix
        ldx #63                 ; did the sheet have a No. column?
@c:     lda colmap,x
        cmp nf_no
        beq @have
        dex
        bpl @c
        bmi @fix
@have:  lda #0
        sta nx_max
        sta nx_max+1
        sta nx_i
@m:     lda nx_i                ; the largest No. before the new rows
        cmp im_base
        bcs @md
        jsr getno
        lda pk_v+1
        cmp nx_max+1
        bcc @mn
        bne @mb
        lda pk_v
        cmp nx_max
        bcc @mn
@mb:    lda pk_v
        sta nx_max
        lda pk_v+1
        sta nx_max+1
@mn:    inc nx_i
        bne @m
@md:    lda im_base
        sta nx_i
@a:     lda nx_i
        cmp count
        bcs @fix
        ldx nf_no
        jsr @shift
        ldx nf_po
        cpx #$FF
        beq @an
        jsr @shift
@an:    inc nx_i
        bne @a
@fix:   jsr numberfix
        jmp notab_inval
; @shift: field X of record nx_i += nx_max (0 stays 0; past 999 -> 0)
@shift: stx is_f
        lda nx_i
        jsr getv
        lda pk_v
        ora pk_v+1
        beq @sd
        clc
        lda pk_v
        adc nx_max
        sta pk_v
        lda pk_v+1
        adc nx_max+1
        sta pk_v+1
        cmp #>MAXNO
        bcc @sw
        bne @sz
        lda pk_v
        cmp #<(MAXNO+1)
        bcc @sw
@sz:    lda #0
        sta pk_v
        sta pk_v+1
@sw:    lda nx_i
        ldx is_f
        jmp pokev
@sd:    rts

; ---------------------------------------------------------------
; Design Form: one No., one Part Of, and Part Of needs a No.
; carry set = not allowed, A/Y = the message, X = the row
; ---------------------------------------------------------------
dnestchk:
        lda #$FF
        sta dc_no
        sta dc_po
        ldx #0
@l:     cpx dn
        bcs @e
        lda dkind,x
        cmp #K_NO
        bne @p
        ldy dc_no
        iny
        bne @two
        stx dc_no
@p:     cmp #K_PARTOF
        bne @n
        ldy dc_po
        iny
        bne @twop
        stx dc_po
@n:     inx
        bne @l
@e:     ldx dc_po
        cpx #$FF
        beq @ok
        lda dc_no
        cmp #$FF
        bne @ok
        LDAY al_ponono
        sec
        rts
@ok:    clc
        rts
@two:   LDAY al_twono
        sec
        rts
@twop:  LDAY al_twopo
        sec
        rts

        .segment "RODATA"
s_twono:  .byte "A form can have only one field|"
          .byte "of type No.", 0
s_twopo:  .byte "A form can have only one field|"
          .byte "of type Part Of.", 0
s_ponono: .byte "A Part Of field holds the No. of|"
          .byte "another record, so the form needs|"
          .byte "a field of type No. as well.", 0
al_twono: .word t_alert, s_twono
          .byte 1
          .word b_ok
al_twopo: .word t_alert, s_twopo
          .byte 1
          .word b_ok
al_ponono: .word t_alert, s_ponono
          .byte 1
          .word b_ok

; tables after the program (TBASE, defs.inc), set up at run time
NOLO     = TBASE
NOHI     = NOLO + MAXREC
DEPTH    = NOHI + MAXREC
NOMAP    = DEPTH + MAXREC
FAKEREC  = NOMAP + 128

        .segment "BSS"
PBUF:     .res 64
nf_no:    .res 1
nf_po:    .res 1
nf_nm:    .res 1
notab_ok: .res 1
fx_n:     .res 1
fx_no:    .res 1
fx_po:    .res 1
pk_len:   .res 1
pk_v:     .res 2
pv_f:     .res 1
nb_i:     .res 1
fn_v:     .res 2
nx_i:     .res 1
nx_max:   .res 2
kd_r:     .res 1
kd_n:     .res 1
kd_v:     .res 2
in_self:  .res 2
in_n:     .res 1
pn_r:     .res 1
nn_x:     .res 1
tr_i:     .res 1
tr_k:     .res 1
tr_r:     .res 1
tr_cur:   .res 1
tr_pos:   .res 1
tr_j:     .res 1
rt_have:  .res 1
rt_lo:    .res 1
rt_hi:    .res 1
rt_bk:    .res 1
ti_n:     .res 1
ek_c:     .res 1
es_d:     .res 1
es_p:     .res 1
es_v:     .res 2
fmn_rp:   .res 2
nk_x:     .res 1
nk_len:   .res 1
nk_i:     .res 1
nk_j:     .res 1
is_f:     .res 1
dc_no:    .res 1
dc_po:    .res 1
