; ---------------------------------------------------------------
; Mouse Calc import / export
;
; Mouse Calc 1.1 (Version Soft) sheets are ProDOS files of type $F8:
;   $883-byte program-state header, max row, max column, then cell
;   records sorted by column then row:  row, col, type, body..., $FF
;   type: $80 = number, $40 = formula, low nibble = display format
;   text body = ASCII | $80;  number = exponent byte then BCD pairs,
;   value = 0.pairs * 100^((e & $3F) - $1F), e bit $40 = negative
;   formula = type $C0+fmt, cached value, $FE, tokens
;
; Export writes the records shown in the list: row 1 holds the field
; names, each record is a row, and a Total row adds up every Number and
; Money column with a live SUM.  Import matches the row-1 headings with
; the field names; into a database with no form yet, it makes a field
; from each heading.
; ---------------------------------------------------------------
MC_HDRLEN = $883
MC_WA    = $29          ; column widths (two copies) and positions
MC_WB    = $68
MC_PA    = $A7
MAXDIR   = 14

        .segment "LCODE"
mchdr:  .incbin "../build/mchdr.pk"
mchdr_end:

s_total:   .byte "Total", 0
t_export:  .byte "Export to Mouse Calc", 0
t_import:  .byte "Import from Mouse Calc", 0
s_expl1:   .byte "Save the records in the list as a", 0
s_expl2:   .byte "Mouse Calc sheet in this folder:", 0
s_expname: .byte "Name:", 0
nd_export: .word t_export, s_expl1, s_expl2, b_export, EXPNAME
b_export:  .byte "Export", 0
b_import:  .byte "Import", 0
b_replace: .byte "Replace", 0
b_add:     .byte "Add", 0
b_create:  .byte "Create", 0
s_badname: .byte "A ProDOS name starts with a letter|"
           .byte "and has up to 15 letters, digits|"
           .byte "and periods.", 0
s_notmc:   .byte "That name belongs to a file that|"
           .byte "is not a Mouse Calc sheet. Please|"
           .byte "choose another name.", 0
s_exists:  .byte "A Mouse Calc sheet with that name|"
           .byte "already exists. Replace it?", 0
s_expok1:  .byte "Exported ", 0
s_expok2:  .byte " records to|", 0
s_expok3:  .byte "||Open it in Mouse Calc.", 0
s_nofiles: .byte "There are no Mouse Calc sheets in|"
           .byte "this folder. Copy one next to|"
           .byte "MOUSEDB.SYSTEM and try again.", 0
s_impq1:   .byte "Add the sheet's rows to this|"
           .byte "database, or replace its records|"
           .byte "with them? (Revert to Saved brings|"
           .byte "back the saved database.)", 0
s_impq2:   .byte "Import the sheet's rows into|"
           .byte "this database?", 0
s_impq3a:  .byte "Make a new database from this|"
           .byte "sheet? Its ", 0
s_impq3b:  .byte " columns become|fields, and its rows records.", 0
s_impok1:  .byte "Imported ", 0
s_impok2:  .byte " records.", 0
s_impover: .byte "|Some rows did not fit in memory.", 0
s_impok3:  .byte "||Choose Save to keep them.", 0
s_nomatch2: .byte "None of the headings in row 1 of|"
           .byte "that sheet match the fields of this|"
           .byte "database. Nothing was changed.", 0
s_nohead:  .byte "Row 1 of that sheet has no|"
           .byte "headings to make fields from.|"
           .byte "Nothing was changed.", 0
s_imperr:  .byte "Could not read the sheet.||", 0
s_experr:  .byte "Could not export the sheet.||", 0
s_pickh:   .byte "Mouse Calc sheets in this folder:", 0
s_mcext:   .byte ".MC", 0
s_dbnm:    .byte "DATABASE", 0
pk_import: .word t_import, s_pickh, b_import

al_badname: .word t_export, s_badname
            .byte 1
            .word b_ok
al_notmc:   .word t_export, s_notmc
            .byte 1
            .word b_ok
al_exists:  .word t_export, s_exists
            .byte 2
            .word b_replace, b_cancel
al_expmsg:  .word t_export, MSGBUF
            .byte 1
            .word b_ok
al_nofiles: .word t_import, s_nofiles
            .byte 1
            .word b_ok
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

        .segment "LCODE"
EXPNAME:   .byte 0
           .res 15
mcreate_p: .byte 7
           .word mc_path
           .byte $C3, $F8
           .word $0000
           .byte $01
           .word 0, 0
mopen_p:   .byte 3
           .word mc_path
           .word FILEBUF
mo_ref:    .byte 0
mgfi_p:    .byte $0A
           .word mc_path
           .byte 0
mgfi_type: .byte 0
           .res 13
mwrite_p:  .byte 4
mw_ref:    .byte 0
           .word OBUF
mw_len:    .word 0
           .word 0
mread_p:   .byte 4
mr_ref:    .byte 0
mr_buf:    .word INBUF
mr_req:    .word 255
mr_trans:  .word 0
mclose_p:  .byte 1
mc_ref:    .byte 0
mseteof_p: .byte 2
mse_ref:   .byte 0
           .byte 0, 0, 0
sd_skip:   .byte 0
mark_p:    .byte 2, 0, 0, 0, 0

        .segment "LCODE"

msetrefs:
        lda mo_ref
        sta mw_ref
        sta mr_ref
        sta mc_ref
        sta mse_ref
        rts

; ---------------------------------------------------------------
; output buffer
; ---------------------------------------------------------------
ob_put: stx ob_x
        ldx oblen
        sta OBUF,x
        inx
        stx oblen
        cpx #255
        bne @r
        pha
        jsr ob_flush
        pla
