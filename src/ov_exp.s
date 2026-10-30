; ---------------------------------------------------------------
; Overlay 0: export the records in the list as a CSV or ODS file
;
; CSV: row 1 holds the field names, then one line per record, fields
; separated by commas and lines ending in CR LF.  Text is in double
; quotes; numbers, money (12.50) and whole dates (YYYY-MM-DD) are not.
;
; ODS (OpenDocument spreadsheet): a ZIP file of three members, stored
; without compression: mimetype, META-INF/manifest.xml and content.xml.
; Numbers, money and dates are cells of those types; the field names
; are a bold first row; each column is as wide as its field.
; ---------------------------------------------------------------
zs_p    = sptr                  ; (zero page)

        .segment "OV0"
        jmp exp_main

s_expq:    .byte "Export the records in the list|"
           .byte "as an ODS spreadsheet (LibreOffice,|"
           .byte "Excel, Google Sheets) or as plain|"
           .byte "CSV text?", 0
b_ods:     .byte "ODS", 0
b_csv:     .byte "CSV", 0
al_expq:   .word t_export, s_expq
           .byte 3
           .word b_ods, b_csv, b_cancel
s_expl1:   .byte "Save the records in the list as", 0
s_expl2o:  .byte "an ODS file in this folder:", 0
s_expl2c:  .byte "a CSV file in this folder:", 0
b_export:  .byte "Export", 0
nd_export: .word t_export, s_expl1, s_expl2o, b_export, EXPNAME
s_isdb:    .byte "That name belongs to a database|"
           .byte "or to one of RetroDB's own files.|"
           .byte "Please choose another name.", 0
s_exists:  .byte "A file with that name already|"
           .byte "exists. Replace it?", 0
s_expok1:  .byte "Exported ", 0
s_expok2:  .byte " records to|", 0
s_experr:  .byte "Could not export the file.||", 0
s_exporting: .byte "Exporting", G_DOTS, 0
s_odsext:  .byte ".ODS", 0
s_csvext:  .byte ".CSV", 0
s_dbnm:    .byte "DATABASE", 0
al_badname: .word t_export, s_badname
           .byte 1
           .word b_ok
al_isdb:   .word t_export, s_isdb
           .byte 1
           .word b_ok
al_exists: .word t_export, s_exists
           .byte 2
           .word b_replace, b_cancel
al_expmsg: .word t_export, MSGBUF
           .byte 1
           .word b_ok
; RetroDB's own files: never written over by an export
ownlist:   .word s_lastnm, tmpname, s_sysnm, s_ovlnm, s_tmpnm, s_swpnm, 0

exp_main:
        lda #2
        sta redraw
        lda nfields
        bne @f
        rts
@f:     LDAY al_expq            ; ODS or CSV?
        jsr alert
        cmp #2
        bcc @fmt
        rts
@fmt:   sta ex_csv
        jsr expdefault
        lda #<s_expl2o
        ldy #>s_expl2o
        ldx ex_csv
        beq @l2
        lda #<s_expl2c
        ldy #>s_expl2c
@l2:    sta nd_export+4
        sty nd_export+5
@dlg:   LDAY nd_export
        jsr namedialog
        bcc @go
        rts
@go:    lda EXPNAME             ; a letter first
        beq @bad
        lda EXPNAME+1
        cmp #'A'
        bcc @bad
        cmp #'Z'+1
        bcc @named
@bad:   LDAY al_badname
        jsr alert
        jmp @dlg
@named: jsr isown               ; not one of RetroDB's own files
        bne @cpn
@nmc:   LDAY al_isdb
        jsr alert
        jmp @dlg
@cpn:   ldx EXPNAME             ; mc_path = EXPNAME (in this folder)
@cp:    lda EXPNAME,x
        sta mc_path,x
        dex
        bpl @cp
        lda #$04                ; CSV: a text file; ODS: binary
        ldx ex_csv
        bne @ty
        lda #$06
@ty:    sta mc_type
        MLICALL $C0, mcreate_p
        bcc @open
        cmp #$47
        beq @dup
        jmp experror
@dup:   LDAY EXPNAME            ; a database? (or another text file
        jsr setp1               ; that starts like one)
        jsr isdb
        bcc @nmc
        LDAY al_exists
        jsr alert
        cmp #0
        beq @rep
        rts
