; ---------------------------------------------------------------
; Import and export: the part that stays in memory (LCODE, at $2000)
;
; The work itself is done by three overlays, loaded from RETRODB.OVL
; into OVLBASE-$3FFF only while they are needed:
;   0  Export: CSV or ODS                            (ov_exp.s)
;   1  Import from a CSV file                         (ov_imp.s)
;   2  Unpack an ODS file into a temporary CSV file   (ov_ods.s)
; An ODS file is imported by turning it into RETRODB.TMP (overlay 2)
; and importing that (overlay 1).  Unpacking needs a 32K window in
; auxiliary memory ($4000-$BFFF); records kept there are saved to
; RETRODB.SWP meanwhile.
;
; Also here: the file lists (scandir, pickdialog) and the name dialog,
; which Open and Save As use too.
; ---------------------------------------------------------------
MAXDIR   = 14

        .segment "LCODE"
s_expname: .byte "Name:", 0
s_ovlnm:   .byte 11, "RETRODB.OVL"
s_tmpnm:   .byte 11, "RETRODB.TMP"
s_swpnm:   .byte 11, "RETRODB.SWP"
t_import:  .byte "Import", 0
t_export:  .byte "Export", 0
s_noovl:   .byte "RETRODB.OVL is missing. It holds|"
           .byte "the import and export code, and|"
           .byte "must be next to RETRODB.SYSTEM.", 0
s_noaux:   .byte "There isn't memory to read an ODS|"
           .byte "file now (it needs a 128K Apple,|"
           .byte "/RAM empty, and fewer records).|"
           .byte "Save it as CSV and import that.", 0
s_swperr:  .byte "There isn't room on the disk to|"
           .byte "set the records aside while the|"
           .byte "ODS file is read.||", 0
al_noovl:  .word t_alert, s_noovl
           .byte 1
           .word b_ok
al_noaux:  .word t_import, s_noaux
           .byte 1
           .word b_ok
al_xmsg:   .word t_import, MSGBUF
           .byte 1
           .word b_ok

EXPNAME:   .byte 0
           .res 15
mcreate_p: .byte 7
           .word mc_path
           .byte $C3
mc_type:   .byte $04
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
mw_buf:    .word OBUF
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
mdestroy_p: .byte 1
           .word mc_path
sd_skip:   .byte 0
mark_p:    .byte 2, 0, 0, 0, 0
; RETRODB.OVL, RETRODB.TMP, RETRODB.SWP
xopen_p:   .byte 3
xo_path:   .word s_ovlnm
           .word FILEBUF
xo_ref:    .byte 0
xread_p:   .byte 4
xr_ref:    .byte 0
xr_buf:    .word OVLBASE
xr_req:    .word OVLSIZE
           .word 0
xmark_p:   .byte 2
xm_ref:    .byte 0
xm_pos:    .byte 0, 0, 0
xclose_p:  .byte 1
xc_ref:    .byte 0
xcreate_p: .byte 7
           .word s_swpnm
           .byte $C3, $06
           .word $0000
           .byte $01
           .word 0, 0
xdestroy_p: .byte 1
xd_path:   .word s_swpnm

msetrefs:
        lda mo_ref
        sta mw_ref
        sta mr_ref
        sta mc_ref
        sta mse_ref
        rts

; ---------------------------------------------------------------
; output buffer (OBUF, written to the file mw_ref)
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
        lda #<OBUF
        sta mw_buf
        lda #>OBUF
        sta mw_buf+1
        lda ob_err
        bne @d
        MLICALL $CB, mwrite_p
        bcc @d
        sta ob_err
@d:     rts

; ob_str: zero-terminated A/Y -> the output
ob_str: sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        beq @d
        jsr ob_put
        iny
        bne @l
@d:     rts

; getbyte: next byte of the file mr_ref in A; carry set at end / error
getbyte:
        ldx ib_pos
        cpx ib_len
        bcc @have
        lda #<INBUF             ; (ovload and scandir use mread_p too)
        sta mr_buf
        lda #>INBUF
        sta mr_buf+1
        lda #255
        sta mr_req
        lda #0
        sta mr_req+1
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

; ---------------------------------------------------------------
; overlays
; ---------------------------------------------------------------
; ovload: A = overlay, read from RETRODB.OVL unless it is there already.
; Carry set (after saying so) if it can't be read.
ovload: sta ovl_want
        tax                     ; (ovl_cur holds overlay + 1: 0 = none)
        inx
        cpx ovl_cur
        bne @rd
        clc
        rts