@r:     ldx ob_x
        rts

ob_flush:
        lda oblen
        beq @d
        sta mw_len
        lda #0
        sta mw_len+1
        sta oblen
        lda ob_err
        bne @d
        MLICALL $CB, mwrite_p
        bcc @d
        sta ob_err
@d:     rts

; ---------------------------------------------------------------
; export
; ---------------------------------------------------------------
; expdefault: EXPNAME = the database's name (up to 12 letters) + ".MC"
expdefault:
        ldx #0
        lda named
        beq @un
        ldy #0
@c:     cpy pathname
        beq @e
        cpy #12
        beq @e
        lda pathname+1,y
        cmp #'.'                ; stop at a period: "ADDR.BOOK" -> ADDR.MC
        beq @e
        sta EXPNAME+1,y
        iny
        bne @c
@un:    ldy #0
@u:     lda s_dbnm,y
        beq @e
        sta EXPNAME+1,y
        iny
        bne @u
@e:     ldx #0
@x:     lda s_mcext,x
        beq @d
        sta EXPNAME+1,y
        iny
        inx
        bne @x
@d:     sty EXPNAME
        rts

cmd_export:
        lda #2
        sta redraw
        lda nfields
        bne @f
        rts
@f:     jsr expdefault
@dlg:   lda #<nd_export
        ldy #>nd_export
        jsr namedialog
        bcc @go
        rts
@go:    ; validate the name: letter first, then letters, digits, periods
        lda EXPNAME
        beq @bad
        lda EXPNAME+1
        cmp #'A'
        bcc @bad
        cmp #'Z'+1
        bcs @bad
        jmp @named
@bad:   lda #<al_badname
        ldy #>al_badname
        jsr alert
        jmp @dlg
@named: ; never let an export take MouseDB's own file names
        LDAY EXPNAME
        jsr setp1
        LDAY s_lastnm
        jsr setp2
        jsr namecmp
        beq @nmc0
        LDAY tmpname
        jsr setp2
        jsr namecmp
        beq @nmc0
        LDAY s_sysnm
        jsr setp2
        jsr namecmp
        bne @cpn
@nmc0:  jmp @nmc
@cpn:   ; mc_path = EXPNAME (relative to the MouseDB folder)
        ldx EXPNAME
@cp:    lda EXPNAME,x
        sta mc_path,x
        dex
        bpl @cp
        MLICALL $C0, mcreate_p
        bcc @open
        cmp #$47
        beq @dup
        jmp experror
@dup:   MLICALL $C4, mgfi_p
        bcs @nmc
        lda mgfi_type
        cmp #$F8
        beq @ask
@nmc:   lda #<al_notmc
        ldy #>al_notmc
        jsr alert
        jmp @dlg
@ask:   lda #<al_exists
        ldy #>al_exists
        jsr alert
        cmp #0
        beq @open
        rts
@open:  lda #<s_exporting
        ldy #>s_exporting
        jsr statusmsg
        MLICALL $C8, mopen_p
        bcc @o2
        jmp experror
@o2:    jsr msetrefs
        MLICALL $D0, mseteof_p
        bcc @o3
        pha
        MLICALL $CC, mclose_p
        pla
        jmp experror
@o3:    lda #0
        sta oblen
        sta ob_err
        jsr mcwidths
        jsr wr_mchdr
        ; max row, max column
        jsr hasnum              ; a Total row?
        lda vcount
        bcc @nt
        clc
        adc #2
@nt:    clc
        adc #1
        jsr ob_put
        lda nfields
        jsr ob_put
        ; the "Total" label goes in the first Text column
        lda #$FF
        sta ex_tl
        jsr hasnum
        bcc @nl
        ldx #0
@tl:    cpx nfields
        bcs @nl
        lda fkind,x
        cmp #K_TEXT
        beq @tf
        inx
        bne @tl
@tf:    stx ex_tl
@nl:    ; cells, column by column
        lda #0
        sta ex_col
        lda #1
        sta f2t_mode
@col:   lda #1
        sta c_row
        ldx ex_col
        jsr fnameptr
        jsr fld2tmp
        jsr wr_texttmp
        lda #0
        sta ex_i
@row:   lda ex_i
        cmp vcount
        bcs @tot
        tax
        lda VIEW,x
        ldx ex_col
        jsr recgetf
        lda ex_i
        clc
        adc #2
        sta c_row
        jsr wr_field
        inc ex_i
        jmp @row
@tot:   jsr hasnum
        bcc @ncol
        lda vcount
        clc
        adc #3
        sta c_row
        lda ex_col
        cmp ex_tl
        bne @t8
        lda #<s_total
        ldy #>s_total
        jsr strtmp
        jsr wr_texttmp
        jmp @ncol
@t8:    ldx ex_col
        lda fkind,x
        cmp ex_tk
        bne @ncol
        jsr wr_sum
@ncol:  inc ex_col
        lda ex_col
        cmp nfields
        jne @col
        lda #0
        sta f2t_mode
        jsr ob_flush
        MLICALL $CC, mclose_p
        bcs @cerr
        lda ob_err
        beq @ok
@cerr:  lda ob_err
        jmp experror
@ok:    jsr mb_reset
        lda #<s_expok1
        ldy #>s_expok1
        jsr mb_str
        lda vcount
        jsr mb_num8
        lda #<s_expok2
        ldy #>s_expok2
        jsr mb_str
        jsr mb_prefix
        ldx #0
