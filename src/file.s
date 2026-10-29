; ---------------------------------------------------------------
; ProDOS file I/O.  A database is a text file (type $04):
;
;   MOUSEDB1
;   number of fields
;   "name",kind,length,in-list      one line per field
;   number of records
;   "value"                         one line per field, per record
;
; kind: 1 Text, 2 Number, 3 Money, 4 Date, 5 Yes/No.  Values are written
; as plain text: Money as 1234.50, Yes/No as Yes or No, blank as "".
;
; Saving never overwrites the database in place: the new copy is written
; to MOUSEDB.SAVING, and only when that worked is the old file replaced.
; ---------------------------------------------------------------
        .segment "DATA"
pathname:   .byte 0
            .res 15
tmpname:    .byte 14, "MOUSEDB.SAVING"
destroy_p:  .byte 1
dp_path:    .word tmpname
rename_p:   .byte 2
            .word tmpname
            .word pathname
create_p:   .byte 7
            .word pathname
            .byte $C3, $04
            .word $0000
            .byte $01
            .word 0, 0
open_p:     .byte 3
            .word pathname
            .word FILEBUF
open_ref:   .byte 0
newline_p:  .byte 3
nl_ref:     .byte 0
            .byte $7F, $0D
read_p:     .byte 4
rd_ref:     .byte 0
            .word LINEBUF
            .word 255
rd_trans:   .word 0
write_p:    .byte 4
wr_ref:     .byte 0
            .word LINEBUF
wr_len:     .word 0
            .word 0
close_p:    .byte 1
cl_ref:     .byte 0
seteof_p:   .byte 2
se_ref:     .byte 0
            .byte 0, 0, 0
prefix_p:   .byte 1
            .word PREFIXBUF
online_p:   .byte 2
ol_unit:    .byte 0
            .word PREFIXBUF+1
s_hdr:      .byte "MOUSEDB1", 0
quit_parms: .byte 4, 0
            .word 0
            .byte 0
            .word 0

        .segment "CODE"

; fixprefix: work in the folder MouseDB was started from (ProDOS
; leaves its pathname at $0280), or if no prefix is set, the boot volume
fixprefix:
        ldx $0280               ; a path with a "/" in it?
        beq @gp
        cpx #64
        bcs @gp
@sl:    lda $0280,x
        and #$7F
        cmp #'/'
        beq @dir
        dex
        bne @sl
        beq @gp
@dir:   stx PREFIXBUF           ; its folder becomes the prefix
@cpy:   lda $0280,x
        and #$7F
        sta PREFIXBUF,x
        dex
        bne @cpy
        MLICALL $C6, prefix_p
@gp:    MLICALL $C7, prefix_p
        bcs @set
        lda PREFIXBUF
        bne @d
@set:   lda DEVNUM
        sta ol_unit
        MLICALL $C5, online_p
        bcs @d
        lda PREFIXBUF+1
        and #$0F
        beq @d
        tax
        lda #'/'
        sta PREFIXBUF+1
        sta PREFIXBUF+2,x
        inx
        inx
        stx PREFIXBUF
        MLICALL $C6, prefix_p
@d:     rts

setrefs:
        lda open_ref
        sta nl_ref
        sta rd_ref
        sta wr_ref
        sta cl_ref
        sta se_ref
        rts

; readline: next line into LINEBUF (zero-terminated, high bits cleared)
readline:
        MLICALL $CA, read_p
        bcs @e
        ldx rd_trans
        beq @z
        dex
        lda LINEBUF,x
        and #$7F
        cmp #$0D
        beq @z
        inx
@z:     lda #0
        sta LINEBUF,x
        ldx #0
@h:     lda LINEBUF,x
        beq @ok
        and #$7F
        sta LINEBUF,x
        inx
        bne @h
@ok:    clc
@e:     rts

; line2tmp: LINEBUF without its quotes -> TMPSTR
line2tmp:
        ldx #0
        ldy #0
        lda LINEBUF
        cmp #'"'
        bne @l
        inx
@l:     lda LINEBUF,x
        beq @d
        cmp #'"'
        beq @d
        cpy #70
        bcs @d
        sta TMPSTR,y
        inx
        iny
        bne @l
@d:     lda #0
        sta TMPSTR,y
        rts

; lineint: LINEBUF as a number -> num
lineint:
        lda #<LINEBUF
        sta sptr
        lda #>LINEBUF
        sta sptr+1
        jmp parseint

; nextint: X = position in LINEBUF: skip past the next ",", read a
; number -> A (0 if none, 255 if too big); X = the position after it
nextint:
@s:     lda LINEBUF,x
        beq @none
        inx
        cmp #','
        bne @s
        lda #0
        sta t0
