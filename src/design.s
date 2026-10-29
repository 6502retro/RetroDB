; ---------------------------------------------------------------
; Design Form: add, remove, rename, retype and reorder fields.
;
; The window edits a copy of the form (the D tables).  On OK the
; records are converted to the new form: each new field takes its
; value from the old field it came from (dsrc), through text, so a
; value that doesn't fit a new type or length is cut or left blank.
; ---------------------------------------------------------------
DG_TOP  = 5             ; first field row
DG_NCOL = 4             ; name box
DG_TCOL = 22            ; type choice
DG_LCOL = 36            ; length box
DG_ICOL = 45            ; "in list" choice
DG_BROW = 22            ; buttons

        .segment "RODATA"
t_design:  .byte "Design Form", 0
s_dhead1:  .byte "Field name", 0
s_dhead2:  .byte "Type", 0
s_dhead3:  .byte "Length", 0
s_dhead4:  .byte "In list", 0
s_dsize1:  .byte "Record size: ", 0
s_dsize2:  .byte " of 255 bytes ", 0
s_dhint:   .byte "TAB next  ", G_LEFT, G_RIGHT, " change  ", G_OA, "I insert  ", G_OA, "D delete", 0
b_insert:  .byte "Insert Field", 0
b_remove:  .byte "Delete Field", 0
s_d20:     .byte 2, "20"
s_noflds:  .byte "Please add at least one field: type|"
           .byte "its name in the first row.", 0
s_noname:  .byte "Please give every field a name, or|"
           .byte "delete the empty row with ", G_OA, "-D.", 0
s_dupnm:   .byte "Two fields have the same name.|"
           .byte "Please give each field its own name.", 0
s_badlen:  .byte "A Text field holds 1 to 56|"
           .byte "characters. Please type a length|"
           .byte "in that range.", 0
s_toolong: .byte "The record is longer than 255|"
           .byte "bytes. Please make some Text|"
           .byte "fields shorter.", 0
s_nofit1:  .byte "With this form only ", 0
s_nofit2:  .byte " records|fit in memory, and there are ", 0
s_nofit3:  .byte ".|Make some fields shorter, or|delete records first.", 0
s_chg1:    .byte "This changes all ", 0
s_chg2:    .byte " records. Fields|"
           .byte "you removed lose their data, and|"
           .byte "values that don't fit a new type|"
           .byte "or length are cut or left blank.", 0
b_change:  .byte "Change", 0
al_noflds: .word t_design, s_noflds
           .byte 1
           .word b_ok
al_noname: .word t_design, s_noname
           .byte 1
           .word b_ok
al_dupnm:  .word t_design, s_dupnm
           .byte 1
           .word b_ok
al_badlen: .word t_design, s_badlen
           .byte 1
           .word b_ok
al_toolong: .word t_design, s_toolong
           .byte 1
           .word b_ok
al_dmsg:   .word t_design, MSGBUF
           .byte 1
           .word b_ok
al_change: .word t_design, MSGBUF
           .byte 2
           .word b_change, b_cancel
        .segment "CODE"

; dnptr: X = row -> ptr2 = its name.  dlptr: ptr2 = its length text
dnptr:  txa
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<dname
        sta ptr2
        lda #>dname
        adc #0
        sta ptr2+1
        rts
dlptr:  txa
        asl a
        asl a
        clc
        adc #<dltxt
        sta ptr2
        lda #>dltxt
        adc #0
        sta ptr2+1
        rts

; dlenval: X = row -> A = its Text length (0 if not a number)
dlenval:
        jsr dlptr
        ldy #0
        lda (ptr2),y
        beq @z
        sta t0
        lda #0
        sta t1
        iny
@l:     lda t1                  ; t1 = t1*10 + digit
        asl a
        asl a
        adc t1
        asl a
        sta t1
        lda (ptr2),y
        and #$0F
        clc
        adc t1
        sta t1
        cpy t0
        beq @d
        iny
        bne @l