@nm:    cpx EXPNAME
        beq @nmd
        lda EXPNAME+1,x
        stx ex_i
        jsr mb_char
        ldx ex_i
        inx
        bne @nm
@nmd:   lda #<s_expok3
        ldy #>s_expok3
        jsr mb_str
        lda #<al_expmsg
        ldy #>al_expmsg
        jmp alert

; hasnum: carry set if the form has a Number or Money field.  ex_tk =
; the kind the Total row adds up: Money when there is any (so a Year
; number is not summed beside the dollars), otherwise Number.
hasnum: lda #K_NUMBER
        sta ex_tk
        ldx #0
@m:     cpx nfields
        bcs @h
        lda fkind,x
        cmp #K_MONEY
        beq @mm
        inx
        bne @m
@mm:    sta ex_tk
@h:     ldx #0
@l:     cpx nfields
        bcs @no
        lda fkind,x
        jsr isnumk
        bcs @d
        inx
        bne @l
@no:    clc
@d:     rts

experror:
        pha
        jsr mb_reset
        lda #<s_experr
        ldy #>s_experr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<al_expmsg
        ldy #>al_expmsg
        jmp alert

; mb_prefix: append the current prefix (folder) to MSGBUF
mb_prefix:
        ldx #0
@l:     cpx PREFIXBUF
        beq @d
        lda PREFIXBUF+1,x
        stx mp_x
        jsr mb_char
        ldx mp_x
        inx
        bne @l
@d:     rts

        .segment "LCODE"
s_exporting: .byte "Exporting to Mouse Calc", G_DOTS, 0
        .segment "LCODE"

; mcwidths: MCWID/MCPOS = each column's width byte and screen position
mcwidths:
        lda #3
        sta mw_x
        ldx #1
@c:     stx mw_c
        lda #11                 ; Mouse Calc's own width
        cpx nfields
        beq @f
        bcs @have
@f:     dex                     ; field X-1
        lda fkind,x
        cmp #K_TEXT
        beq @txt
        cmp #K_DATE
        beq @txt
        tay
        lda mcw_kind,y
        jmp @name
@txt:   lda flen,x
        clc
        adc #1
        cmp #40
        bcc @name
        lda #40
@name:  sta mw_w                ; at least as wide as the heading
        jsr fnameptr
        ldy #0
        lda (ptr1),y
        clc
        adc #1
        cmp mw_w
        bcc @nw
        sta mw_w
@nw:    lda mw_w
        cmp #4
        bcs @have
        lda #4
@have:  sta mw_w
        ldx mw_c
        cmp #11
        bne @set
        lda #$FF
@set:   sta MCWID,x
        lda mw_x                ; on screen while it fits (80 columns)
        beq @off
        clc
        adc mw_w
        cmp #$50
        bcs @off
        lda mw_x
        sta MCPOS,x
        clc
        adc mw_w
        sta mw_x
        jmp @nx
@off:   lda #$FF
        sta MCPOS,x
        lda #0
        sta mw_x
@nx:    inx
        cpx #63
        jne @c
        rts

        .segment "LCODE"
;                 -  Text Num Money Date Yes/No
mcw_kind: .byte  11, 11,  11, 13,   11,  6
        .segment "LCODE"

; wr_mchdr: unpack the PackBits header into the output, putting in the
; column widths and positions
wr_mchdr:
        lda #<mchdr
        sta ptr2
        lda #>mchdr
        sta ptr2+1
        lda #0
        sta hc
        sta hc+1
@n:     lda ptr2
        cmp #<mchdr_end
        lda ptr2+1
        sbc #>mchdr_end
        bcs @d
        ldy #0
        lda (ptr2),y
        jsr @inc
        cmp #$80
        bcs @rep
        tax
        inx
        stx wh_n
@lit:   ldy #0
        lda (ptr2),y
        jsr @inc
        jsr hdrput
        dec wh_n
        bne @lit
        beq @n
@rep:   eor #$FF
        clc
        adc #2
        sta wh_n
        ldy #0
        lda (ptr2),y
        jsr @inc
        sta wh_b
@r:     lda wh_b
        jsr hdrput
        dec wh_n
        bne @r
        beq @n
@d:     rts
@inc:   inc ptr2
        bne @i
        inc ptr2+1
@i:     rts

; hdrput: header byte A at offset hc (widths and positions replaced)
hdrput: ldx hc+1
        bne @put
        ldx hc
        cpx #MC_WA+1
        bcc @put
        cpx #MC_WA+63
        bcc @w
        cpx #MC_WB+1
        bcc @put
        cpx #MC_WB+63
        bcc @wb
        cpx #MC_PA+1
        bcc @put
        cpx #MC_PA+63
        bcs @put
        txa                     ; position of column hc - MC_PA
        sec
        sbc #MC_PA
        tax
        lda MCPOS,x
        jmp @put
@wb:    txa
        sec
        sbc #MC_WB
        tax
        lda MCWID,x
        jmp @put
@w:     txa
        sec
        sbc #MC_WA
        tax
        lda MCWID,x
@put:   jsr ob_put
        inc hc
        bne @d
        inc hc+1
@d:     rts

; wr_texttmp: text cell from TMPSTR (nothing if empty)
wr_texttmp:
        lda TMPSTR
        beq @d
        lda #0
        jsr cell_begin
        ldy #0
@l:     lda TMPSTR,y
        beq @e
        ora #$80
        jsr ob_put
        iny
        bne @l
@e:     jmp cell_end
@d:     rts

; wr_field: field ex_col of record rp, as a cell in row c_row
wr_field:
        ldx ex_col
        jsr getfk
        lda fk_k
        jsr isnumk
        bcs @num
        jsr f2t                 ; Text, Date, Yes/No: text
        jmp wr_texttmp