@rep:   MLICALL $C1, mdestroy_p ; start afresh (the type may differ)
        bcc @rc
        jmp experror
@rc:    MLICALL $C0, mcreate_p
        bcc @open
        jmp experror
@open:  LDAY s_exporting
        jsr statusmsg
        MLICALL $C8, mopen_p
        bcc @o2
        jmp experror
@o2:    jsr msetrefs
        lda #0
        sta oblen
        sta ob_err
        sta z_on
        ldx #2
@zo:    sta z_off,x
        dex
        bpl @zo
        lda #1
        sta f2t_mode
        lda ex_csv
        beq @ods
        jsr csv_write
        jmp @fl
@ods:   jsr ods_write
@fl:    lda #0
        sta f2t_mode
        jsr ob_flush
        MLICALL $CC, mclose_p
        bcs @cerr
        lda ob_err
        beq @ok
@cerr:  lda ob_err
        jmp experror
@ok:    jsr mb_reset
        LDAY s_expok1
        jsr mb_str
        lda vcount
        jsr mb_num8
        LDAY s_expok2
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
@nmd:   LDAY al_expmsg
        jmp alert

experror:
        pha
        jsr mb_reset
        LDAY s_experr
        jsr mb_str
        pla
        jsr mb_errtext
        LDAY al_expmsg
        jmp alert

; isown: Z set if EXPNAME is one of RetroDB's own files
isown:  ldx #0
@l:     stx ex_i
        lda ownlist,x
        ora ownlist+1,x
        beq @no
        LDAY EXPNAME
        jsr setp1
        ldx ex_i
        lda ownlist,x
        ldy ownlist+1,x
        jsr setp2
        jsr namecmp
        beq @d
        ldx ex_i
        inx
        inx
        bne @l
@no:    lda #1
@d:     rts

; expdefault: EXPNAME = the database's name (up to 11 letters) + .ODS
; or .CSV
expdefault:
        ldx #0
        lda named
        beq @un
@c:     cpx pathname
        beq @e
        cpx #11
        beq @e
        lda pathname+1,x
        cmp #'.'                ; stop at a period: ADDR.BOOK -> ADDR.ODS
        beq @e
        sta EXPNAME+1,x
        inx
        bne @c
@un:    lda s_dbnm,x
        beq @e
        sta EXPNAME+1,x
        inx
        bne @un
@e:     lda ex_csv
        bne @xc
        LDAY s_odsext
        jmp @x0
@xc:    LDAY s_csvext
@x0:    sta sptr
        sty sptr+1
        ldy #0
@x:     lda (sptr),y
        beq @d
        sta EXPNAME+1,x
        inx
        iny
        bne @x
@d:     stx EXPNAME
        rts

; ---------------------------------------------------------------
; output through the ZIP layer: bytes are counted (z_off), and while
; z_on they go into the member's CRC and size
; ---------------------------------------------------------------
zput:   pha
        inc z_off
        bne @c
        inc z_off+1
        bne @c
        inc z_off+2
@c:     ldx z_on
        beq @o
        sty zp_y                ; CRC-32, a bit at a time (polynomial
        eor z_crc               ; EDB88320)
        sta z_crc
        ldy #8
@b:     lsr z_crc+3
        ror z_crc+2
        ror z_crc+1
        ror z_crc
        bcc @s
        lda z_crc+3
        eor #$ED
        sta z_crc+3
        lda z_crc+2
        eor #$B8
        sta z_crc+2
        lda z_crc+1
        eor #$83
        sta z_crc+1
        lda z_crc
        eor #$20
        sta z_crc
@s:     dey
        bne @b
        ldy zp_y
        inc z_size
        bne @o
        inc z_size+1
        bne @o
        inc z_size+2
@o:     pla
        jmp ob_put

; zstr: zero-terminated A/Y through zput
zstr:   sta zs_p
        sty zs_p+1
@l:     ldy #0
        lda (zs_p),y
        beq @d
        jsr zput
        inc zs_p
        bne @l
        inc zs_p+1
        bne @l
@d:     rts

