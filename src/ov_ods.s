; ---------------------------------------------------------------
; Overlay 2: an ODS spreadsheet (mc_path) -> RETRODB.TMP, a CSV file of
; its first sheet, which overlay 1 then imports.
;
; An ODS file is a ZIP archive; the sheet is in content.xml, usually
; DEFLATE-compressed.  The decoder is a straightforward one after
; Mark Adler's puff.c: canonical Huffman codes decoded a bit at a time.
; Its 32K history window is auxiliary memory $4000-$BFFF, written a
; page at a time from WPAGE; matches further back than the page being
; filled are read through FPAGE, one page at a time.
;
; The XML is read as it comes out: rows of the first table:table become
; lines of RETRODB.TMP, each cell in double quotes.  Numbers come from
; office:value (money with a $ in front, so the import can tell), dates
; from office:date-value, Yes/No from office:boolean-value, everything
; else from the cell's text.  Repeated rows and cells are written out
; (up to 255 rows and 63 columns); rows with nothing in them are left
; out.
; ---------------------------------------------------------------
WPAGE   = LINEBUF               ; the output page being filled
FPAGE   = OBUF                  ; a page of history fetched from aux
FILEBUF2 = $B700                ; RETRODB.TMP's ProDOS buffer and the
ROWBUF  = $B400                 ; row's line: at the top of the main
                                ; record pool (empty: see cmd_import)
ROWMAX  = 760
i_src   = ptr2                  ; (zero page)

        .segment "OV2"
        jmp ods2csv

s_notods:  .byte "That file isn't an ODS spreadsheet,|"
           .byte "or it uses a kind of compression|"
           .byte "RetroDB can't read.", 0
s_badods:  .byte "That ODS file couldn't be read.|"
           .byte "It may be damaged.", 0
s_reading: .byte "Reading the ODS file", G_DOTS, 0
n_content: .byte "content.xml"
al_notods: .word t_import, s_notods
           .byte 1
           .word b_ok
al_badods: .word t_import, s_badods
           .byte 1
           .word b_ok

geteof_p:  .byte 2
ge_ref:    .byte 0
ge_eof:    .byte 0, 0, 0
tcreate_p: .byte 7
           .word s_tmpnm
           .byte $C3, $04
           .word $0000
           .byte $01
           .word 0, 0
topen_p:   .byte 3
           .word s_tmpnm
           .word FILEBUF2
to_ref:    .byte 0
twrite_p:  .byte 4
tw_ref:    .byte 0
           .word ROWBUF
tw_len:    .word 0
           .word 0
tclose_p:  .byte 1
tc_ref:    .byte 0

; ods2csv: carry clear = RETRODB.TMP made; set = it said what went wrong
ods2csv:
        LDAY s_reading
        jsr statusmsg
        MLICALL $C8, mopen_p    ; the ODS file
        bcc @o
        jmp xerror
@o:     jsr msetrefs
        lda mo_ref
        sta ge_ref
        lda #<INBUF
        sta mr_buf
        lda #>INBUF
        sta mr_buf+1
        lda #255
        sta mr_req
        lda #0
        sta mr_req+1
        jsr findxml             ; content.xml: where, and how it's packed
        bcc @tmp
        MLICALL $CC, mclose_p
        LDAY al_notods
        jsr alert
        sec
        rts
@tmp:   LDAY s_tmpnm            ; RETRODB.TMP, afresh
        jsr xdestroy
        MLICALL $C0, tcreate_p
        bcs @terr
        MLICALL $C8, topen_p
        bcc @to
@terr:  pha
        MLICALL $CC, mclose_p
        pla
        jmp @xerr
@to:    lda to_ref
        sta tw_ref
        sta tc_ref
        jsr xml_init
        lda #0
        sta ierr
        sta w_lo
        sta w_hi
        sta w_hi+1
        lda #$FF
        sta f_hi
        sta f_hi+1
        lda zmeth
        beq @stored
        jsr inflate
        jmp @done
@stored:
        jsr instored            ; stored: the bytes as they are
@done:  MLICALL $CC, tclose_p
        php
        MLICALL $CC, mclose_p
        plp
        bcs @werr
        lda ierr
        bne @bad
        lda x_werr
        bne @werr2
        clc
        rts
@bad:   LDAY al_badods
        jsr alert
        sec
        rts
@werr2: lda x_werr
@werr:
@xerr:  jsr xerror
        sec
        rts

; ---------------------------------------------------------------
; the ZIP directory
; ---------------------------------------------------------------
; findxml: leave the file at content.xml's data; zmeth = 0 stored or
; 8 deflated.  Carry set if there's no content.xml we can read.
findxml:
        MLICALL $D1, geteof_p
        jcs @no
        lda ge_eof+2            ; the last 22 bytes (or fewer than 255)
        bne @big
        lda ge_eof+1
        bne @big
        lda ge_eof
        cmp #22
        bcc @no
        sta fz_n
        lda #0
        sta mark_p+2
        sta mark_p+3
        sta mark_p+4
        jmp @rd
@big:   lda #255
        sta fz_n
        sec
        lda ge_eof
        sbc #255
        sta mark_p+2
        lda ge_eof+1
        sbc #0
        sta mark_p+3
        lda ge_eof+2
        sbc #0
        sta mark_p+4
@rd:    jsr fseek
        bcs @no
        ldx #0
@rb:    stx fx_i
        jsr getbyte
        bcs @no
        ldx fx_i
        sta FPAGE,x
        inx
        cpx fz_n
        bne @rb
        lda fz_n                ; look back for 50 4B 05 06
        sec
        sbc #22
        tax