@d:     lda t1
        rts
@z:     lda #0
        rts

; dsetlen: X = row, A = length -> its length text
dsetlen:
        pha
        jsr dlptr
        pla
        ldy #0
        cmp #10
        bcs @two
        ora #'0'
        ldy #1
        sta (ptr2),y
        tya
        dey
        sta (ptr2),y
        rts
@two:   ldx #'0'
@t:     cmp #10
        bcc @g
        sbc #10
        inx
        bne @t
@g:     ora #'0'
        ldy #2
        sta (ptr2),y
        txa
        dey
        sta (ptr2),y
        dey
        lda #2
        sta (ptr2),y
        rts

; dsize: A = the record size of the design (carry set if over 255)
dsize:  lda #0
        sta ds_tot
        sta ds_tot+1
        ldx #0
@l:     cpx dn
        bcs @d
        stx ds_x
        jsr dlenval
        tax
        ldy ds_x
        lda dkind,y
        jsr kindsize
        ldx ds_x
        sta dsz,x
        lda ds_tot
        sta doff,x
        clc
        adc dsz,x
        sta ds_tot
        bcc @n
        inc ds_tot+1
@n:     inx
        bne @l
@d:     lda ds_tot+1
        bne @big
        lda ds_tot
        clc
        rts
@big:   lda #$FF
        sec
        rts

; ---------------------------------------------------------------
; drawing
; ---------------------------------------------------------------
drawdesign:
        lda #2
        sta wx
        sta wy
        lda #76
        sta ww
        lda #20
        sta wh
        lda #<t_design
        ldy #>t_design
        jsr drawwin
        POS DG_NCOL, 4
        PRT s_dhead1
        POS DG_TCOL, 4
        PRT s_dhead2
        POS DG_LCOL-1, 4
        PRT s_dhead3
        POS DG_ICOL, 4
        PRT s_dhead4
        ldx #0
@r:     stx dd_i
        jsr drawdrow
        ldx dd_i
        inx
        cpx #MAXFIELDS
        bne @r
        jsr drawdsize
        POS 4, DG_BROW
        lda #<b_insert
        ldy #>b_insert
        ldx #0
        jsr drawbtn
        POS 19, DG_BROW
        lda #<b_remove
        ldy #>b_remove
        ldx #0
        jsr drawbtn
        POS 61, DG_BROW
        lda #<s_ok
        ldy #>s_ok
        ldx #1
        jsr drawbtn
        POS 66, DG_BROW
        lda #<b_cancel
        ldy #>b_cancel
        ldx #0
        jmp drawbtn

drawdsize:
        POS 4, 21
        lda #0
        sta inv
        PRT s_dsize1
        jsr dsize
        php
        jsr setnum8
        plp
        bcc @ok
        lda #1
        sta inv
        PRTS ">255"
        lda #0
        sta inv
        jmp @t
@ok:    ldx #3
        jsr prnum
@t:     PRT s_dsize2
        POS 37, 21
        PRT s_dhint
        rts

; drawdrow: X = row
drawdrow:
        stx dr_r
        txa
        clc
        adc #DG_TOP
        sta cy
        lda #DG_NCOL-1
        sta cx
        lda #0
        sta inv
        ldx #74                 ; clear the row
        jsr spaces
        ldx dr_r
        cpx dn
        bcc @field
        beq @new
        rts                     ; past the new row: empty
@new:   cpx #MAXFIELDS
        bcs @rts
        jsr dgname
        lda #0
        ldx dr_r
        cpx drow
        bne @nf
        lda #1