; zdec: A (0-255) as decimal digits
zdec:   sta num
        lda #0
        sta num+1
        sta num+2
        sta num+3
        sta num+4
zdecn:  jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jmp zstr

; zw16: A/Y as a little-endian word
zw16:   sty zw_hi
        jsr zput
        lda zw_hi
        jmp zput

; ---------------------------------------------------------------
; CSV
; ---------------------------------------------------------------
csv_write:
        ldx #0                  ; the field names
@h:     stx ex_col
        txa
        beq @h1
        lda #','
        jsr ob_put
@h1:    ldx ex_col
        jsr fnameptr
        jsr fld2tmp
        jsr csv_q
        ldx ex_col
        inx
        cpx nfields
        bcc @h
        jsr csv_eol
        lda #0
        sta ex_i
@r:     lda ex_i                ; the records, in the list's order
        cmp vcount
        bcs @d
        lda #0
        sta ex_col
@c:     lda ex_col
        beq @c1
        lda #','
        jsr ob_put
@c1:    jsr ex_get              ; field ex_col of record ex_i
        bcs @nx                 ; blank
        lda fk_k
        cmp #K_TEXT
        beq @q
        cmp #K_YESNO
        beq @q
        cmp #K_DATE
        bne @p
        lda f2_n                ; a whole date isn't quoted
        cmp #10
        bne @q
@p:     LDAY TMPSTR
        jsr ob_str
        jmp @nx
@q:     jsr csv_q
@nx:    inc ex_col
        lda ex_col
        cmp nfields
        bcc @c
        jsr csv_eol
        inc ex_i
        jmp @r
@d:     rts

csv_eol:
        lda #$0D
        jsr ob_put
        lda #$0A
        jmp ob_put

; csv_q: TMPSTR in double quotes (a quote inside becomes two)
csv_q:  lda #'"'
        jsr ob_put
        ldy #0
@l:     lda TMPSTR,y
        beq @e
        jsr ob_put
        cmp #'"'
        bne @n
        jsr ob_put
@n:     iny
        bne @l
@e:     lda #'"'
        jmp ob_put

; ex_get: field ex_col of the list's record ex_i -> fk_*, TMPSTR (plain
; text, f2_n characters).  Carry set if it is blank.
ex_get: ldx ex_i
        lda VIEW,x
        ldx ex_col
        jsr recgetf
        ldx ex_col
        jsr getfk
        jsr isblank
        beq @b
        jsr f2t
        clc
        rts
@b:     sec
        rts

; ---------------------------------------------------------------
; ODS
; ---------------------------------------------------------------
ods_write:
        jsr dostime
        lda #0                  ; mimetype (must come first, stored)
        jsr zbegin
        LDAY x_mime
        jsr zstr
        jsr zend
        lda #1                  ; the manifest
        jsr zbegin
        LDAY x_manif
        jsr zstr
        jsr zend
        lda #2                  ; the sheet
        jsr zbegin
        jsr content
        jsr zend
        ldx #2                  ; the central directory
@cd:    lda z_off,x
        sta zc_off,x
        dex
        bpl @cd
        lda #0
        sta zm
@ce:    jsr zcentral
        inc zm
        lda zm
        cmp #3
        bne @ce
        sec                     ; its size
        lda z_off
        sbc zc_off
        sta zc_size
        lda z_off+1
        sbc zc_off+1
        sta zc_size+1
        lda z_off+2
        sbc zc_off+2
        sta zc_size+2
        LDAY x_eocd             ; and its end
        jsr zbytes
        ldx #0
@sz:    lda zc_size,x
        jsr zput3
        inx
        cpx #3
        bne @sz
        lda #0
        jsr zput3
        ldx #0
@of:    lda zc_off,x
        jsr zput3
        inx
        cpx #3
        bne @of
        lda #0
        jsr zput3
        lda #0
        tay
        jmp zw16

; zput3: zput keeping X
zput3:  stx z3_x
        jsr zput
        ldx z3_x
        rts

; zbytes: A/Y -> a count byte, then that many bytes, through zput
zbytes: sta zs_p
        sty zs_p+1
        ldy #0
        lda (zs_p),y
        sta zb_n