@d:     lda LINEBUF,x
        cmp #' '
        beq @n
        cmp #'0'
        bcc @e
        cmp #'9'+1
        bcs @e
        and #$0F
        pha
        lda t0                  ; t0 = t0*10 + digit (capped at 255)
        cmp #26
        bcs @big
        asl a
        asl a
        adc t0
        asl a
        sta t0
        pla
        clc
        adc t0
        bcc @st
        lda #255
@st:    sta t0
@n:     inx
        bne @d
@big:   pla
        lda #255
        sta t0
        bne @n
@e:     lda t0
        rts
@none:  lda #0
        rts

; doload: open the database in pathname.  Carry set + A = error
; ($80 = not a MouseDB database).
doload: lda #0
        sta ld_over
        sta ld_short
        MLICALL $C8, open_p
        bcc @o
        sec
        rts
@o:     jsr setrefs
        MLICALL $C9, newline_p
        jsr readline
        jcs @rerr
        ldx #0                  ; "MOUSEDB1"
@h:     lda s_hdr,x
        cmp LINEBUF,x
        jne @notdb
        inx
        cpx #9
        bne @h
        jsr readline
        jcs @rerr
        jsr lineint
        lda num+1
        ora num+2
        ora num+3
        jne @notdb
        lda num
        jeq @notdb
        cmp #MAXFIELDS+1
        jcs @notdb
        sta ld_nf
        ; the fields
        lda #0
        sta ld_i
@fl:    lda ld_i
        cmp ld_nf
        jcs @fd
        jsr readline
        jcs @rerr
        ldx ld_i                ; name
        jsr fnameptr
        ldx #0
        ldy #0
        lda LINEBUF
        cmp #'"'
        bne @nl
        inx
@nl:    lda LINEBUF,x
        beq @ne
        cmp #'"'
        beq @ne
        cmp #','
        beq @ne
        cpy #MAXNAME
        bcs @nn
        iny
        cmp #'|'
        bne @nc
        lda #'/'
@nc:    sta (ptr1),y
@nn:    inx
        bne @nl
@ne:    tya
        ldy #0
        sta (ptr1),y
        tay
        bne @nok
        lda #'?'                ; an empty name
        iny
        sta (ptr1),y
        tya
        dey
        sta (ptr1),y
@nok:   jsr nextint             ; kind
        ldy ld_i
        cmp #1
        bcc @kd
        cmp #NKINDS+1
        bcc @ks
@kd:    lda #K_TEXT
@ks:    sta fkind,y
        jsr nextint             ; length
        ldy ld_i
        cmp #1
        bcs @l1
        lda #20
@l1:    cmp #MAXTEXT+1
        bcc @l2
        lda #MAXTEXT
@l2:    sta flen,y
        jsr nextint             ; in list
        ldy ld_i
        cmp #0
        beq @ls
        lda #1
@ls:    sta flist,y
        lda fkind,y             ; non-Text fields: their screen width
        cmp #K_TEXT
        beq @fn
        ldx #0
        jsr kindwidth
        ldy ld_i
        sta flen,y
@fn:    inc ld_i
        jmp @fl
@fd:    lda ld_nf
        sta nfields
        LDAY fkind              ; one No., one Part Of
        sta rq
        sty rq+1
        ldx ld_nf
        jsr fixkinds
        jsr fdsetup
        jcs @notdb
        jsr initpool
        ; the records
        jsr readline
        jcs @rerr
        jsr lineint
        lda num+1
        ora num+2
        ora num+3
        ora num+4
        bne @cap
        lda num
        cmp maxrec
        bcc @n
        beq @n
@cap:   lda #1
        sta ld_over
        lda maxrec
@n:     sta ld_n
        lda #0
        sta ld_i
        sta count
        lda #1
        sta f2t_mode
@rec:   lda ld_i
        cmp ld_n
        bcc @more
        lda ld_over             ; all read: is there more than it said?
        bne @close
        jsr readline
        bcs @close
        lda LINEBUF
        beq @close
        inc ld_short
        jmp @close
@more:  jsr recgetw
        lda #0
        sta ld_f
@fv:    lda ld_f
        cmp nfields
        bcs @fvd
        jsr readline
        bcs @close
        jsr line2tmp
        ldx ld_f
        jsr getfk
        jsr t2f
        bcc @fok
        jsr fblank
@fok:   inc ld_f
        bne @fv
@fvd:   jsr recput
        inc ld_i
        lda ld_i
        sta count
        jmp @rec
@close: lda ld_i                ; fewer records than the header says?
        cmp ld_n
        bcs @cl
        inc ld_short
@cl:    MLICALL $CC, close_p
        lda #0
        sta f2t_mode
        sta dirty
        sta selactive
        sta sortdesc
        sta sel
        sta top
        lda #$FF
        sta sortkey
        jsr clearcrit
        jsr formchanged
        jsr numberfix
        ldx nf_po               ; with a Part Of field: open in tree order
        cpx #$FF
        beq @nt
        stx sortkey
        jsr dotree
        jsr buildsortmenu