@sig:   lda FPAGE,x
        cmp #$50
        bne @sn
        lda FPAGE+1,x
        cmp #$4B
        bne @sn
        lda FPAGE+2,x
        cmp #$05
        bne @sn
        lda FPAGE+3,x
        cmp #$06
        beq @eocd
@sn:    dex
        cpx #$FF
        bne @sig
@no:    sec
        rts
@eocd:  lda FPAGE+10,x          ; entries
        sta fx_ents
        lda FPAGE+11,x
        sta fx_ents+1
        lda FPAGE+16,x          ; central directory offset
        sta mark_p+2
        lda FPAGE+17,x
        sta mark_p+3
        lda FPAGE+18,x
        sta mark_p+4
        jsr fseek
        bcs @no
@ent:   lda fx_ents
        ora fx_ents+1
        beq @no
        ldx #0                  ; the 46-byte entry -> FPAGE
@eb:    stx fx_i
        jsr getbyte
        bcs @no
        ldx fx_i
        sta FPAGE,x
        inx
        cpx #46
        bne @eb
        lda FPAGE
        cmp #$50
        bne @no
        lda FPAGE+3
        cmp #$02
        bne @no
        lda #1                  ; its name: content.xml?
        sta fx_ok
        ldx #0
@nm:    cpx FPAGE+28
        bcs @ne
        stx fx_i
        jsr getbyte
        bcs @no
        ldx fx_i
        cpx #11
        bcs @nx
        cmp n_content,x
        beq @nn
@nx:    lda #0
        sta fx_ok
@nn:    inx
        bne @nm
@ne:    lda FPAGE+29            ; a name of 11 characters
        bne @bad
        lda FPAGE+28
        cmp #11
        beq @len
@bad:   lda #0
        sta fx_ok
@len:   lda fx_ok
        bne @found
        clc                     ; skip extra field and comment
        lda FPAGE+30
        adc FPAGE+32
        sta fx_skip
        lda FPAGE+31
        adc FPAGE+33
        sta fx_skip+1
@sk:    lda fx_skip
        ora fx_skip+1
        beq @nxe
        jsr getbyte
        jcs @no
        lda fx_skip
        bne @sk1
        dec fx_skip+1
@sk1:   dec fx_skip
        jmp @sk
@nxe:   lda fx_ents
        bne @ne1
        dec fx_ents+1
@ne1:   dec fx_ents
        jmp @ent
@found: lda FPAGE+10            ; method: stored or deflated only
        sta zmeth
        lda FPAGE+11
        bne @no2
        lda zmeth
        beq @m
        cmp #8
        bne @no2
@m:     lda FPAGE+20            ; compressed size (for stored data)
        sta zleft
        lda FPAGE+21
        sta zleft+1
        lda FPAGE+22
        sta zleft+2
        lda FPAGE+42            ; its local header
        sta mark_p+2
        lda FPAGE+43
        sta mark_p+3
        lda FPAGE+44
        sta mark_p+4
        jsr fseek
        bcs @no2
        ldx #0                  ; the 30-byte local header
@lb:    stx fx_i
        jsr getbyte
        bcs @no2
        ldx fx_i
        sta FPAGE,x
        inx
        cpx #30
        bne @lb
        clc                     ; then past its name and extra field
        lda FPAGE+26
        adc FPAGE+28
        sta fx_skip
        lda FPAGE+27
        adc FPAGE+29
        sta fx_skip+1
@ls:    lda fx_skip
        ora fx_skip+1
        beq @at
        jsr getbyte
        bcs @no2
        lda fx_skip
        bne @ls1
        dec fx_skip+1
@ls1:   dec fx_skip
        jmp @ls
@at:    clc
        rts
@no2:   sec
        rts

; fseek: SET_MARK to mark_p+2..4, and empty the input buffer
fseek:  lda mo_ref
        sta mark_p+1
        lda #0
        sta ib_len
        sta ib_pos
        MLICALL $CE, mark_p
        rts

; instored: zleft bytes as they are
instored:
@l:     lda zleft
        ora zleft+1
        ora zleft+2
        beq @d
        jsr getbyte
        bcs @e
        jsr xml_byte
        lda x_done
        bne @d
        lda zleft
        bne @a
        lda zleft+1
        bne @b
        dec zleft+2
@b:     dec zleft+1
@a:     dec zleft
        jmp @l
@e:     inc ierr
@d:     rts

; ---------------------------------------------------------------
; DEFLATE
; ---------------------------------------------------------------
inflate:
        lda #0
        sta bc
@blk:   jsr getbit              ; last block?
        lda #0
        rol a
        sta i_last
        ldx #2
        jsr bits
        lda v
        beq @st
        cmp #1
        beq @fix
        cmp #2
        beq @dyn
        jmp ibad
@st:    jsr i_stored
        jmp @next
@fix:   jsr i_fixed
        jsr codes
        jmp @next
@dyn:   jsr i_dynamic
        lda ierr
        bne @d
        jsr codes
@next:  lda ierr
        ora x_done
        bne @d
        lda i_last
        beq @blk
@d:     rts

ibad:   inc ierr
        rts

; getbit: the next bit in carry
getbit: lda bc
        bne @h
        stx gb_x
        jsr getbyte
        ldx gb_x
        bcc @ok
        inc ierr
        lda #0
@ok:    sta bb
        lda #8
        sta bc
@h:     dec bc
        lsr bb
        rts

; bits: X bits (up to 13), first bit lowest -> v
bits:   lda #0
        sta v
        sta v+1
        sta m+1
        lda #1
        sta m
@l:     cpx #0
        beq @d
        jsr getbit
        bcc @z
        lda v
        ora m
        sta v
        lda v+1
        ora m+1
        sta v+1