@nf:    jmp drawtf
@rts:   rts
@field: jsr dgname
        lda #0
        jsr dfocus
        jsr drawtf
        ; type
        lda #DG_TCOL
        sta cx
        lda #G_LEFT
        jsr putch
        jsr space
        lda #1
        jsr dgfoc
        ldx dr_r
        lda dkind,x
        jsr kindname
        ldx #7
        jsr prtw
        lda #0
        sta inv
        jsr space
        lda #G_RIGHT
        jsr putch
        ; length
        ldx dr_r
        lda dkind,x
        cmp #K_TEXT
        bne @fix
        jsr dglen
        lda #2
        jsr dfocus
        jsr drawtf
        jmp @list
@fix:   lda #DG_LCOL
        sta cx
        ldx dr_r
        lda dkind,x
        jsr kindwidth
        jsr setnum8
        ldx #2
        jsr prnum
        ; in list
@list:  lda #DG_ICOL
        sta cx
        lda #G_LEFT
        jsr putch
        jsr space
        lda #3
        jsr dgfoc
        lda #<s_yes
        ldy #>s_yes
        ldx dr_r
        lda dlist,x
        bne @y
        lda #<s_no
        ldy #>s_no
        ldx #3
        jsr prtw
        jmp @le
@y:     lda #<s_yes
        ldy #>s_yes
        ldx #3
        jsr prtw
@le:    lda #0
        sta inv
        jsr space
        lda #G_RIGHT
        jmp putch

; dfocus: A = column -> A = 1 if the cell (dr_r, A) has the focus
dfocus: jsr dgfoc
        lda inv
        ldx #0
        stx inv
        rts

; dgfoc: inv = 1 if the cell (dr_r, A) has the focus
dgfoc:  ldx #0
        cmp dcol
        bne @n
        lda dr_r
        cmp drow
        bne @n
        inx
@n:     stx inv
        rts

; dgname / dglen: text box registers for row dr_r
dgname: ldx dr_r
        jsr dnptr
        lda #MAXNAME
        sta tf_max
        lda #7
        sta tf_filt
        lda #DG_NCOL
        sta tf_col
        lda dr_r
        clc
        adc #DG_TOP
        sta tf_row
        rts
dglen:  ldx dr_r
        jsr dlptr
        lda #2
        sta tf_max
        lda #1
        sta tf_filt
        lda #DG_LCOL
        sta tf_col
        lda dr_r
        clc
        adc #DG_TOP
        sta tf_row
        rts

; ---------------------------------------------------------------
; the dialog
; ---------------------------------------------------------------
cmd_design:
        lda #2
        sta redraw
        ; copy the form into the D tables
        lda nfields
        sta dn
        ldx #0
@cp:    cpx nfields
        bcs @cpd
        lda fkind,x
        sta dkind,x
        lda flist,x
        sta dlist,x
        txa
        sta dsrc,x
        stx dd_i
        lda flen,x
        ldy fkind,x
        cpy #K_TEXT
        beq @tl
        lda #20
@tl:    jsr dsetlen
        ldx dd_i
        jsr fnameptr            ; name: ptr1 = fname entry
        jsr dnptr
        ldy #15
@nc:    lda (ptr1),y
        sta (ptr2),y
        dey
        bpl @nc
        ldx dd_i
        inx
        bne @cp
@cpd:   lda #0
        sta drow
        sta dcol
@full:  jsr hidecursor
        jsr drawdesign
@loop:  jsr getevent
        cmp #EV_KEY
        jne @mouse
        lda keych
        cmp #$0D
        bne @k1
        jmp @ok
@k1:    cmp #$1B
        bne @k2
        rts
@k2:    ldx keyoa
        beq @k3
        jsr toupper
        cmp #'I'
        jeq @ins
        cmp #'D'
        jeq @del
        jmp @loop
@k3:    cmp #$09
        jeq @tab
        cmp #$0A
        jeq @down
        cmp #$0B
        jeq @up
        lda dcol
        beq @name
        cmp #2
        beq @len
        ; a choice: type or in list
        lda keych
        cmp #$08
        beq @cprev
        cmp #$15
        beq @cnext
        cmp #' '
        beq @cnext
        jmp @loop