@num:   jsr fld2num
        bcs @d                  ; blank: no cell
        lda fn_neg
        sta en_neg
        lda #$80                ; Number: normal format
        ldx fk_k
        cpx #K_MONEY
        bne @n1
        lda #$88                ; Money: $X,XXX.XX
@n1:    jsr cell_begin
        jsr fmtnum
        lda #0
        ldx fk_k
        cpx #K_MONEY
        bne @n2
        lda #2
@n2:    sta en_frac
        jsr enc_dec
        jmp cell_end
@d:     rts

; wr_sum: formula cell  +SUM(X2...Xn) with the cached total
wr_sum: ldx ex_col
        lda fkind,x
        sta ws_k
        lda #$C0
        ldx ws_k
        cpx #K_MONEY
        bne @f
        lda #$C8
@f:     jsr cell_begin
        lda ex_col
        sta st_f
        jsr viewsum             ; sum40 = the total
        ldx #4
@c:     lda sum40,x
        sta num,x
        dex
        bpl @c
        lda #0
        sta en_neg
        lda num+4
        bpl @p
        jsr negnum
        inc en_neg
@p:     jsr fmtnum
        lda #0
        ldx ws_k
        cpx #K_MONEY
        bne @fr
        lda #2
@fr:    sta en_frac
        jsr enc_dec
        lda #$FE
        jsr ob_put
        lda #$E0                ; +
        jsr ob_put
        lda #$C1                ; SUM
        jsr ob_put
        lda #$ED                ; (
        jsr ob_put
        ldx ex_col
        inx
        txa
        ora #$80                ; column
        pha
        jsr ob_put
        lda #2
        jsr ob_put
        lda #$EC                ; ...
        jsr ob_put
        pla
        jsr ob_put
        ldx vcount
        inx
        txa
        jsr ob_put
        lda #$EE                ; )
        jsr ob_put
        jmp cell_end

; cell_begin: A = type byte; row c_row, column ex_col+1
cell_begin:
        pha
        lda c_row
        jsr ob_put
        ldx ex_col
        inx
        txa
        jsr ob_put
        pla
        jmp ob_put
cell_end:
        lda #$FF
        jmp ob_put

; wr_textz: text cell from zero-terminated string A/Y
wr_textz:
        sta ptr3
        sty ptr3+1
        lda #0
        jsr cell_begin
        ldy #0
@l:     lda (ptr3),y
        beq @d
        ora #$80
        jsr ob_put
        iny
        bne @l
@d:     jmp cell_end

; enc_dec: numbuf = decimal digits (zero-terminated); the last en_frac
; of them are the fraction.  Writes exponent byte + BCD pairs.
enc_dec:
        ldx #0
@sk:    lda numbuf,x            ; skip leading zeros
        cmp #'0'
        bne @nz
        inx
        bne @sk
@nz:    stx en_s
        lda numbuf,x
        bne @len
        lda #0                  ; zero
        jmp ob_put
@len:   ldy #0
@l:     lda numbuf,x
        beq @gl
        inx
        iny
        bne @l
@gl:    ; Y = significant digit count; integer digits = Y - en_frac
        tya
        sec
        sbc en_frac
        bcs @ip
        ; fewer digits than the fraction: pad with leading zeros
        eor #$FF
        clc
        adc #1                  ; A = zeros needed
        sta en_pad
        lda #0
        sta en_int
        jmp @build
@ip:    sta en_int
        lda #0
        sta en_pad
        lda en_int
        lsr a
        bcc @build
        inc en_pad              ; odd integer part: one leading zero
        inc en_int
@build: ldy #0
@pz:    cpy en_pad
        beq @cpd
        lda #'0'
        sta ENBUF,y
        iny
        bne @pz
@cpd:   ldx en_s
@cp:    lda numbuf,x
        beq @cpe
        sta ENBUF,y
        inx
        iny
        bne @cp
@cpe:   tya                     ; make the digit count even
        lsr a
        bcc @ev
        lda #'0'
        sta ENBUF,y
        iny
@ev:    sty en_n
        ; drop trailing "00" pairs
@tr:    lda en_n
        cmp #2
        bcc @emit
        tax
        lda ENBUF-1,x
        cmp #'0'
        bne @emit
        lda ENBUF-2,x
        cmp #'0'
        bne @emit
        dec en_n
        dec en_n
        jmp @tr
@emit:  lda en_int
        lsr a
        clc
        adc #$1F
        ldx en_neg
        beq @pos
        ora #$40                ; negative
@pos:   jsr ob_put
        ldy #0
@ep:    cpy en_n
        bcs @ed
        lda ENBUF,y
        and #$0F
        asl a
        asl a
        asl a
        asl a
        sta en_b
        lda ENBUF+1,y
        and #$0F
        ora en_b
        jsr ob_put
        iny
        iny
        bne @ep
@ed:    rts

; namedialog: A/Y -> spec (.word title, line1, line2, button, buffer)
; asks for a ProDOS name.  Carry clear = OK.
namedialog:
        sta ptr1
        sty ptr1+1
        ldy #9
@cp:    lda (ptr1),y
        sta nd_title,y
        dey
        bpl @cp
        jsr hidecursor
        lda #20
        sta wx
        lda #7
        sta wy
        lda #40
        sta ww
        lda #8
        sta wh
        lda nd_title
        ldy nd_title+1
        jsr drawwin
        POS 22, 10
        lda nd_l1
        ldy nd_l1+1
        jsr prt
        POS 22, 11
        lda nd_l2
        ldy nd_l2+1
        jsr prt
        POS 22, 13
        PRT s_expname
        POS 42, 15
        lda nd_btn
        ldy nd_btn+1
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
        beq @ok
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
        cmp #42
        bcc @loop
        cmp #50
        bcc @ok
        cmp #51
        bcc @loop
        cmp #59
        bcs @loop