@z:     asl m
        rol m+1
        dex
        jmp @l
@d:     rts

; i_stored: a stored block: LEN, NLEN, then LEN bytes
i_stored:
        lda #0                  ; to the next byte boundary
        sta bc
        jsr getbyte
        sta v
        jsr getbyte
        sta v+1
        jsr getbyte
        jsr getbyte
@l:     lda v
        ora v+1
        beq @d
        jsr getbyte
        bcs @e
        jsr out_byte
        lda x_done
        bne @d
        lda v
        bne @a
        dec v+1
@a:     dec v
        jmp @l
@e:     inc ierr
@d:     rts

; i_fixed: the fixed codes
i_fixed:
        ldx #0
@a:     lda #8                  ; 0-143: 8 bits
        cpx #144
        bcc @s
        lda #9                  ; 144-255: 9 bits
@s:     sta LENS,x
        inx
        bne @a
        ldx #0
@b:     lda #7                  ; 256-279: 7 bits, 280-287: 8 bits
        cpx #24
        bcc @t
        lda #8
@t:     sta LENS+256,x
        inx
        cpx #32
        bne @b
        lda #<288
        ldx #>288
        jsr lconstruct
        ldx #0
        lda #5
@c:     sta LENS,x
        inx
        cpx #30
        bne @c
        lda #30
        jmp dconstruct

; i_dynamic: a dynamic block's code lengths, and its codes
i_dynamic:
        ldx #5                  ; HLIT, HDIST, HCLEN
        jsr bits
        clc
        lda v
        adc #<257
        sta nlen
        lda #>257
        adc #0
        sta nlen+1
        ldx #5
        jsr bits
        ldx v
        inx
        stx ndist
        ldx #4
        jsr bits
        lda v
        clc
        adc #4
        sta ncode
        ldx #18                 ; code length code lengths, in their order
        lda #0
@z:     sta LENS,x
        dex
        bpl @z
        lda #0
        sta i_n
@cl:    lda i_n
        cmp ncode
        bcs @cld
        ldx #3
        jsr bits
        ldx i_n
        ldy clorder,x
        lda v
        sta LENS,y
        inc i_n
        bne @cl
@cld:   lda #19                 ; (decoded with the distance tables)
        jsr dconstruct
        lda #0                  ; then the lengths themselves
        sta i_n
        sta i_n+1
        clc
        lda nlen
        adc ndist
        sta i_tot
        lda nlen+1
        adc #0
        sta i_tot+1
@ln:    lda i_n+1
        cmp i_tot+1
        bcc @more
        lda i_n
        cmp i_tot
        jcs @lnd
@more:  jsr decode_d
        lda ierr
        beq @ok
        rts
@ok:    lda v
        cmp #16
        bcs @rep
        jsr @put                ; a length
        jmp @ln
@rep:   cmp #16
        bne @r17
        lda i_n                 ; 16: the previous length 3-6 times
        ora i_n+1
        jeq ibad
        jsr @prev
        sta i_rl
        ldx #2
        jsr bits
        lda v
        clc
        adc #3
        jmp @fill
@r17:   cmp #17
        bne @r18
        lda #0                  ; 17: zero 3-10 times
        sta i_rl
        ldx #3
        jsr bits
        lda v
        clc
        adc #3
        jmp @fill
@r18:   lda #0                  ; 18: zero 11-138 times
        sta i_rl
        ldx #7
        jsr bits
        lda v
        clc
        adc #11
@fill:  sta i_rc
@fl:    lda i_n+1               ; (not past the end)
        cmp i_tot+1
        bcc @f1
        lda i_n
        cmp i_tot
        jcs ibad
@f1:    lda i_rl
        jsr @put
        dec i_rc
        bne @fl
        jmp @ln
@lnd:   lda nlen                ; literal/length codes
        ldx nlen+1
        jsr lconstruct
        lda nlen                ; distance codes follow them in LENS
        clc
        adc #<LENS
        sta i_src
        lda nlen+1
        adc #>LENS
        sta i_src+1
        ldy #0                  ; move them to the start of LENS
@mv:    lda (i_src),y
        sta LENS,y
        iny
        cpy ndist
        bne @mv
        lda ndist
        jmp dconstruct
; @put: A -> LENS[i_n++]
@put:   pha
        clc
        lda #<LENS
        adc i_n
        sta i_src
        lda #>LENS
        adc i_n+1
        sta i_src+1
        pla
        ldy #0
        sta (i_src),y
        inc i_n
        bne @p
        inc i_n+1
@p:     rts
; @prev: LENS[i_n - 1]
@prev:  sec
        lda i_n
        sbc #1
        sta i_src
        lda i_n+1
        sbc #0
        sta i_src+1
        clc
        lda i_src
        adc #<LENS
        sta i_src
        lda i_src+1
        adc #>LENS
        sta i_src+1
        ldy #0
        lda (i_src),y
        rts

clorder: .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15

; lconstruct: the literal/length tables from LENS[0..A/X-1]
lconstruct:
        sta c_n
        stx c_n+1
        lda #<LCNT
        sta c_cnt
        lda #>LCNT
        sta c_cnt+1
        lda #<LSYM
        sta c_sym
        lda #>LSYM
        sta c_sym+1
        jmp construct
; dconstruct: the distance tables from LENS[0..A-1]
dconstruct:
        sta c_n
        lda #0
        sta c_n+1
        lda #<DCNT
        sta c_cnt
        lda #>DCNT
        sta c_cnt+1
        lda #<DSYM
        sta c_sym
        lda #>DSYM
        sta c_sym+1