@cnext: lda #1
        bne @cstep
@cprev: lda #$FF
@cstep: sta dd_dir
        ldx drow
        lda dcol
        cmp #3
        beq @lst
        lda dkind,x             ; type: 1..5
        clc
        adc dd_dir
        bne @k5
        lda #NKINDS
@k5:    cmp #NKINDS+1
        bcc @k6
        lda #1
@k6:    sta dkind,x
        jmp @redrow
@lst:   lda dlist,x
        eor #1
        sta dlist,x
        jmp @redrow
@name:  ldx drow
        stx dr_r
        jsr dgname
        lda keych
        jsr tfkey
        jcc @loop
        ldx drow                ; typing in the new row adds a field
        cpx dn
        bcc @redrow
        jsr dnptr
        ldy #0
        lda (ptr2),y
        jeq @redrow
        jsr dnewrow
        inc dn
        ldx dn
        jsr dclrname
        jmp @redraw2
@len:   ldx drow
        stx dr_r
        jsr dglen
        lda keych
        jsr tfkey
        jcc @loop
        jmp @redraw2
@redrow:
        ldx drow
        jsr drawdrow
        jsr drawdsize
        jmp @loop
@redraw2:
        ldx drow
        jsr drawdrow
        ldx drow
        inx
        jsr drawdrow
        jsr drawdsize
        jmp @loop
@tab:   ldx drow
        cpx dn
        bcs @tnr                ; the new row has only a name
        lda dcol
        clc
        adc #1
        cmp #2
        bne @t2
        ldy dkind,x             ; length only for Text
        cpy #K_TEXT
        beq @t2
        lda #3
@t2:    cmp #4
        bcc @tset
@tnr:   lda #0
        sta dcol
        jmp @down2
@tset:  sta dcol
        jmp @moved
@down:
@down2: ldx drow
        inx
        cpx dn
        beq @dn1
        bcc @dn1
        ldx #0                  ; past the new row: back to the top
@dn1:   cpx #MAXFIELDS
        bcc @dn2
        ldx #0
@dn2:   jmp @setrow
@up:    ldx drow
        dex
        bpl @setrow
        ldx dn
        cpx #MAXFIELDS
        bcc @setrow
        dex
@setrow:
        lda drow
        sta dd_old
        stx drow
        cpx dn                  ; the new row: name only
        bcc @sr1
        lda #0
        sta dcol
@sr1:   lda drow
        tax
        jsr @fixcol
        ldx dd_old              ; redraw the row left and the row entered
        jsr drawdrow
@moved: jsr hidecursor          ; (the focus moved within row drow)
        ldx drow
        jsr drawdrow
        jmp @loop
@fixcol: lda dcol               ; no length box unless Text
        cmp #2
        bne @fc
        lda dkind,x
        cmp #K_TEXT
        beq @fc
        lda #3
        sta dcol
@fc:    rts
@ins:   lda dn
        cmp #MAXFIELDS
        jcs @loop
        ldx drow
        cpx dn
        jcs @loop               ; (the new row is already blank)
        jsr dinsert
        jmp @full
@del:   ldx drow
        cpx dn
        jcs @loop
        jsr ddelete
        jmp @full
@mouse: lda mrow
        cmp #DG_BROW
        bne @mrow
        lda mcol
        cmp #4
        jcc @loop
        cmp #18
        bcc @ins
        cmp #19
        jcc @loop
        cmp #33
        bcc @del
        cmp #61
        jcc @loop
        cmp #65
        jcc @ok
        cmp #66
        jcc @loop
        cmp #74
        jcs @loop
        rts
@mrow:  sec
        sbc #DG_TOP
        jcc @loop
        cmp #MAXFIELDS
        jcs @loop
        cmp dn
        beq @mr
        jcs @loop