@l:     iny
        lda (zs_p),y
        sty zb_y
        jsr zput
        ldy zb_y
        dec zb_n
        bne @l
        rts

; zbegin: A = member zm: its local header (CRC and sizes come later)
zbegin: sta zm
        tax
        lda z_off               ; where it starts
        sta zm_off0,x
        lda z_off+1
        sta zm_off1,x
        lda z_off+2
        sta zm_off2,x
        lda #0
        sta zm_crc0,x
        sta zm_crc1,x
        sta zm_crc2,x
        sta zm_crc3,x
        sta zm_sz0,x
        sta zm_sz1,x
        sta zm_sz2,x
        LDAY x_local
        jsr zbytes
        jsr zhead
        jsr zname
        lda #$FF
        sta z_crc
        sta z_crc+1
        sta z_crc+2
        sta z_crc+3
        lda #0
        sta z_size
        sta z_size+1
        sta z_size+2
        inc z_on
        rts

; zhead: time, date, CRC, both sizes, name length, extra length of
; member zm (the part the local header and central entry share)
zhead:  ldx zm                  ; gather them in zfix
        lda z_time
        sta zh_buf
        lda z_time+1
        sta zh_buf+1
        lda z_date
        sta zh_buf+2
        lda z_date+1
        sta zh_buf+3
        lda zm_crc0,x
        sta zh_buf+4
        lda zm_crc1,x
        sta zh_buf+5
        lda zm_crc2,x
        sta zh_buf+6
        lda zm_crc3,x
        sta zh_buf+7
        lda zm_sz0,x
        sta zh_buf+8
        sta zh_buf+12
        lda zm_sz1,x
        sta zh_buf+9
        sta zh_buf+13
        lda zm_sz2,x
        sta zh_buf+10
        sta zh_buf+14
        lda #0
        sta zh_buf+11
        sta zh_buf+15
        sta zh_buf+17
        sta zh_buf+18
        sta zh_buf+19
        lda zm_nlen,x
        sta zh_buf+16
        ldx #0
@w:     lda zh_buf,x
        jsr zput3
        inx
        cpx #20
        bne @w
        rts

; zname: the name of member zm
zname:  ldx zm
        lda zm_nlo,x
        ldy zm_nhi,x
        jmp zstr

; zend: member zm is complete: its CRC and size go into its local header
zend:   lda #0
        sta z_on
        ldx zm
        lda z_crc
        eor #$FF
        sta zm_crc0,x
        sta zfix
        lda z_crc+1
        eor #$FF
        sta zm_crc1,x
        sta zfix+1
        lda z_crc+2
        eor #$FF
        sta zm_crc2,x
        sta zfix+2
        lda z_crc+3
        eor #$FF
        sta zm_crc3,x
        sta zfix+3
        lda z_size
        sta zm_sz0,x
        sta zfix+4
        sta zfix+8
        lda z_size+1
        sta zm_sz1,x
        sta zfix+5
        sta zfix+9
        lda z_size+2
        sta zm_sz2,x
        sta zfix+6
        sta zfix+10
        lda #0
        sta zfix+7
        sta zfix+11
        jsr ob_flush
        ldx zm                  ; mark = its start + 14
        clc
        lda zm_off0,x
        adc #14
        sta mark_p+2
        lda zm_off1,x
        adc #0
        sta mark_p+3
        lda zm_off2,x
        adc #0
        sta mark_p+4
        jsr zmark
        lda ob_err
        bne @back
        lda #<zfix
        sta mw_buf
        lda #>zfix
        sta mw_buf+1
        lda #12
        sta mw_len
        lda #0
        sta mw_len+1
        MLICALL $CB, mwrite_p
        bcc @back
        sta ob_err
@back:  lda z_off               ; and back to the end
        sta mark_p+2
        lda z_off+1
        sta mark_p+3
        lda z_off+2
        sta mark_p+4
zmark:  lda mo_ref
        sta mark_p+1
        lda ob_err
        bne @d
        MLICALL $CE, mark_p
        bcc @d
        sta ob_err
@d:     rts

; zcentral: the central directory entry of member zm
zcentral:
        LDAY x_cent             ; signature, made by, needed, flags, method
        jsr zbytes
        jsr zhead
        ldx #0                  ; comment, disk, attributes: all zero