; construct: counts per length (16 words at c_cnt) and the symbols in
; code order (words at c_sym) from the lengths LENS[0..c_n-1]
construct:
        lda c_cnt
        sta ptr3
        lda c_cnt+1
        sta ptr3+1
        ldy #31                 ; no codes of any length yet
        lda #0
@z:     sta (ptr3),y
        dey
        bpl @z
        jsr @first              ; count the codes of each length
@cl:    jsr @end
        bcs @cd
        jsr @len
        asl a
        tay
        lda (ptr3),y
        clc
        adc #1
        sta (ptr3),y
        iny
        lda (ptr3),y
        adc #0
        sta (ptr3),y
        jsr @step
        jmp @cl
@cd:    lda #0                  ; where each length's symbols start
        sta OFFS+2
        sta OFFS+3
        ldy #2
@of:    clc
        lda OFFS,y
        adc (ptr3),y
        sta OFFS+2,y
        iny
        lda OFFS,y
        adc (ptr3),y
        sta OFFS+2,y
        iny
        cpy #30
        bne @of
        jsr @first              ; place the symbols
@pl:    jsr @end
        bcs @d
        jsr @len
        beq @pn
        asl a
        tay
        lda OFFS,y              ; slot = offs[len]++
        sta c_t
        lda OFFS+1,y
        sta c_t+1
        clc
        lda OFFS,y
        adc #1
        sta OFFS,y
        lda OFFS+1,y
        adc #0
        sta OFFS+1,y
        asl c_t                 ; sym[slot] = the symbol
        rol c_t+1
        clc
        lda c_sym
        adc c_t
        sta rq
        lda c_sym+1
        adc c_t+1
        sta rq+1
        ldy #0
        lda c_i
        sta (rq),y
        iny
        lda c_i+1
        sta (rq),y
@pn:    jsr @step
        jmp @pl
@d:     rts
@first: lda #0
        sta c_i
        sta c_i+1
        rts
@end:   lda c_i+1               ; carry set when c_i = c_n
        cmp c_n+1
        bcc @e
        lda c_i
        cmp c_n
@e:     rts
@len:   clc                     ; A = LENS[c_i]
        lda #<LENS
        adc c_i
        sta rq
        lda #>LENS
        adc c_i+1
        sta rq+1
        ldy #0
        lda (rq),y
        rts
@step:  inc c_i
        bne @s
        inc c_i+1
@s:     rts

; decode_l / decode_d: the next symbol with those tables -> v
decode_l:
        lda #<LCNT
        sta ptr3
        lda #>LCNT
        sta ptr3+1
        lda #<LSYM
        sta rq
        lda #>LSYM
        sta rq+1
        jmp decode
decode_d:
        lda #<DCNT
        sta ptr3
        lda #>DCNT
        sta ptr3+1
        lda #<DSYM
        sta rq
        lda #>DSYM
        sta rq+1
decode: lda #0
        sta d_code
        sta d_code+1
        sta d_first
        sta d_first+1
        sta d_index
        sta d_index+1
        ldy #2                  ; length 1 (counts are words)
@l:     sty d_y
        jsr getbit
        lda d_code              ; code |= bit (its low bit is 0)
        adc #0
        sta d_code
        ldy d_y
        lda (ptr3),y            ; d_cnt = count[len]
        sta d_cnt
        iny
        lda (ptr3),y
        sta d_cnt+1
        sec                     ; t = code - first
        lda d_code
        sbc d_first
        sta d_t
        lda d_code+1
        sbc d_first+1
        sta d_t+1
        lda d_t+1               ; t < count?
        cmp d_cnt+1
        bcc @hit
        bne @no
        lda d_t
        cmp d_cnt
        bcc @hit
@no:    clc                     ; index += count
        lda d_index
        adc d_cnt
        sta d_index
        lda d_index+1
        adc d_cnt+1
        sta d_index+1
        clc                     ; first = (first + count) << 1
        lda d_first
        adc d_cnt
        sta d_first
        lda d_first+1
        adc d_cnt+1
        sta d_first+1
        asl d_first
        rol d_first+1
        asl d_code              ; code <<= 1
        rol d_code+1
        ldy d_y
        iny
        iny
        cpy #32
        bne @l
        jmp ibad
@hit:   clc                     ; v = sym[index + t]
        lda d_index
        adc d_t
        sta d_t
        lda d_index+1
        adc d_t+1
        sta d_t+1
        asl d_t
        rol d_t+1
        clc
        lda rq
        adc d_t
        sta rq
        lda rq+1
        adc d_t+1
        sta rq+1
        ldy #0
        lda (rq),y
        sta v
        iny
        lda (rq),y
        sta v+1
        rts

; codes: literals, lengths and distances until the end of the block
codes:
@l:     jsr decode_l
        lda ierr
        bne @d
        lda v+1
        bne @hi
        lda v                   ; a literal
        jsr out_byte
        lda x_done
        beq @l
@d:     rts
@hi:    lda v                   ; 256: the end; 257-285: a length
        beq @d
        sec
        sbc #1
        cmp #29
        bcs @bad
        tax
        lda lbase_lo,x
        sta i_len
        lda lbase_hi,x
        sta i_len+1
        lda lext,x
        tax
        jsr bits
        clc
        lda i_len
        adc v
        sta i_len
        lda i_len+1
        adc v+1
        sta i_len+1
        jsr decode_d            ; the distance
        lda ierr
        bne @d
        lda v
        cmp #30
        bcs @bad
        tax
        lda dbase_lo,x
        sta i_dist
        lda dbase_hi,x
        sta i_dist+1
        lda dext,x
        tax
        jsr bits
        clc
        lda i_dist
        adc v
        sta i_dist
        lda i_dist+1
        adc v+1
        sta i_dist+1
        jsr copy
        lda x_done
        jeq @l
        rts