@mr:    sta dd_i
        lda mcol                ; which column?
        ldx #0
        cmp #DG_TCOL
        bcc @mc
        inx
        cmp #DG_LCOL-1
        bcc @mc
        inx
        cmp #DG_ICOL
        bcc @mc
        inx
@mc:    stx dcol
        lda drow
        sta dd_old
        ldx dd_i
        stx drow
        cpx dn
        bcc @mc2
        lda #0
        sta dcol
@mc2:   jsr @fixcol
        jsr @moved2
        lda dcol                ; a click on a choice steps it
        cmp #1
        beq @mch
        cmp #3
        jne @loop
        jmp @cnext
@mch:   lda mcol
        cmp #DG_TCOL+2
        jcc @cprev
        jmp @cnext
@moved2:
        ldx dd_old
        jsr drawdrow
        ldx drow
        jmp drawdrow
@ok:    jsr dcheck
        bcc @apply
        jmp @full
@apply: jmp dapply

; dnewrow: row X becomes a new Text field of 20 characters
dnewrow:
        lda #K_TEXT
        sta dkind,x
        lda #1
        sta dlist,x
        lda #$FF
        sta dsrc,x
        lda #20
        jmp dsetlen

; dclrname: X = row -> empty name (if X < 16)
dclrname:
        cpx #MAXFIELDS
        bcs @d
        jsr dnptr
        lda #0
        tay
        sta (ptr2),y
@d:     rts

; dinsert: a blank field above row drow
dinsert:
        ldx dn
@s:     cpx drow
        beq @put
        dex
        stx dd_i
        jsr dcopyrow            ; row X -> row X+1
        ldx dd_i
        jmp @s
@put:   ldx drow
        jsr dnewrow
        ldx drow
        jsr dclrname
        inc dn
        lda #0
        sta dcol
        ldx dn
        jmp dclrname

; ddelete: remove row drow
ddelete:
        ldx drow
@s:     inx
        cpx dn
        bcs @e
        stx dd_i
        dex
        jsr dcopydown           ; row X+1 -> row X
        ldx dd_i
        jmp @s
@e:     dec dn
        ldx dn
        jsr dclrname
        lda drow
        cmp dn
        bcc @d
        lda #0
        sta dcol
@d:     rts

; dcopyrow: row X -> row X+1.  dcopydown: row X+1 -> row X
dcopyrow:
        stx dc_a
        inx
        stx dc_b
        jmp dcopy
dcopydown:
        stx dc_b
        inx
        stx dc_a
dcopy:  ldx dc_a
        ldy dc_b
        lda dkind,x
        sta dkind,y
        lda dlist,x
        sta dlist,y
        lda dsrc,x
        sta dsrc,y
        jsr dnptr
        lda ptr2
        sta ptr1
        lda ptr2+1
        sta ptr1+1
        ldx dc_b
        jsr dnptr
        ldy #15
@n:     lda (ptr1),y
        sta (ptr2),y
        dey
        bpl @n
        ldx dc_a
        jsr dlptr
        lda ptr2
        sta ptr1
        lda ptr2+1
        sta ptr1+1
        ldx dc_b
        jsr dlptr
        ldy #2
@l:     lda (ptr1),y
        sta (ptr2),y
        dey
        bpl @l
        rts

; ---------------------------------------------------------------
; checking and applying the new form
; ---------------------------------------------------------------
; dcheck: carry clear if the design can be used (else a message was
; shown and drow points at the problem)
dcheck: lda dn
        bne @n1
        lda #<al_noflds
        ldy #>al_noflds
        jmp @bad
@n1:    ldx #0                  ; names
@nm:    cpx dn
        bcs @n2
        jsr dnptr
        ldy #0
        lda (ptr2),y
        beq @noname
        inx
        bne @nm
@noname:
        stx drow
        lda #0
        sta dcol
        lda #<al_noname
        ldy #>al_noname
        jmp @bad