@z:     lda #0
        jsr zput3
        inx
        cpx #10
        bne @z
        ldx zm                  ; where its local header is
        lda zm_off0,x
        jsr zput
        ldx zm
        lda zm_off1,x
        jsr zput
        ldx zm
        lda zm_off2,x
        jsr zput
        lda #0
        jsr zput
        jmp zname

; dostime: z_date/z_time from the ProDOS clock (2026-01-01 if not set)
dostime:
        lda $BF93               ; time: hour, minute -> hhhhhmmm mmm00000
        asl a
        asl a
        asl a
        sta z_time+1
        lda $BF92
        and #$3F
        lsr a
        lsr a
        lsr a
        ora z_time+1
        sta z_time+1
        lda $BF92
        and #$07
        asl a
        asl a
        asl a
        asl a
        asl a
        sta z_time
        lda $BF90               ; date: same layout, year since 1980
        sta z_date
        lda $BF91
        sta z_date+1
        ora z_date
        bne @y
        lda #$21                ; (no clock)
        sta z_date
        lda #$5C
        sta z_date+1
        rts
@y:     lda z_date+1            ; ProDOS year 0-99 -> years since 1980
        lsr a
        cmp #40
        bcs @19
        adc #20
        bne @set
@19:    sec
        sbc #80
@set:   asl a
        sta t0
        lda z_date+1
        and #1
        ora t0
        sta z_date+1
        rts

; content: content.xml
content:
        LDAY x_head
        jsr zstr
        lda #0                  ; a column style for each field
        sta ex_col
@cs:    LDAY x_cs1
        jsr zstr
        lda ex_col
        jsr zcolno
        LDAY x_cs2
        jsr zstr
        ldx ex_col              ; width: field (or name) * 6pt + 8pt
        lda fkind,x
        pha
        lda flen,x
        tax
        pla
        jsr kindwidth
        sta ex_w
        ldx ex_col
        jsr fnameptr
        ldy #0
        lda (ptr1),y
        cmp ex_w
        bcc @w
        sta ex_w
@w:     lda ex_w
        cmp #40
        bcc @w2
        lda #40
@w2:    asl a                   ; *6 + 8 (at most 248)
        sta t0
        asl a
        clc
        adc t0
        adc #8
        jsr zdec
        LDAY x_cs3
        jsr zstr
        inc ex_col
        lda ex_col
        cmp nfields
        bcc @cs
        LDAY x_body
        jsr zstr
        jsr zsheet              ; the sheet's name
        LDAY x_body2
        jsr zstr
        lda #0
        sta ex_col
@cc:    LDAY x_col1
        jsr zstr
        lda ex_col
        jsr zcolno
        LDAY x_col2
        jsr zstr
        inc ex_col
        lda ex_col
        cmp nfields
        bcc @cc
        ; the field names
        LDAY x_row
        jsr zstr
        lda #0
        sta ex_col
@hn:    LDAY x_hcell
        jsr zstr
        ldx ex_col
        jsr fnameptr
        jsr fld2tmp
        jsr zxml
        LDAY x_endt
        jsr zstr
        inc ex_col
        lda ex_col
        cmp nfields
        bcc @hn
        LDAY x_erow
        jsr zstr
        ; the records
        lda #0
        sta ex_i
@r:     lda ex_i
        cmp vcount
        jcs @end
        LDAY x_row
        jsr zstr
        lda #0
        sta ex_col
@c:     jsr ex_get
        bcs @blank
        lda fk_k
        cmp #K_NUMBER
        beq @fl
        cmp #K_NO
        bcs @fl
        cmp #K_MONEY
        beq @mo
        cmp #K_DATE
        bne @st
        lda f2_n
        cmp #10
        bne @st
        LDAY x_date             ; a whole date
        jsr zstr
        jsr zval
        jmp @nx
@fl:    LDAY x_float
        jsr zstr
        jsr zval
        jmp @nx
@mo:    LDAY x_money
        jsr zstr
        jsr zval
        jmp @nx
@st:    LDAY x_str
        jsr zstr
        jsr zxml
        LDAY x_endt
        jsr zstr
        jmp @nx
@blank: LDAY x_empty
        jsr zstr