@bad:   jmp ibad

lbase_lo: .lobytes 3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258
lbase_hi: .hibytes 3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258
lext:     .byte 0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0
dbase_lo: .lobytes 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577
dbase_hi: .hibytes 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577
dext:     .byte 0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13

; copy: i_len bytes from i_dist back
copy:   sec                     ; s = position - distance
        lda w_lo
        sbc i_dist
        sta s_lo
        lda w_hi
        sbc i_dist+1
        sta s_hi
        lda w_hi+1
        sbc #0
        sta s_hi+1
        bcs @l
        jmp ibad                ; (before the start)
@l:     lda i_len
        ora i_len+1
        jeq @d
        lda s_hi                ; in the page being filled?
        cmp w_hi
        bne @aux
        lda s_hi+1
        cmp w_hi+1
        bne @aux
        ldx s_lo
        lda WPAGE,x
        jmp @put
@aux:   lda s_hi                ; in aux: that page in FPAGE
        cmp f_hi
        bne @f
        lda s_hi+1
        cmp f_hi+1
        beq @have
@f:     lda s_hi
        sta f_hi
        sta A1L+1
        sta A2L+1
        lda s_hi+1
        sta f_hi+1
        lda A1L+1
        and #$7F                ; window page -> aux $40-$BF
        clc
        adc #$40
        sta A1L+1
        sta A2L+1
        lda #0
        sta A1L
        lda #$FF
        sta A2L
        lda #<FPAGE
        sta A4L
        lda #>FPAGE
        sta A4L+1
        clc
        jsr auxmv
@have:  ldx s_lo
        lda FPAGE,x
@put:   jsr out_byte
        lda x_done
        bne @d
        inc s_lo
        bne @n
        inc s_hi
        bne @n
        inc s_hi+1
@n:     lda i_len
        bne @dl
        dec i_len+1
@dl:    dec i_len
        jmp @l
@d:     rts