@n2:    lda #0                  ; no two the same
        sta dk_i
@u1:    lda dk_i
        cmp dn
        bcs @n3
        tax
        inx
        stx dk_j
@u2:    lda dk_j
        cmp dn
        bcs @u3
        jsr dsame
        beq @dup
        inc dk_j
        bne @u2
@u3:    inc dk_i
        bne @u1
@dup:   lda dk_j
        sta drow
        lda #0
        sta dcol
        lda #<al_dupnm
        ldy #>al_dupnm
        jmp @bad
@n3:    ldx #0                  ; Text lengths 1-56
@ln:    cpx dn
        bcs @n4
        lda dkind,x
        cmp #K_TEXT
        bne @lnx
        stx dk_i
        jsr dlenval
        ldx dk_i
        cmp #1
        bcc @badlen
        cmp #MAXTEXT+1
        bcs @badlen
@lnx:   inx
        bne @ln
@badlen:
        stx drow
        lda #2
        sta dcol
        lda #<al_badlen
        ldy #>al_badlen
        jmp @bad
@n4:    jsr dnestchk            ; No. and Part Of
        bcc @n4b
        stx drow
        pha
        lda #1
        sta dcol
        pla
        jmp @bad
@n4b:   jsr dsize               ; size
        bcc @n5
        lda #<al_toolong
        ldy #>al_toolong
        jmp @bad
@n5:    sta dnewsz
        jsr capfor              ; do the records still fit?
        sta dnewcap
        cmp count
        bcs @n6
        jsr mb_reset
        lda #<s_nofit1
        ldy #>s_nofit1
        jsr mb_str
        lda dnewcap
        jsr mb_num8
        lda #<s_nofit2
        ldy #>s_nofit2
        jsr mb_str
        lda count
        jsr mb_num8
        lda #<s_nofit3
        ldy #>s_nofit3
        jsr mb_str
        lda #<al_dmsg
        ldy #>al_dmsg
        jmp @bad
@n6:    lda count               ; anything lost?  ask first
        beq @good
        jsr dloses
        bcc @good
        jsr mb_reset
        lda #<s_chg1
        ldy #>s_chg1
        jsr mb_str
        lda count
        jsr mb_num8
        lda #<s_chg2
        ldy #>s_chg2
        jsr mb_str
        lda #<al_change
        ldy #>al_change
        jsr alert
        cmp #0
        beq @good
        sec
        rts
@good:  clc
        rts
@bad:   jsr alert
        sec
        rts

; mb_num8: append A as a decimal number to MSGBUF
mb_num8:
        jsr setnum8
        jsr fmtnum
        lda #<numbuf
        ldy #>numbuf
        jmp mb_str

; dsame: are the names of rows dk_i and dk_j the same?  Z set = yes
dsame:  ldx dk_i
        jsr dnptr
        lda ptr2
        sta ptr1
        lda ptr2+1
        sta ptr1+1
        ldx dk_j
        jsr dnptr
        ldy #0
        lda (ptr1),y
        cmp (ptr2),y
        bne @d
        tay
@l:     lda (ptr1),y
        jsr toupper
        sta t0
        lda (ptr2),y
        jsr toupper
        cmp t0
        bne @d
        dey
        bne @l
@d:     rts

; dloses: carry set if the change can lose data: a field removed, a
; type changed, or a Text field made shorter
dloses: ldx #0                  ; every old field still used?
@o:     cpx nfields
        bcs @k
        ldy #0
@s:     cpy dn
        beq @lost
        txa
        cmp dsrc,y
        beq @fnd
        iny
        bne @s
@fnd:   inx
        bne @o
@k:     ldy #0                  ; types and lengths
@t:     cpy dn
        bcs @no
        ldx dsrc,y
        cpx #$FF
        beq @tn
        lda fkind,x
        cmp dkind,y
        bne @lost
        cmp #K_TEXT
        bne @tn
        sty dk_i
        tya
        tax
        jsr dlenval
        ldy dk_i
        ldx dsrc,y
        cmp flen,x
        bcc @lost