@x:     sec
        rts
@ok:    clc
        rts
@setf:  lda nd_buf
        sta ptr2
        lda nd_buf+1
        sta ptr2+1
        lda #15
        sta tf_max
        lda #3
        sta tf_filt
        lda #28
        sta tf_col
        lda #13
        sta tf_row
        rts

; ---------------------------------------------------------------
; import
; ---------------------------------------------------------------
cmd_import:
        lda #2
        sta redraw
        lda #$F8
        sta sd_type
        jsr scandir
        bcc @sc
        jmp imperror
@sc:    lda ndir
        bne @pick
        lda #<al_nofiles
        ldy #>al_nofiles
        jmp alert
@pick:  lda #<pk_import
        ldy #>pk_import
        jsr setpick
        jsr pickdialog
        bcc @chosen
        rts
@chosen:
        ; mc_path = chosen name
        jsr dselptr
        ldy #0
        lda (ptr1),y
        tay
@cn:    lda (ptr1),y
        sta mc_path,y
        dey
        bpl @cn
        lda #<s_importing
        ldy #>s_importing
        jsr statusmsg
        MLICALL $C8, mopen_p
        bcc @o
        jmp imperror
@o:     jsr msetrefs
        lda #<INBUF
        sta mr_buf
        lda #>INBUF
        sta mr_buf+1
        lda #255
        sta mr_req
        lda #0
        sta mr_req+1
        sta ib_len
        sta ib_pos
        ; pass 1: the headings, and what kind of data each column holds
        jsr skiphdr
        bcs @rderr
        lda #$FF
        ldx #63
@cm:    sta colmap,x
        dex
        bpl @cm
        lda #0
        ldx #31
@rs:    sta ROWSKIP,x
        dex
        bpl @rs
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
        sta im_new              ; 0: make the form from the sheet
@p1:    jsr readcell
        bcs @p1d
        jsr scancell
        jmp @p1
@p1d:   ldx #63                 ; any column in use?
@fn:    lda colmap,x
        cmp #$FF
        bne @have
        dex
        bpl @fn
        MLICALL $CC, mclose_p
        lda #<al_nomatch2
        ldy #>al_nomatch2
        ldx im_new
        bne @nm
        lda #<al_nohead
        ldy #>al_nohead
@nm:    jmp alert
@rderr: pha
        MLICALL $CC, mclose_p
        pla
        jmp imperror
@have:  ; ask
        lda im_new
        bne @old
        jsr mb_reset            ; a new form
        lda #<s_impq3a
        ldy #>s_impq3a
        jsr mb_str
        lda dn
        jsr mb_num8
        lda #<s_impq3b
        ldy #>s_impq3b
        jsr mb_str
        lda #<al_impq3
        ldy #>al_impq3
        jsr alert
        cmp #0
        bne @cancel
        jsr newform
        lda #0
        sta im_base
        jmp @go
@old:   lda count
        bne @addq
        lda #<al_impq2
        ldy #>al_impq2
        jsr alert
        cmp #0
        bne @cancel
        lda #0
        sta im_base
        jmp @go
@addq:  lda #<al_impq1
        ldy #>al_impq1
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
        lda #0
        sta mark_p+2
        sta mark_p+3
        sta mark_p+4
        lda mo_ref
        sta mark_p+1
        MLICALL $CE, mark_p
        bcs @rderr2
        lda #0
        sta ib_len
        sta ib_pos
        jsr skiphdr
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
        jsr imperror
        jmp @fin
@p2d:   MLICALL $CC, mclose_p
@fin:   lda im_hw
        sta count
        jsr compact
        lda #0
        sta selactive
        jsr showall
        lda #0
        sta sel
        sta top
        lda #1
        sta dirty
        ; report
        jsr mb_reset
        lda #<s_impok1
        ldy #>s_impok1
        jsr mb_str
        lda count
        sec
        sbc im_base
        jsr mb_num8
        lda #<s_impok2
        ldy #>s_impok2
        jsr mb_str
        lda ld_over
        beq @rep
        lda #<s_impover
        ldy #>s_impover
        jsr mb_str
@rep:   lda #<s_impok3
        ldy #>s_impok3
        jsr mb_str
        jsr drawall
        lda #<al_impmsg
        ldy #>al_impmsg
        jmp alert

imperror:
        pha
        jsr mb_reset
        lda #<s_imperr
        ldy #>s_imperr
        jsr mb_str
        pla
        jsr mb_errtext
        lda #<al_impmsg
        ldy #>al_impmsg
        jmp alert

        .segment "LCODE"
s_importing: .byte "Importing from Mouse Calc", G_DOTS, 0
        .segment "LCODE"