@rd:    lda #0
        sta ovl_cur
        LDAY s_ovlnm
        jsr xopen
        bcs @err
        lda #0                  ; mark = overlay * OVLSIZE
        sta xm_pos
        sta xm_pos+1
        sta xm_pos+2
        ldx ovl_want
        beq @m
@ml:    clc
        lda xm_pos
        adc #<OVLSIZE
        sta xm_pos
        lda xm_pos+1
        adc #>OVLSIZE
        sta xm_pos+1
        bcc @mn
        inc xm_pos+2
@mn:    dex
        bne @ml
@m:     MLICALL $CE, xmark_p
        bcs @cerr
        lda #<OVLBASE
        sta xr_buf
        lda #>OVLBASE
        sta xr_buf+1
        lda #<OVLSIZE
        sta xr_req
        lda #>OVLSIZE
        sta xr_req+1
        MLICALL $CA, xread_p
        bcs @cerr
        jsr xclose
        ldx ovl_want
        inx
        stx ovl_cur
        clc
        rts
@cerr:  jsr xclose
@err:   LDAY al_noovl
        jsr alert
        sec
        rts

; xopen: open the file named A/Y (length-prefixed) as xo_ref
xopen:  sta xo_path
        sty xo_path+1
        MLICALL $C8, xopen_p
        bcs @d
        lda xo_ref
        sta xr_ref
        sta xm_ref
        sta xc_ref
@d:     rts
xclose: MLICALL $CC, xclose_p
        rts

cmd_export:
        lda #0
        jsr ovload
        bcs @d
        jmp OVLBASE
@d:     rts

; ---------------------------------------------------------------
; import: choose a .CSV or .ODS file in this folder
; ---------------------------------------------------------------
cmd_import:
        lda #2
        sta redraw
        lda #$FF                ; files named .CSV or .ODS
        sta sd_type
        jsr scandir
        bcc @sc
        jmp xerror
@sc:    lda ndir
        bne @pick
        LDAY al_nofiles
        jmp alert
@pick:  LDAY pk_import
        jsr setpick
        jsr pickdialog
        bcc @chosen
        rts
@chosen:
        jsr dselptr             ; mc_path = the name
        ldy #0
        lda (ptr1),y
        tay
@cn:    lda (ptr1),y
        sta mc_path,y
        dey
        bpl @cn
        lda #0
        sta im_tmp
        jsr isods
        bcs @csv
        lda auxok               ; ODS: unpack it into RETRODB.TMP, which
        beq @noaux              ; needs aux memory, and no records in
        ldx #0                  ; main memory (its buffers go there)
@mr:    cpx count
        bcs @aux
        lda PTRBK,x
        beq @noaux
        inx
        bne @mr
@noaux: LDAY al_noaux
        jmp alert
@aux:   jsr auxhold
        bcs @x
        lda #2
        jsr ovload
        bcs @back
        jsr OVLBASE             ; carry set: it said what went wrong
        php
        jsr auxback
        plp
        bcs @rm
        ldx s_tmpnm             ; and import that
@tc:    lda s_tmpnm,x
        sta mc_path,x
        dex
        bpl @tc
        inc im_tmp
@csv:   lda #1
        jsr ovload
        bcs @rm
        jsr OVLBASE
@rm:    lda im_tmp              ; RETRODB.TMP is no longer needed
        beq @x
        LDAY s_tmpnm
        jmp xdestroy
@back:  jmp auxback
@x:     rts

; isods: does mc_path end in ".ODS"?  carry clear = yes
isods:  ldx mc_path
        cpx #5
        bcc @no
        ldy #3
@c:     lda mc_path,x
        jsr toupper
        cmp s_odsx,y
        bne @no
        dex
        dey
        bpl @c
        clc
        rts
@no:    sec
        rts
s_odsx: .byte ".ODS"
s_csvx: .byte ".CSV"

; xdestroy: delete the file named A/Y (errors ignored)
xdestroy:
        sta xd_path
        sty xd_path+1
        MLICALL $C1, xdestroy_p
        rts

; xerror: "Could not read the file." and the ProDOS error in A
xerror: pha
        jsr mb_reset
        LDAY s_xerr
        jsr mb_str
        pla
        jsr mb_errtext
        LDAY al_xmsg
        jmp alert
s_xerr: .byte "Could not read the file.||", 0

        .segment "CODE"           ; (main memory: LCODE is full)
; ---------------------------------------------------------------
; Records in auxiliary memory at $4000 and up are saved to RETRODB.SWP
; while an ODS file is unpacked there, and read back afterwards.
; ---------------------------------------------------------------
auxhold:
        lda #0
        sta ah_held
        ldx #0                  ; any record at $3F00 or above?
@l:     cpx count
        bcs @no
        lda PTRBK,x
        beq @n
        lda PTRHI,x
        cmp #$3F
        bcs @need