@tn:    iny
        bne @t
@no:    clc
        rts
@lost:  sec
        rts

; dapply: convert the records and install the new form
dapply: lda #<s_working
        ldy #>s_working
        jsr statusmsg
        ldx #0                  ; numeric Text lengths
@lv:    cpx dn
        bcs @lvd
        stx dk_i
        lda dkind,x
        cmp #K_TEXT
        bne @lvn
        jsr dlenval
        jmp @lvs
@lvn:   ldx #0
        jsr kindwidth
@lvs:   ldx dk_i
        sta dlenv,x
        inx
        bne @lv
@lvd:   jsr dsize               ; doff/dsz for the new form
        sta dnewsz
        lda count
        beq @inst
        jsr relayout
@inst:  ; the new form
        lda dn
        sta nfields
        ldx #0
@cf:    cpx dn
        bcs @cfd
        lda dkind,x
        sta fkind,x
        lda dlenv,x
        sta flen,x
        lda dlist,x
        sta flist,x
        stx dk_i
        jsr dnptr
        lda ptr2
        sta rq
        lda ptr2+1
        sta rq+1
        ldx dk_i
        jsr fnameptr
        ldy #15
@cn:    lda (rq),y
        sta (ptr1),y
        dey
        bpl @cn
        ldx dk_i
        inx
        bne @cf
@cfd:   jsr fdsetup
        jsr initpool
        lda #$FF
        sta sortkey
        lda #0
        sta sortdesc
        sta selactive
        jsr clearcrit
        jsr formchanged
        jsr numberfix
        jsr showall
        lda #0
        sta sel
        sta top
        lda #1
        sta dirty
        lda #2
        sta redraw
        rts

        .segment "RODATA"
s_working: .byte "Changing the form", G_DOTS, 0
        .segment "CODE"

; ---------------------------------------------------------------
; relayout: move the records into the slots of the new record size,
; converting each one.  First the records are put in slot order (record
; i in slot i); then, from the last one when records grow (the first
; when they shrink), each is read, converted and written to its new
; slot, which never overlaps a record not yet converted.
; ---------------------------------------------------------------
relayout:
        lda recsize
        bne @os
        lda #1
@os:    sta dold
        lda dnewsz
        bne @ns
        lda #1
@ns:    sta dnew
        ; 1. record i into slot i (old layout)
        lda dold
        sta sa_sz
        jsr poolcaps
        lda #0
        sta rl_i
@c1:    lda rl_i
        cmp count
        jcs @step2
        sta sa_k
        jsr slotaddr
        ldx rl_i
        jsr rl_issa
        jeq @c1n
        ldx rl_i                ; find the entry that has slot i