; scancell: pass 1.  Row-1 headings choose the columns; a +SUM formula
; marks its row as a total row to leave out; data cells tell a new form
; what kind each field is.
scancell:
        lda c_c
        cmp #64
        jcs @d
        lda c_r
        jeq @d
        cmp #1
        jeq @head
        lda c_t                 ; a +SUM( formula?
        and #$C0
        cmp #$C0
        bne @data
        ldx #0
@ff:    cpx c_len
        bcs @data
        lda CELLBUF,x
        inx
        cmp #$FE
        bne @ff
        lda CELLBUF,x
        cmp #$E0
        bne @data
        lda CELLBUF+1,x
        cmp #$C1
        bne @data
        jsr skipbit             ; ROWSKIP |= this row
        ora ROWSKIP,x
        sta ROWSKIP,x
        rts
@data:  lda im_new
        bne @d
        ldx c_c                 ; statistics for a new field
        lda colmap,x
        cmp #$FF
        beq @d
        tax
        lda c_t
        bmi @num
        stx im_x
        jsr cell2tmp            ; text: how long?
        jsr trimtmp
        ldx #0
@ln:    lda TMPSTR,x
        beq @lg
        inx
        bne @ln
@lg:    txa
        beq @d                  ; empty text doesn't count
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
@num:   stx im_x
        lda c_len               ; ERROR/NA/TRUE/FALSE: ignore
        beq @d
        lda CELLBUF
        cmp #$80
        beq @d
        inc im_num,x
        lda c_t
        and #$0F
        cmp #6                  ; $X,XXX
        beq @mon
        cmp #8                  ; $X,XXX.XX
        bne @fr
@mon:   lda #1
        sta im_money,x
@fr:    jsr bcd2text            ; a fraction?
        ldx #0
@fl:    lda TMPSTR,x
        beq @fd
        cmp #'.'
        beq @isf
        inx
        bne @fl
@isf:   ldx im_x
        lda #1
        sta im_frac,x
@fd:    ldx im_x                ; as text, how long?
        ldy #0
@nl:    lda TMPSTR,y
        beq @ng
        iny
        bne @nl
@ng:    tya
        cmp im_len,x
        bcc @nd
        sta im_len,x
@nd:    rts
@head:  lda c_t                 ; headings are text
        bmi @d
        jsr cell2tmp
        jsr trimtmp
        lda TMPSTR
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

; skipbit: X = byte, A = bit of row c_r in ROWSKIP
skipbit:
        lda c_r
        and #7
        tax
        lda bits8,x
        pha
        lda c_r
        lsr a
        lsr a
        lsr a
        tax
        pla
        rts

        .segment "LCODE"
bits8:  .byte 1, 2, 4, 8, 16, 32, 64, 128
        .segment "LCODE"

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
@size:  jsr dsize               ; too long?  shorten the longest Text
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
        lda c_c
        cmp #64
        bcs @d
        tax
        lda colmap,x
        cmp #$FF
        beq @d
        sta sc_f
        jsr skipbit             ; a total row?
        and ROWSKIP,x
        bne @d
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
@put:   lda c_t                 ; the cell as text
        bmi @nm
        jsr cell2tmp
        jmp @t
@nm:    jsr bcd2text
@t:     lda sc_i
        ldx sc_f
        jsr recgetf
        ldx sc_f
        jsr getfk
        jsr t2f
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

; compact: from im_base on, drop records that are blank or came from a
; total row, keeping the rest in sheet order
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
        lda cp_i                ; total row?
        sec
        sbc im_base
        clc
        adc #2
        sta c_r
        jsr skipbit
        and ROWSKIP,x
        bne @n
        ; swap slot cp_i into position cp_o
        ldx cp_i
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

; getbyte: next file byte in A; carry set at end of file / error
getbyte:
        ldx ib_pos
        cpx ib_len
        bcc @have
        MLICALL $CA, mread_p
        bcs @e
        lda mr_trans
        beq @eof
        sta ib_len
        ldx #0
        stx ib_pos
@have:  lda INBUF,x
        inc ib_pos
        clc
        rts
@eof:   lda #$4C
@e:     sec
        rts

; skiphdr: skip the $883-byte header and the max row/column bytes
skiphdr:
        lda #<(MC_HDRLEN+2)
        sta sh_n
        lda #>(MC_HDRLEN+2)
        sta sh_n+1
@l:     jsr getbyte
        bcs @d
        lda sh_n
        bne @dl
        dec sh_n+1
@dl:    dec sh_n
        lda sh_n
        ora sh_n+1
        bne @l
        clc
@d:     rts

; readcell: next cell into c_r, c_c, c_t and CELLBUF (c_len bytes).
; carry set at end of file.
readcell:
        jsr getbyte
        bcs @d
        sta c_r
        jsr getbyte
        bcs @d
        sta c_c
        jsr getbyte
        bcs @d
        sta c_t
        lda #0
        sta c_len
@b:     jsr getbyte
        bcs @end
        cmp #$FF
        beq @end
        ldx c_len
        cpx #255
        beq @b
        sta CELLBUF,x
        inc c_len
        jmp @b
@end:   clc
@d:     rts

; cell2tmp: cell contents as text in TMPSTR (zero-terminated)
cell2tmp:
        lda c_t
        bmi bcd2text
        ldx #0
        ldy #0
@l:     cpx c_len
        beq @d
        cpy #62
        bcs @d
        lda CELLBUF,x
        and #$7F
        cmp #$20
        bcc @n
        cmp #'"'
        bne @s
        lda #$27                ; keep quotes out of the file
@s:     sta TMPSTR,y
        iny
@n:     inx
        bne @l
@d:     lda #0
        sta TMPSTR,y
        rts

; bcd2text: number cell -> decimal text in TMPSTR
bcd2text:
        lda #0
        sta bt_o
        lda c_len
        jeq @out
        lda CELLBUF
        cmp #$80
        jeq @out                ; ERROR / NA / TRUE / FALSE
        sta bt_e
        and #$40
        beq @pos
        lda #'-'
        jsr @put
@pos:   jsr bcdpairs            ; DIGITS = digit pairs, bt_nd digits
        lda bt_e
        and #$3F
        sec
        sbc #$1F                ; integer pairs (signed)
        beq @small
        bmi @small
        cmp #11
        jcs @big
        asl a
        sta bt_ki               ; integer digits
@pad:   ldx bt_nd               ; pad stored digits out to the integer part
        cpx bt_ki
        bcs @ip
        lda #'0'
        sta DIGITS,x
        inc bt_nd
        bne @pad
@ip:    ldx #0                  ; skip leading zeros, keep at least one digit
@lz:    inx
        cpx bt_ki
        bcs @lz1
        lda DIGITS-1,x
        cmp #'0'
        beq @lz
@lz1:   dex
@ic:    cpx bt_ki
        bcs @ie
        lda DIGITS,x
        jsr @put
        inx
        bne @ic
@ie:    lda bt_ki
        sta bt_fs
        jmp @frac
@small: ; value below 1: "0", fraction = (-2k) zeros + digits
        eor #$FF
        clc
        adc #1
        asl a
        cmp #20
        bcs @zero
        sta bt_pad
        jsr padfrac
        lda #'0'
        jsr @put
        lda #0
        sta bt_fs
@frac:  lda bt_nd
        sta bt_fe
@tz:    lda bt_fe               ; drop trailing zeros
        cmp bt_fs
        beq @out
        bcc @out
        tax
        lda DIGITS-1,x
        cmp #'0'
        bne @dot
        dec bt_fe
        jmp @tz
@dot:   lda #'.'
        jsr @put
        ldx bt_fs
@fc:    cpx bt_fe
        bcs @out
        lda DIGITS,x
        jsr @put
        inx
        bne @fc
@zero:  lda #'0'
        jsr @put
@out:   ldy bt_o
        lda #0
        sta TMPSTR,y
        rts
@big:   lda #0
        sta bt_o
        jmp @zero
@put:   ldy bt_o
        cpy #40
        bcs @pd
        sta TMPSTR,y
        inc bt_o
@pd:    rts

; bcdpairs: CELLBUF[1..] BCD pairs -> DIGITS (ASCII), bt_nd = count
bcdpairs:
        ldx #1
        lda #0
        sta bt_nd
@l:     cpx c_len
        bcs @d
        lda CELLBUF,x
        cmp #$FE
        beq @d
        cmp #$A0
        bcs @d
        and #$0F
        cmp #10
        bcs @d
        lda CELLBUF,x
        lsr a
        lsr a
        lsr a
        lsr a
        ora #'0'
        stx bp_x
        ldx bt_nd
        cpx #30
        bcs @d
        sta DIGITS,x
        inx
        ldy bp_x
        lda CELLBUF,y
        and #$0F
        ora #'0'
        sta DIGITS,x
        inx
        stx bt_nd
        ldx bp_x
        inx
        bne @l
@d:     rts

; padfrac: shift DIGITS right by bt_pad, filling with '0'
padfrac:
        lda bt_pad
        beq @d
        ldx bt_nd
@s:     dex
        bmi @f
        lda DIGITS,x
        pha
        txa
        clc
        adc bt_pad
        tay
        pla
        sta DIGITS,y
        jmp @s
@f:     ldx #0
        lda #'0'
@z:     cpx bt_pad
        beq @n
        sta DIGITS,x
        inx
        bne @z
@n:     lda bt_nd
        clc
        adc bt_pad
        sta bt_nd
@d:     rts

; ---------------------------------------------------------------
; scandir: DIRNAMES = the files of type sd_type in the current folder.
; For databases ($04) the folder is read a block at a time and each
; block's text files are checked (dbfilter) with the folder closed, so
; other text files never take up places in the list.  sd_more is set
; if there were more than MAXDIR.
; ---------------------------------------------------------------
scandir:
        lda #0
        sta ndir
        sta sd_more
        sta sd_blk
        lda #1                  ; block 0 starts with the folder's header
        sta sd_ent
        ; mc_path = prefix without its trailing slash
        ldx PREFIXBUF
        dex
        stx mc_path
@cp:    lda PREFIXBUF,x
        sta mc_path,x
        dex
        bne @cp
@open:  MLICALL $C8, mopen_p
        bcc @o
        rts
@o:     jsr msetrefs
        lda #<DIRBUF
        sta mr_buf
        lda #>DIRBUF
        sta mr_buf+1
        lda #0
        sta mr_req
        lda #2
        sta mr_req+1
        lda ndir
        sta sd_start
        lda sd_blk              ; read past the blocks already scanned
        sta sd_skip             ; (more dependable than SET_MARK on a folder)
@skp:   lda sd_skip
        beq @blk
        MLICALL $CA, mread_p
        jcs @end
        dec sd_skip
        jmp @skp
@blk:   MLICALL $CA, mread_p
        jcs @end
        lda #<(DIRBUF+4)        ; ptr1 = entry sd_ent
        sta ptr1
        lda #>(DIRBUF+4)
        sta ptr1+1
        ldx sd_ent
        beq @ent
@sk:    clc
        lda ptr1
        adc #$27
        sta ptr1
        bcc @sk1
        inc ptr1+1
@sk1:   dex
        bne @sk
@ent:   ldy #0
        lda (ptr1),y
        and #$F0
        beq @next
        cmp #$40
        bcs @next               ; only seedling/sapling/tree files
        ldy #16
        lda (ptr1),y
        cmp sd_type
        bne @next
        lda ndir
        cmp #MAXDIR
        bcs @full
        asl a
        asl a
        asl a
        asl a
        tax
        ldy #0
        lda (ptr1),y
        and #$0F
        sta DIRNAMES,x
        sta t0
@nc:    inx
        iny
        lda (ptr1),y
        sta DIRNAMES,x
        cpy t0
        bne @nc
        inc ndir
@next:  clc
        lda ptr1
        adc #$27
        sta ptr1
        bcc @nn
        inc ptr1+1
@nn:    inc sd_ent
        lda sd_ent
        cmp #13
        jne @ent
        lda #0                  ; on to the next block
        sta sd_ent
        inc sd_blk
        lda sd_type
        cmp #$04
        jne @blk
        jsr @close              ; inventories: check this block's files
        jsr dbfilter
        jmp @open
@full:  jsr @close              ; the list is full
        lda sd_type
        cmp #$04
        bne @more
        jsr dbfilter           ; room again once non-databases go?
        lda ndir
        cmp #MAXDIR
        jcc @open
@more:  inc sd_more
        clc
        rts
@end:   jsr @close
        clc
        rts
@close: MLICALL $CC, mclose_p
        lda #<INBUF
        sta mr_buf
        lda #>INBUF
        sta mr_buf+1
        rts

; setpick: A/Y -> spec (.word title, heading, button) for pickdialog
setpick:
        sta ptr1
        sty ptr1+1
        ldy #5
@cp:    lda (ptr1),y
        sta pk_title,y
        dey
        bpl @cp
        rts

; pickdialog: choose one of DIRNAMES.  Carry clear = chosen (dsel).
PK_TOP = 6
pickdialog:
        lda #0
        sta dsel
@full:  jsr hidecursor
        lda #20
        sta wx
        lda #1
        sta wy
        lda #40
        sta ww
        lda ndir
        clc
        adc #6
        sta wh
        lda pk_title
        ldy pk_title+1
        jsr drawwin
        POS 22, 4
        lda pk_head
        ldy pk_head+1
        jsr prt
        jsr @list
        lda sd_more             ; more than fit in the list?
        beq @nm
        lda ndir
        clc
        adc #PK_TOP
        sta cy
        lda #22
        sta cx
        PRTS "Only the first 14 are listed."
@nm:    lda ndir
        clc
        adc #PK_TOP+1
        sta pk_btn
        sta cy
        lda #42
        sta cx
        lda pk_btnl
        ldy pk_btnl+1
        ldx #1
        jsr drawbtn
        lda #51
        sta cx
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jsr drawbtn
@loop:  jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        beq @ok
        cmp #$1B
        beq @x
        cmp #$0B
        beq @up
        cmp #$0A
        beq @dn
        jmp @loop
@up:    lda dsel
        beq @loop
        dec dsel
        jsr @list
        jmp @loop
@dn:    ldx dsel
        inx
        cpx ndir
        bcs @loop
        stx dsel
        jsr @list
        jmp @loop
@mouse: lda mrow
        cmp pk_btn
        bne @mrow
        lda mcol
        cmp #42
        bcc @loop
        cmp #50
        bcc @ok
        cmp #51
        bcc @loop
        cmp #59
        bcs @loop
@x:     sec
        rts
@ok:    clc
        rts
@mrow:  sec
        sbc #PK_TOP
        bcc @loop
        cmp ndir
        bcs @loop
        cmp dsel
        beq @ok                 ; click the selected sheet again to import
        sta dsel
        jsr @list
        jmp @loop
@list:  lda #0
        sta pk_i
@lr:    lda pk_i
        cmp ndir
        bcs @ld
        clc
        adc #PK_TOP
        sta cy
        lda #24
        sta cx
        lda #0
        ldx pk_i
        cpx dsel
        bne @li
        lda #1
@li:    sta inv
        jsr space
        lda pk_i
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<DIRNAMES
        sta ptr1
        lda #>DIRNAMES
        adc #0
        sta ptr1+1
        ldx #16
        jsr prtfld
        jsr space
        lda #0
        sta inv
        inc pk_i
        jmp @lr
@ld:    rts

        .segment "BSS"
oblen:   .res 1
ob_err:  .res 1
ob_x:    .res 1
ex_col:  .res 1
ex_i:    .res 1
ex_tl:   .res 1
ex_tk:   .res 1
c_row:   .res 1
wh_n:    .res 1
wh_b:    .res 1
hc:      .res 2
mw_x:    .res 1
mw_c:    .res 1
mw_w:    .res 1
ws_k:    .res 1
MCWID:   .res 63
MCPOS:   .res 63
mp_x:    .res 1
en_frac: .res 1
en_neg:  .res 1
en_s:    .res 1
en_int:  .res 1
en_pad:  .res 1
en_n:    .res 1
en_b:    .res 1
ib_len:  .res 1
ib_pos:  .res 1
sh_n:    .res 2
c_r:     .res 1
c_c:     .res 1
c_t:     .res 1
c_len:   .res 1
im_new:  .res 1
im_base: .res 1
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
bt_e:    .res 1
bt_ki:   .res 1
bt_nd:   .res 1
bt_o:    .res 1
bt_pad:  .res 1
bt_fs:   .res 1
bt_fe:   .res 1
bp_x:    .res 1
sc_f:    .res 1
sc_i:    .res 1
br_x:    .res 1
cp_o:    .res 1
cp_i:    .res 1
ndir:    .res 1
dsel:    .res 1
pk_btn:  .res 1
pk_i:    .res 1
pk_title: .res 2
pk_head: .res 2
pk_btnl: .res 2
sd_type: .res 1
sd_more: .res 1
sd_blk:  .res 1
sd_ent:  .res 1
sd_start: .res 1
nd_title: .res 2
nd_l1:   .res 2
nd_l2:   .res 2
nd_btn:  .res 2
nd_buf:  .res 2