@nt:    jsr showall
        clc
        rts
@notdb: lda #$80
@rerr:  pha
        MLICALL $CC, close_p
        jsr clearform
        pla
        sec
        rts

; ---- writing ----
lb_reset:
        lda #0
        sta lblen
        rts
lb_char:
        ldx lblen
        sta LINEBUF,x
        inc lblen
        rts
lb_zstr:
        sta sptr
        sty sptr+1
        ldy #0
@l:     lda (sptr),y
        beq @d
        jsr lb_char
        iny
        bne @l
@d:     rts
; lb_write: terminate with CR and write the line (carry set on error)
lb_write:
        lda #$0D
        jsr lb_char
        lda lblen
        sta wr_len
        lda #0
        sta wr_len+1
        MLICALL $CB, write_p
        php
        pha
        jsr lb_reset
        pla
        plp
        rts

; lb_num8: A as a decimal number into the line
lb_num8:
        jsr setnum8
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jmp lb_zstr

; dosave: write the database to MOUSEDB.SAVING, then swap it in for
; the old file.  On any error the old file is left as it was.
dosave: lda #<tmpname           ; work on the temporary file
        sta dp_path
        sta create_p+1
        sta open_p+1
        lda #>tmpname
        sta dp_path+1
        sta create_p+2
        sta open_p+2
        MLICALL $C1, destroy_p  ; a leftover from an earlier try
        jsr @write
        php
        pha
        lda #<pathname          ; back to the real name
        sta create_p+1
        sta open_p+1
        lda #>pathname
        sta create_p+2
        sta open_p+2
        pla
        plp
        bcs @fail
        lda #<pathname          ; replace the old file with the new one
        sta dp_path
        lda #>pathname
        sta dp_path+1
        MLICALL $C1, destroy_p
        bcc @ren
        cmp #$46                ; there was no old file: fine
        bne @fail
@ren:   MLICALL $C2, rename_p
        bcs @fail2
        lda #0
        sta dirty
        clc
        rts
@fail:  pha                     ; throw the incomplete copy away
        lda #<tmpname
        sta dp_path
        lda #>tmpname
        sta dp_path+1
        MLICALL $C1, destroy_p
        pla
@fail2: sec
        rts

@write: MLICALL $C0, create_p
        bcc @c
        rts
@c:     MLICALL $C8, open_p
        bcc @o
        rts
@o:     jsr setrefs
        jsr lb_reset
        lda #<s_hdr
        ldy #>s_hdr
        jsr lb_zstr
        jsr lb_write
        jcs @err
        lda nfields
        jsr lb_num8
        jsr lb_write
        jcs @err
        lda #0
        sta sv_i
@fl:    lda sv_i                ; "name",kind,length,list
        cmp nfields
        bcs @fd
        lda #'"'
        jsr lb_char
        ldx sv_i
        jsr fnameptr
        ldy #0
        lda (ptr1),y
        sta t1
@nc:    cpy t1
        beq @ne
        iny
        lda (ptr1),y
        jsr lb_char
        jmp @nc
@ne:    lda #'"'
        jsr lb_char
        lda #','
        jsr lb_char
        ldx sv_i
        lda fkind,x
        jsr lb_num8
        lda #','
        jsr lb_char
        ldx sv_i
        lda flen,x
        jsr lb_num8
        lda #','
        jsr lb_char
        ldx sv_i
        lda flist,x
        jsr lb_num8
        jsr lb_write
        jcs @err
        inc sv_i
        jmp @fl
@fd:    lda count
        jsr lb_num8
        jsr lb_write
        jcs @err
        lda #1
        sta f2t_mode
        lda #0
        sta sv_i
@rec:   lda sv_i
        cmp count
        bcs @done
        lda #0
        sta sv_f
@fv:    lda sv_f
        cmp nfields
        bcs @nr
        lda sv_i
        jsr recget
        ldx sv_f
        jsr getfk
        jsr f2t
        lda #'"'
        jsr lb_char
        lda #<TMPSTR
        ldy #>TMPSTR
        jsr lb_zstr
        lda #'"'
        jsr lb_char
        jsr lb_write
        bcs @err
        inc sv_f
        bne @fv
@nr:    inc sv_i
        jmp @rec
@done:  lda #0
        sta f2t_mode
        MLICALL $CC, close_p
        rts
@err:   pha
        lda #0
        sta f2t_mode
        MLICALL $CC, close_p
        pla
        sec
        rts

        .segment "BSS"
ld_n:     .res 1
ld_i:     .res 1
ld_f:     .res 1
ld_nf:    .res 1
ld_over:  .res 1
ld_short: .res 1
sv_i:     .res 1
sv_f:     .res 1
lblen:    .res 1