@n:     inx
        bne @l
@no:    clc
        rts
@need:  LDAY s_swpnm
        jsr xdestroy
        MLICALL $C0, xcreate_p
        bcs @err
        LDAY s_swpnm
        jsr xopen
        bcs @err
        lda #$40
        sta ah_pg
@w:     jsr ah_range            ; aux page -> INBUF
        clc
        jsr auxmv
        lda #<INBUF
        sta xr_buf
        lda #>INBUF
        sta xr_buf+1
        lda #0
        sta xr_req
        lda #1
        sta xr_req+1
        MLICALL $CB, xread_p    ; (same layout as WRITE)
        bcs @werr
        inc ah_pg
        lda ah_pg
        cmp #$C0
        bne @w
        jsr xclose
        inc ah_held
        clc
        rts
@werr:  pha
        jsr xclose
        LDAY s_swpnm
        jsr xdestroy
        pla
@err:   pha
        jsr mb_reset
        LDAY s_swperr
        jsr mb_str
        pla
        jsr mb_errtext
        LDAY al_xmsg
        jsr alert
        sec
        rts

auxback:
        lda ah_held
        beq @d
        LDAY s_swpnm
        jsr xopen
        bcs @d
        lda #$40
        sta ah_pg
@r:     lda #<INBUF
        sta xr_buf
        lda #>INBUF
        sta xr_buf+1
        lda #0
        sta xr_req
        lda #1
        sta xr_req+1
        MLICALL $CA, xread_p
        bcs @c
        jsr ah_range            ; INBUF -> aux page
        lda A1L                 ; (swap: main INBUF is the source)
        ldx A4L
        sta A4L
        stx A1L
        lda A1L+1
        ldx A4L+1
        sta A4L+1
        stx A1L+1
        clc
        lda A1L
        adc #$FF
        sta A2L
        lda A1L+1
        adc #0
        sta A2L+1
        sec
        jsr auxmv
        inc ah_pg
        lda ah_pg
        cmp #$C0
        bne @r
@c:     jsr xclose
        LDAY s_swpnm
        jsr xdestroy
        lda #0
        sta ah_held
@d:     rts

; ah_range: AUXMOVE registers for aux page ah_pg -> main INBUF
ah_range:
        lda #0
        sta A1L
        lda ah_pg
        sta A1L+1
        lda #$FF
        sta A2L
        lda ah_pg
        sta A2L+1
        lda #<INBUF
        sta A4L
        lda #>INBUF
        sta A4L+1
        rts

        .segment "LCODE"

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

; ---------------------------------------------------------------
; scandir: DIRNAMES = the files of type sd_type in the current folder
; (sd_type $FF: the files named .CSV or .ODS, of any type).
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
        lda sd_type
        cmp #$FF
        bne @ty
        jsr sufxok
        bcs @next
        bcc @take
@ty:    ldy #16
        lda (ptr1),y
        cmp sd_type
        bne @next
@take:  lda ndir
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
        jsr @close              ; databases: check this block's files
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

; sufxok: does the directory entry at ptr1 end in .CSV or .ODS?
; carry clear = yes (ptr1 kept)
sufxok: ldy #0
        lda (ptr1),y
        and #$0F
        cmp #5
        bcc @no
        sta t0
        ldx #3                  ; .CSV
        ldy t0
@c:     lda (ptr1),y
        cmp s_csvx,x
        bne @o
        dey
        dex
        bpl @c
        clc
        rts
@o:     ldx #3                  ; .ODS
        ldy t0
@d:     lda (ptr1),y
        cmp s_odsx,x
        bne @no
        dey
        dex
        bpl @d
        clc
        rts
@no:    sec
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
        beq @ok                 ; click the selected one again to choose it
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

s_nofiles: .byte "There are no CSV or ODS files in|"
           .byte "this folder. Copy one next to|"
           .byte "RETRODB.SYSTEM and try again.", 0
s_pickh:   .byte "CSV and ODS files in this folder:", 0
b_import:  .byte "Import", 0
pk_import: .word t_import, s_pickh, b_import
al_nofiles: .word t_import, s_nofiles
           .byte 1
           .word b_ok

        .segment "BSS"
oblen:   .res 1
ob_err:  .res 1
ob_x:    .res 1
mp_x:    .res 1
ib_len:  .res 1
ib_pos:  .res 1
ovl_cur: .res 1                 ; the overlay loaded, plus 1 (0: none)
ovl_want: .res 1
im_tmp:  .res 1
ah_held: .res 1
ah_pg:   .res 1
im_base: .res 1                 ; (used by imp_nest in nest.s too)
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