@nx:    inc ex_col
        lda ex_col
        cmp nfields
        bcc @c
        LDAY x_erow
        jsr zstr
        inc ex_i
        jmp @r
@end:   LDAY x_tail
        jmp zstr

; zval: TMPSTR, then "/>
zval:   LDAY TMPSTR
        jsr zstr
        LDAY x_endv
        jmp zstr

; zxml: TMPSTR with & < > escaped
zxml:   ldy #0
@l:     lda TMPSTR,y
        beq @d
        sty zx_y
        cmp #'&'
        bne @lt
        LDAY x_amp
        jsr zstr
        jmp @n
@lt:    cmp #'<'
        bne @gt
        LDAY x_lt
        jsr zstr
        jmp @n
@gt:    cmp #'>'
        bne @c
        LDAY x_gt
        jsr zstr
        jmp @n
@c:     jsr zput
@n:     ldy zx_y
        iny
        bne @l
@d:     rts

; zcolno: A = field -> "co" and its number (1-16)
zcolno: pha
        lda #'c'
        jsr zput
        lda #'o'
        jsr zput
        pla
        clc
        adc #1
        jmp zdec

; zsheet: the sheet's name: the database's name, or Database
zsheet: lda named
        beq @un
        ldx #0
@l:     cpx pathname
        beq @d
        lda pathname+1,x
        stx ex_w
        jsr zput
        ldx ex_w
        inx
        bne @l
@un:    LDAY s_sheet
        jmp zstr
@d:     rts
s_sheet: .byte "Database", 0

; ---------------------------------------------------------------
; the fixed parts of the ODS file
; ---------------------------------------------------------------
x_local: .byte 10, $50, $4B, $03, $04, $14, $00, $00, $00, $00, $00
x_cent:  .byte 12, $50, $4B, $01, $02, $14, $00, $14, $00, $00, $00, $00, $00
x_eocd:  .byte 12, $50, $4B, $05, $06, 0, 0, 0, 0, 3, 0, 3, 0
zm_nlen: .byte 8, 21, 11
zm_nlo:  .byte <n_mime, <n_manif, <n_cont
zm_nhi:  .byte >n_mime, >n_manif, >n_cont
n_mime:  .byte "mimetype", 0
n_manif: .byte "META-INF/manifest.xml", 0
n_cont:  .byte "content.xml", 0
x_mime:  .byte "application/vnd.oasis.opendocument.spreadsheet", 0
x_manif: .byte "<?xml version=", $22, "1.0", $22, " encoding=", $22, "UTF-8", $22, "?>", $0A
         .byte "<manifest:manifest xmlns:manifest=", $22
         .byte "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0", $22
         .byte " manifest:version=", $22, "1.2", $22, ">", $0A
         .byte "<manifest:file-entry manifest:full-path=", $22, "/", $22
         .byte " manifest:version=", $22, "1.2", $22, " manifest:media-type=", $22
         .byte "application/vnd.oasis.opendocument.spreadsheet", $22, "/>", $0A
         .byte "<manifest:file-entry manifest:full-path=", $22, "content.xml", $22
         .byte " manifest:media-type=", $22, "text/xml", $22, "/>", $0A
         .byte "</manifest:manifest>", $0A, 0