@fj:    inx
        cpx maxrec
        jcs @c1n                ; (can't happen)
        jsr rl_issa
        bne @fj
        stx rl_j
        lda dold                ; swap the two records' bytes
        sta bk_len
        ldx rl_i
        jsr rl_bk
        lda #<CACHE1
        sta bk_buf
        lda #>CACHE1
        sta bk_buf+1
        jsr blkread
        jsr rl_bksa
        lda #<CACHE2
        sta bk_buf
        lda #>CACHE2
        sta bk_buf+1
        jsr blkread
        lda #<CACHE1
        sta bk_buf
        lda #>CACHE1
        sta bk_buf+1
        jsr blkwrite            ; record i -> slot i
        ldx rl_i
        jsr rl_bk
        lda #<CACHE2
        sta bk_buf
        lda #>CACHE2
        sta bk_buf+1
        jsr blkwrite            ; the other one -> record i's old slot
        ldx rl_i                ; and swap the table entries
        ldy rl_j
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
@c1n:   inc rl_i
        jne @c1
        ; 2. convert, in the safe direction
@step2: lda dnew
        cmp dold
        bcc @asc
        beq @asc
        ldx count               ; growing: from the last record
@g:     dex
        stx rl_i
        jsr rl_conv
        ldx rl_i
        bne @g
        rts
@asc:   lda #0
        sta rl_i
@a:     lda rl_i
        cmp count
        bcs @d
        jsr rl_conv
        inc rl_i
        bne @a
@d:     rts

; rl_issa: does table entry X hold slot (sa_bank, sa_addr)?  Z = yes
rl_issa:
        lda PTRLO,x
        cmp sa_addr
        bne @d
        lda PTRHI,x
        cmp sa_addr+1
        bne @d
        lda PTRBK,x
        cmp sa_bank
@d:     rts

; rl_bk: bk_bank/bk_addr = table entry X.  rl_bksa: = sa_bank/sa_addr
rl_bk:  lda PTRLO,x
        sta bk_addr
        lda PTRHI,x
        sta bk_addr+1
        lda PTRBK,x
        sta bk_bank
        rts
rl_bksa:
        lda sa_addr
        sta bk_addr
        lda sa_addr+1
        sta bk_addr+1
        lda sa_bank
        sta bk_bank
        rts

; rl_conv: record rl_i: old slot -> CACHE1, convert to CACHE2, new slot
rl_conv:
        lda dold
        sta sa_sz
        sta bk_len
        jsr poolcaps
        lda rl_i
        sta sa_k
        jsr slotaddr
        jsr rl_bksa
        lda #<CACHE1
        sta bk_buf
        lda #>CACHE1
        sta bk_buf+1
        jsr blkread
        lda #1
        sta f2t_mode
        lda #0
        sta rl_f
@f:     lda rl_f
        cmp dn
        bcs @w
        ldx rl_f
        lda #<CACHE2
        sta rp
        lda #>CACHE2
        sta rp+1
        jsr rl_newfk
        ldx rl_f
        lda dsrc,x
        cmp #$FF
        beq @blank
        tax                     ; old field -> text
        lda #<CACHE1
        sta rp
        lda #>CACHE1
        sta rp+1
        jsr getfk
        jsr f2t
        lda #<CACHE2
        sta rp
        lda #>CACHE2
        sta rp+1
        ldx rl_f
        jsr rl_newfk
        jsr t2f
        bcc @nx
@blank: jsr fblank
@nx:    inc rl_f
        bne @f
@w:     lda #0
        sta f2t_mode
        lda dnew
        sta sa_sz
        sta bk_len
        jsr poolcaps
        lda rl_i
        sta sa_k
        jsr slotaddr
        jsr rl_bksa
        lda #<CACHE2
        sta bk_buf
        lda #>CACHE2
        sta bk_buf+1
        jmp blkwrite

; rl_newfk: X = new field -> fk_*
rl_newfk:
        lda dkind,x
        sta fk_k
        lda doff,x
        sta fk_o
        lda dlenv,x
        sta fk_l
        rts

        .segment "BSS"
dn:       .res 1
drow:     .res 1
dcol:     .res 1
dkind:    .res MAXFIELDS
dlist:    .res MAXFIELDS
dsrc:     .res MAXFIELDS
dlenv:    .res MAXFIELDS
doff:     .res MAXFIELDS
dsz:      .res MAXFIELDS
dname:    .res MAXFIELDS*16
dltxt:    .res MAXFIELDS*4
dd_i:     .res 1
dd_dir:   .res 1
dd_old:   .res 1
dr_r:     .res 1
dc_a:     .res 1
dc_b:     .res 1
dk_i:     .res 1
dk_j:     .res 1
ds_tot:   .res 2
ds_x:     .res 1
dnewsz:   .res 1
dnewcap:  .res 1
dold:     .res 1
dnew:     .res 1
rl_i:     .res 1
rl_j:     .res 1
rl_f:     .res 1