; out_byte: A comes out of the decoder: into the window, and the XML
out_byte:
        ldx w_lo
        sta WPAGE,x
        pha
        inx
        stx w_lo
        bne @x
        lda w_hi                ; a full page: to aux
        and #$7F                ; window page -> aux $40-$BF
        clc
        adc #$40
        sta A4L+1
        lda #0
        sta A4L
        lda #<WPAGE
        sta A1L
        lda #>WPAGE
        sta A1L+1
        lda #<(WPAGE+255)
        sta A2L
        lda #>(WPAGE+255)
        sta A2L+1
        sec
        jsr auxmv
        lda w_hi                ; (FPAGE may hold that page's old data)
        cmp f_hi
        bne @i
        lda w_hi+1
        cmp f_hi+1
        bne @i
        lda #$FF
        sta f_hi
        sta f_hi+1
@i:     inc w_hi
        bne @x
        inc w_hi+1
@x:     pla
        jmp xml_byte

; ---------------------------------------------------------------
; the XML
; ---------------------------------------------------------------
XS_TEXT  = 0
XS_LT    = 1                    ; after <
XS_NAME  = 2
XS_ATTRS = 3
XS_ANAME = 4
XS_EQ    = 5                    ; after the attribute's name: = then quote
XS_AVAL  = 6
XS_SKIP  = 7                    ; <?...>, <!...>
XS_ENT   = 8                    ; &...;

T_OTHER = 0
T_TABLE = 1
T_ROW   = 2
T_CELL  = 3
T_P     = 4
T_S     = 5
T_SP1   = 6                     ; text:tab, text:line-break: a space

xml_init:
        lda #0
        ldx #xv_end - x_vars - 1
@z:     sta x_vars,x
        dex
        bpl @z
        sta rowlen
        sta rowlen+1
        rts

xml_byte:
        sta xb
        ldx x_st
        lda xjh,x
        pha
        lda xjl,x
        pha
        lda xb
        rts
xjl:    .lobytes x_text-1, xp_lt-1, x_name-1, x_attrs-1, x_aname-1, x_eq-1, x_aval-1, x_skip-1, x_ent-1
xjh:    .hibytes x_text-1, xp_lt-1, x_name-1, x_attrs-1, x_aname-1, x_eq-1, x_aval-1, x_skip-1, x_ent-1

x_text: cmp #'<'
        bne @a
        lda #XS_LT
        sta x_st
        rts
@a:     cmp #'&'
        bne @c
        lda #XS_TEXT
        jmp x_entbeg
@c:     jmp x_tchar

xp_lt:   ldx #0
        stx x_nlen
        stx x_close
        stx x_self
        cmp #'/'
        bne @n
        inc x_close
        lda #XS_NAME
        sta x_st
        rts
@n:     cmp #'?'
        beq @sk
        cmp #'!'
        beq @sk
        jsr x_nch
        lda #XS_NAME
        sta x_st
        rts
@sk:    lda #XS_SKIP
        sta x_st
        rts

x_name: cmp #'>'
        bne @a
        jsr x_tagid
        jmp xp_gt
@a:     cmp #'/'
        bne @b
        inc x_self
        rts
@b:     cmp #' '+1
        bcs x_nch
        jsr x_tagid             ; the name is complete
        lda #XS_ATTRS
        sta x_st
        rts
; x_nch: A -> the tag's name (up to 31 characters)
x_nch:  ldx x_nlen
        cpx #31
        bcs @d
        sta x_nm,x
        inx
        stx x_nlen
        lda #0
        sta x_nm,x
@d:     rts

x_attrs:
        cmp #'>'
        bne @a
        jmp xp_gt
@a:     cmp #'/'
        bne @b
        inc x_self
        rts
@b:     cmp #' '+1
        bcc @d
        ldx #0
        stx x_alen
        jsr x_ach
        lda #XS_ANAME
        sta x_st
@d:     rts

x_aname:
        cmp #'='
        bne @a
        lda #XS_EQ
        sta x_st
        rts
@a:     cmp #' '+1
        bcs x_ach
        rts
; x_ach: A -> the attribute's name (up to 31 characters)
x_ach:  ldx x_alen
        cpx #31
        bcs @d
        sta x_an,x
        inx
        stx x_alen
        lda #0
        sta x_an,x
@d:     rts

x_eq:   cmp #'"'
        beq @q
        cmp #$27
        bne @d
@q:     sta x_quote
        lda #0
        sta x_vlen
        sta TMP2
        lda #XS_AVAL
        sta x_st
@d:     rts

x_aval: cmp x_quote
        bne @a
        jsr x_attr              ; the attribute is complete
        lda #XS_ATTRS
        sta x_st
        rts
@a:     cmp #'&'
        bne x_vch
        lda #XS_AVAL
        jmp x_entbeg
; x_vch: A -> the attribute's value in TMP2 (up to 63 characters)
x_vch:  ldx x_vlen
        cpx #63
        bcs @d
        sta TMP2,x
        inx
        stx x_vlen
        lda #0
        sta TMP2,x
@d:     rts

x_skip: cmp #'>'
        bne @d
        lda #XS_TEXT
        sta x_st
@d:     rts

; entities: &amp; &lt; &gt; &quot; &apos; &#n; &#xh;
x_entbeg:
        sta x_eret
        lda #0
        sta x_elen
        lda #XS_ENT
        sta x_st
        rts
x_ent:  cmp #';'
        beq @end
        ldx x_elen
        cpx #8
        bcs @d
        sta x_eb,x
        inc x_elen
@d:     rts
@end:   lda x_eret
        sta x_st
        lda x_eb
        cmp #'#'
        beq @num
        ldx #0                  ; a named one: by its first letters
@n:     lda x_enm,x
        beq @q
        cmp x_eb
        bne @nx
        lda x_enm+1,x
        cmp x_eb+1
        beq @hit
@nx:    inx
        inx
        inx
        bne @n
@hit:   lda x_enm+2,x
        jmp @out
@num:   lda #0                  ; &#nn;  (and &#xhh; roughly)
        sta v
        ldx #1
@nd:    cpx x_elen
        bcs @nv
        lda x_eb,x
        and #$0F
        sta t0
        lda v                   ; v = v*10 + digit
        asl a
        asl a
        clc
        adc v
        asl a
        clc
        adc t0
        sta v
        inx
        bne @nd
@nv:    lda v
        cmp #$80
        bcc @out
@q:     lda #'?'
@out:   ldx x_st
        cpx #XS_AVAL
        bne @t
        jmp x_vch
@t:     jmp x_tchar
x_enm:  .byte "am&", "lt<", "gt>", "qu", $22, "ap", $27, 0

; x_tagid: x_nm -> x_tag
x_tagid:
        ldx #0
@l:     stx x_ti
        lda x_tn,x
        beq @none
        tay                     ; Y = offset of the name in x_tstr
        ldx #0
@c:     lda x_tstr,y
        cmp x_nm,x
        bne @nx
        cmp #0
        beq @hit
        iny
        inx
        bne @c
@nx:    ldx x_ti
        inx
        inx
        bne @l
@hit:   ldx x_ti
        lda x_tn+1,x
        sta x_tag
        rts
@none:  lda #T_OTHER
        sta x_tag
        rts
x_tn:   .byte xt_table - x_tstr, T_TABLE, xt_row - x_tstr, T_ROW
        .byte xt_cell - x_tstr, T_CELL, xt_cov - x_tstr, T_CELL
        .byte xt_p - x_tstr, T_P, xt_s - x_tstr, T_S
        .byte xt_tab - x_tstr, T_SP1, xt_lb - x_tstr, T_SP1, 0
x_tstr: .byte 0                 ; (offset 0 means the end of x_tn)
xt_table: .byte "table:table", 0
xt_row:   .byte "table:table-row", 0
xt_cell:  .byte "table:table-cell", 0
xt_cov:   .byte "table:covered-table-cell", 0
xt_p:     .byte "text:p", 0
xt_s:     .byte "text:s", 0
xt_tab:   .byte "text:tab", 0
xt_lb:    .byte "text:line-break", 0

; x_attr: an attribute of the tag (x_an = x_nm's attribute, TMP2 = value)
x_attr: lda x_close
        bne @d
        lda x_tag
        cmp #T_ROW
        bne @c
        LDAY xa_rrep
        jsr x_aname_is
        bne @d
        jsr x_vnum
        sta r_rep
@d:     rts
@c:     cmp #T_CELL
        beq @cell
        jmp @s
@cell:  LDAY xa_crep
        jsr x_aname_is
        bne @ty
        jsr x_vnum
        sta c_rep
        rts
@ty:    LDAY xa_type
        jsr x_aname_is
        bne @v
        lda TMP2                ; f(loat) c(urrency) p(ercentage)
        ldx #1                  ; d(ate) b(oolean), anything else text
        cmp #'f'
        beq @st
        cmp #'p'
        beq @st
        inx
        cmp #'c'
        beq @st
        inx
        cmp #'d'
        beq @st
        inx
        cmp #'b'
        beq @st
        ldx #0
@st:    stx c_type
        rts
@v:     LDAY xa_val
        jsr x_aname_is
        beq @cv
        LDAY xa_dval
        jsr x_aname_is
        beq @cv
        LDAY xa_bval
        jsr x_aname_is
        beq @cv
        LDAY xa_form            ; a SUM formula: a totals row, left out
        jsr x_aname_is
        bne @x
        ldx #0
@fl:    lda TMP2,x
        beq @x
        ldy #0
@fc:    lda TMP2,x
        cmp s_sum,y
        bne @fn
        inx
        iny
        cpy #4
        bne @fc
        inc r_sum
        rts
@fn:    txa                     ; (back to the character after the start)
        sty fz_y
        sec
        sbc fz_y
        tax
        inx
        bne @fl
@x:     rts
@cv:    ldx #0                  ; the value -> c_val
@cvl:   lda TMP2,x
        sta c_val,x
        beq @x
        inx
        cpx #31
        bne @cvl
        lda #0
        sta c_val,x
        rts
@s:     cmp #T_S
        bne @x
        LDAY xa_c
        jsr x_aname_is
        bne @x
        jsr x_vnum
        sta s_n
        rts
xa_rrep: .byte "table:number-rows-repeated", 0
xa_crep: .byte "table:number-columns-repeated", 0
xa_type: .byte "office:value-type", 0
xa_val:  .byte "office:value", 0
xa_dval: .byte "office:date-value", 0
xa_bval: .byte "office:boolean-value", 0
xa_c:    .byte "text:c", 0
xa_form: .byte "table:formula", 0
s_sum:   .byte "SUM("

; x_aname_is: Z set if the attribute's name is A/Y
x_aname_is:
        sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        cmp x_an,y
        bne @d
        cmp #0
        beq @d
        iny
        bne @l
@d:     rts

; x_vnum: TMP2 as a whole number, at most 255 -> A
x_vnum: lda #0
        sta v
        ldx #0
@l:     lda TMP2,x
        beq @d
        cmp #'0'
        bcc @d
        cmp #'9'+1
        bcs @d
        and #$0F
        sta t0
        lda v
        cmp #26
        bcs @big
        asl a
        asl a
        clc
        adc v
        asl a
        clc
        adc t0
        bcs @big
        sta v
        inx
        bne @l
@big:   lda #255
        rts
@d:     lda v
        rts

; xp_gt: the tag's > : opening or closing it
xp_gt:   lda #XS_TEXT
        sta x_st
        lda x_close
        bne xp_end
        lda x_tag               ; an opening tag
        cmp #T_TABLE
        bne @row
        lda x_done              ; (only the first table)
        bne @d
        inc x_intab
        jmp @self
@row:   ldx x_intab
        beq @self
        cmp #T_ROW
        bne @cell
        jsr row_begin
        jmp @self
@cell:  cmp #T_CELL
        bne @p
        lda #1
        sta x_incell
        jmp @self
@p:     cmp #T_P
        bne @s
        lda x_incell
        beq @self
        lda x_pcount            ; a second paragraph: a space between
        beq @p1
        lda #' '
        jsr x_tchar0
@p1:    inc x_pcount
        lda #1
        sta x_inp
        jmp @self
@s:     cmp #T_S
        bne @sp
        lda x_inp
        beq @self
@sl:    lda #' '                ; text:s: s_n spaces (1 if not given)
        jsr x_tchar0
        dec s_n
        bne @sl
        jmp @self
@sp:    cmp #T_SP1
        bne @self
        lda x_inp
        beq @self
        lda #' '
        jsr x_tchar0
@self:  lda x_self              ; <.../> closes it at once
        bne xp_end
@d:     lda x_tag               ; get ready for the next one
        jmp x_reset

; xp_end: a closing tag (or a self-closing one)
xp_end:  lda x_tag
        cmp #T_TABLE
        bne @row
        lda x_intab
        beq @d
        inc x_done              ; the first table is done: stop
        jmp @d
@row:   ldx x_intab
        beq @d
        cmp #T_ROW
        bne @cell
        jsr row_end
        jmp @d
@cell:  cmp #T_CELL
        bne @p
        jsr cell_end
        jmp @d
@p:     cmp #T_P
        bne @d
        lda #0
        sta x_inp
@d:     lda x_tag
; x_reset: after a tag: attributes for the next one
x_reset:
        lda #0
        sta x_self
        sta x_close
        cmp #T_S
        bne @r
        lda #1
        sta s_n
@r:     rts

; x_tchar: a character of text, if it's in a cell's paragraph
x_tchar:
        ldx x_inp
        beq x_td
x_tchar0:
        cmp #$80                ; UTF-8: one ? per character
        bcc @a
        cmp #$C0
        bcc x_td
        lda #'?'
@a:     cmp #' '
        bcs @b
        lda #' '
@b:     cmp #$7F
        bcs x_td
        cmp #'"'                ; (quotes can't go in a database file)
        bne @c
        lda #$27
@c:     ldx c_tlen
        cpx #70
        bcs x_td
        sta TMPSTR,x
        inx
        stx c_tlen
x_td:   rts

; row_begin: a table:table-row
row_begin:
        lda #0
        sta rowlen
        sta rowlen+1
        sta r_col
        sta r_pend
        sta r_any
        sta r_sum
        lda #1
        sta r_rep
cell_reset:
        lda #0
        sta c_tlen
        sta c_type
        sta c_val
        sta x_pcount
        sta x_inp
        sta x_incell
        lda #1
        sta c_rep
        lda #1
        sta s_n
        rts

; cell_end: the cell's value goes into the row (c_rep times)
cell_end:
        lda c_rep
        bne @r
        inc c_rep
@r:     ldx c_tlen              ; its text, zero-terminated
        lda #0
        sta TMPSTR,x
        lda c_type
        beq @txt
        lda c_val               ; a value
        beq @txt
        lda c_type
        cmp #4
        bcs @yn
        ldx #0                  ; numbers as they are; money with a $
        cmp #2                  ; first; dates up to the T
        bne @nd
        lda #'$'
        sta TMPSTR
        inx
@nd:    ldy #0
@cv:    lda c_val,y
        beq @ce
        cmp #'T'
        bne @cs
        lda c_type
        cmp #3
        beq @ce
        lda #'T'
@cs:    sta TMPSTR,x
        inx
        iny
        cpy #31
        bcc @cv
@ce:    lda #0
        sta TMPSTR,x
        jmp @txt
@yn:    lda c_val               ; booleans: Yes or No
        cmp #'t'
        beq @yes
        lda #'N'
        sta TMPSTR
        lda #'o'
        sta TMPSTR+1
        lda #0
        sta TMPSTR+2
        jmp @txt
@yes:   lda #'Y'
        sta TMPSTR
        lda #'e'
        sta TMPSTR+1
        lda #'s'
        sta TMPSTR+2
        lda #0
        sta TMPSTR+3
@txt:   lda TMPSTR              ; empty: just count the columns
        bne @put
        clc
        lda r_pend
        adc c_rep
        bcc @pe
        lda #255
@pe:    sta r_pend
        jmp cell_reset
@put:   lda r_col               ; up to 63 columns
        clc
        adc r_pend
        bcs @full
        cmp #63
        bcs @full
@pc:    lda r_pend              ; commas for the empty ones before it
        beq @val
        jsr @comma
        dec r_pend
        jmp @pc
@val:   jsr @comma
        lda #'"'
        jsr rb_put
        ldx #0
@vl:    lda TMPSTR,x
        beq @vq
        stx x_vx
        jsr rb_put
        ldx x_vx
        inx
        bne @vl
@vq:    lda #'"'
        jsr rb_put
        inc r_any
        dec c_rep
        beq @vd
        lda r_col
        cmp #63
        bcc @val
@vd:
@full:  jmp cell_reset
@comma: lda r_col               ; a comma before every column but the first
        beq @c0
        lda #','
        jsr rb_put
@c0:    inc r_col
        rts

; rb_put: A -> the row's line (ROWBUF)
rb_put: ldx rowlen+1
        cpx #>ROWMAX
        bcc @ok
        ldx rowlen
        cpx #<ROWMAX
        bcs @d
@ok:    pha
        clc
        lda #<ROWBUF
        adc rowlen
        sta rq
        lda #>ROWBUF
        adc rowlen+1
        sta rq+1
        pla
        ldy #0
        sta (rq),y
        inc rowlen
        bne @d
        inc rowlen+1
@d:     rts

; row_end: the row's line (r_rep times) -> RETRODB.TMP
row_end:
        lda r_sum               ; a totals row
        bne @d
        lda r_any
        beq @d                  ; nothing in it
        lda #$0D
        jsr rb_put
        lda #$0A
        jsr rb_put
        lda r_rep
        bne @w
        inc r_rep
@w:     lda x_rows
        cmp #255
        bcs @full
        lda rowlen
        sta tw_len
        lda rowlen+1
        sta tw_len+1
        lda x_werr
        bne @d
        MLICALL $CB, twrite_p
        bcc @ok
        sta x_werr
        inc x_done
        rts
@ok:    inc x_rows
        dec r_rep
        bne @w
@d:     rts
@full:  inc x_done              ; 255 rows: enough
        rts

        .segment "OV2BSS"
x_vars:
r_sum:   .res 1
fz_y:    .res 1
x_st:    .res 1
x_nlen:  .res 1
x_alen:  .res 1
x_vlen:  .res 1
x_close: .res 1
x_self:  .res 1
x_quote: .res 1
x_tag:   .res 1
x_ti:    .res 1
x_eret:  .res 1
x_elen:  .res 1
x_done:  .res 1
x_intab: .res 1
x_incell: .res 1
x_inp:   .res 1
x_pcount: .res 1
x_rows:  .res 1
x_werr:  .res 1
r_rep:   .res 1
r_col:   .res 1
r_pend:  .res 1
r_any:   .res 1
c_rep:   .res 1
c_type:  .res 1
c_tlen:  .res 1
s_n:     .res 1
xv_end:
x_vx:    .res 1
xb:      .res 1
x_nm:    .res 32
x_an:    .res 32
x_eb:    .res 8
c_val:   .res 32
rowlen:  .res 2
ierr:    .res 1
zmeth:   .res 1
zleft:   .res 3
fz_n:    .res 1
fx_i:    .res 1
fx_ok:   .res 1
fx_ents: .res 2
fx_skip: .res 2
bb:      .res 1
bc:      .res 1
gb_x:    .res 1
v:       .res 2
m:       .res 2
i_last:  .res 1
i_n:     .res 2
i_tot:   .res 2
i_rl:    .res 1
i_rc:    .res 1
i_len:   .res 2
i_dist:  .res 2
nlen:    .res 2
ndist:   .res 1
ncode:   .res 1
c_n:     .res 2
c_i:     .res 2
c_t:     .res 2
c_cnt:   .res 2
c_sym:   .res 2
d_code:  .res 2
d_first: .res 2
d_index: .res 2
d_t:     .res 2
d_y:     .res 1
d_cnt:   .res 2
w_lo:    .res 1
w_hi:    .res 2
s_lo:    .res 1
s_hi:    .res 2
f_hi:    .res 2
OFFS:    .res 32
LCNT:    .res 32
DCNT:    .res 32
LSYM:    .res 2*288
DSYM:    .res 2*32
LENS:    .res 320