x_head:  .byte "<?xml version=", $22, "1.0", $22, " encoding=", $22, "UTF-8", $22, "?>", $0A
         .byte "<office:document-content"
         .byte " xmlns:office=", $22, "urn:oasis:names:tc:opendocument:xmlns:office:1.0", $22
         .byte " xmlns:style=", $22, "urn:oasis:names:tc:opendocument:xmlns:style:1.0", $22
         .byte " xmlns:text=", $22, "urn:oasis:names:tc:opendocument:xmlns:text:1.0", $22
         .byte " xmlns:table=", $22, "urn:oasis:names:tc:opendocument:xmlns:table:1.0", $22
         .byte " xmlns:fo=", $22, "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0", $22
         .byte " xmlns:number=", $22, "urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0", $22
         .byte " office:version=", $22, "1.2", $22, ">", $0A
         .byte "<office:automatic-styles>", $0A
         .byte "<number:currency-style style:name=", $22, "N1", $22, ">"
         .byte "<number:currency-symbol>$</number:currency-symbol>"
         .byte "<number:number number:decimal-places=", $22, "2", $22
         .byte " number:min-decimal-places=", $22, "2", $22
         .byte " number:min-integer-digits=", $22, "1", $22
         .byte " number:grouping=", $22, "true", $22, "/></number:currency-style>", $0A
         .byte "<number:date-style style:name=", $22, "N2", $22, ">"
         .byte "<number:year number:style=", $22, "long", $22, "/><number:text>-</number:text>"
         .byte "<number:month number:style=", $22, "long", $22, "/><number:text>-</number:text>"
         .byte "<number:day number:style=", $22, "long", $22, "/></number:date-style>", $0A
         .byte "<style:style style:name=", $22, "ce1", $22, " style:family=", $22, "table-cell", $22, ">"
         .byte "<style:text-properties fo:font-weight=", $22, "bold", $22, "/></style:style>", $0A
         .byte "<style:style style:name=", $22, "ce2", $22, " style:family=", $22, "table-cell", $22
         .byte " style:data-style-name=", $22, "N1", $22, "/>", $0A
         .byte "<style:style style:name=", $22, "ce3", $22, " style:family=", $22, "table-cell", $22
         .byte " style:data-style-name=", $22, "N2", $22, "/>", $0A, 0
x_cs1:   .byte "<style:style style:name=", $22, 0
x_cs2:   .byte $22, " style:family=", $22, "table-column", $22
         .byte "><style:table-column-properties style:column-width=", $22, 0
x_cs3:   .byte "pt", $22, "/></style:style>", $0A, 0
x_body:  .byte "</office:automatic-styles>", $0A
         .byte "<office:body><office:spreadsheet><table:table table:name=", $22, 0
x_body2: .byte $22, ">", $0A, 0
x_col1:  .byte "<table:table-column table:style-name=", $22, 0
x_col2:  .byte $22, "/>", $0A, 0
x_row:   .byte "<table:table-row>", 0
x_erow:  .byte "</table:table-row>", $0A, 0
x_hcell: .byte "<table:table-cell table:style-name=", $22, "ce1", $22
         .byte " office:value-type=", $22, "string", $22, "><text:p>", 0
x_str:   .byte "<table:table-cell office:value-type=", $22, "string", $22, "><text:p>", 0
x_endt:  .byte "</text:p></table:table-cell>", 0
x_float: .byte "<table:table-cell office:value-type=", $22, "float", $22
         .byte " office:value=", $22, 0
x_money: .byte "<table:table-cell table:style-name=", $22, "ce2", $22
         .byte " office:value-type=", $22, "currency", $22
         .byte " office:currency=", $22, "USD", $22, " office:value=", $22, 0
x_date:  .byte "<table:table-cell table:style-name=", $22, "ce3", $22
         .byte " office:value-type=", $22, "date", $22, " office:date-value=", $22, 0
x_endv:  .byte $22, "/>", 0
x_empty: .byte "<table:table-cell/>", 0
x_tail:  .byte "</table:table></office:spreadsheet></office:body>"
         .byte "</office:document-content>", $0A, 0
x_amp:   .byte "&amp;", 0
x_lt:    .byte "&lt;", 0
x_gt:    .byte "&gt;", 0

        .segment "OV0BSS"
ex_csv:  .res 1
ex_col:  .res 1
ex_i:    .res 1
ex_w:    .res 1
zp_y:    .res 1
zx_y:    .res 1
zb_n:    .res 1
zb_y:    .res 1
zh_buf:  .res 20
zw_hi:   .res 1
z3_x:    .res 1
z_on:    .res 1
z_off:   .res 3
z_crc:   .res 4
z_size:  .res 3
z_time:  .res 2
z_date:  .res 2
zm:      .res 1
zfix:    .res 12
zc_off:  .res 3
zc_size: .res 3
zm_off0: .res 3
zm_off1: .res 3
zm_off2: .res 3
zm_crc0: .res 3
zm_crc1: .res 3
zm_crc2: .res 3
zm_crc3: .res 3
zm_sz0:  .res 3
zm_sz1:  .res 3
zm_sz2:  .res 3
