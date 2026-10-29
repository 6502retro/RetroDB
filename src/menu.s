; ---------------------------------------------------------------
; Menu bar and pull-down menus (mouse drag, click, or keyboard)
; ---------------------------------------------------------------
NMENUS = 5
SORTMENU = 3

        .segment "RODATA"
mtx:    .byte 1, 4, 10, 18, 24          ; title text column
mtw:    .byte 1, 4, 6, 4, 4             ; title width
mbx:    .byte 1, 3, 9, 17, 23           ; pull-down interior column
mbw:    .byte 17, 29, 23, 20, 22        ; pull-down interior width
mstart: .byte 0, 1, 10, 17, 33          ; first command of each menu

mt0:    .byte G_CA, 0
mt1:    .byte "File", 0
mt2:    .byte "Record", 0
mt3:    .byte "Sort", 0
mt4:    .byte "View", 0
mtlo:   .byte <mt0, <mt1, <mt2, <mt3, <mt4
mthi:   .byte >mt0, >mt1, >mt2, >mt3, >mt4

mi0:    .byte "About RetroDB", G_DOTS, 0
mi1:    .byte "New Database", G_DOTS, 0
mi2:    .byte "Open", G_DOTS, 0
mi3:    .byte "Save", 0
mi4:    .byte "Save As", G_DOTS, 0
mi5:    .byte "Revert to Saved", 0
mi6:    .byte "Design Form", G_DOTS, 0
mi7:    .byte "Import from Mouse Calc", G_DOTS, 0
mi8:    .byte "Export to Mouse Calc", G_DOTS, 0
mi9:    .byte "Quit", 0
mi10:   .byte "New Record", G_DOTS, 0
mi11:   .byte "Edit Record", G_DOTS, 0
mi12:   .byte "Duplicate Record", G_DOTS, 0
mi13:   .byte "Delete Record", 0
mi14:   .byte "Delete Selected", G_DOTS, 0
mi15:   .byte "Find", G_DOTS, 0
mi16:   .byte "Find Next", 0
mi33:   .byte "Select Records", G_DOTS, 0
mi34:   .byte "Show All Records", 0
mi35:   .byte "Report", G_DOTS, 0
s_nofld: .byte "(No fields yet)", 0
mikey:  .byte 0, 0,'O','S',0,0,0,'I','X','Q','N','E','C','D',0,'F','G'
        .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .byte 'L','A','R'

apptitle: .byte "RetroDB  by 6502Retro", 0

        .segment "DATA"
mcnt:   .byte 1, 9, 7, 1, 3             ; items (Sort: one per field)
milo:   .byte <mi0,<mi1,<mi2,<mi3,<mi4,<mi5,<mi6,<mi7,<mi8,<mi9
        .byte <mi10,<mi11,<mi12,<mi13,<mi14,<mi15,<mi16
        .res MAXFIELDS
        .byte <mi33,<mi34,<mi35
mihi:   .byte >mi0,>mi1,>mi2,>mi3,>mi4,>mi5,>mi6,>mi7,>mi8,>mi9
        .byte >mi10,>mi11,>mi12,>mi13,>mi14,>mi15,>mi16
        .res MAXFIELDS
        .byte >mi33,>mi34,>mi35

        .segment "CODE"

; buildsortmenu: the Sort menu lists "By <field>" for every field
buildsortmenu:
        lda nfields
        bne @have
        lda #1
        sta mcnt+SORTMENU
        lda #<s_nofld
        sta milo+CMD_SORT0
        lda #>s_nofld
        sta mihi+CMD_SORT0
        rts
@have:  sta mcnt+SORTMENU
        ldx #0
@f:     stx bs_f
        txa                     ; ptr2 = SORTNM + f * 20
        asl a
        asl a
        sta t0
        asl a
        asl a
        clc
        adc t0
        sta t1
        lda #0
        adc #0
        sta t2
        clc
        lda t1
        adc #<SORTNM
        sta ptr2
        lda t2
        adc #>SORTNM
        sta ptr2+1
        lda ptr2
        sta milo+CMD_SORT0,x
        lda ptr2+1
        sta mihi+CMD_SORT0,x
        ldy #0
        lda #'B'
        sta (ptr2),y
        iny
        lda #'y'
        sta (ptr2),y
        iny
        lda #' '
        sta (ptr2),y
        jsr fnameptr
        ldy #0
        lda (ptr1),y
        sta t0
        ldx #0
@c:     cpx t0
        beq @e
        inx
        txa
        tay
        lda (ptr1),y
        iny
        iny
        sta (ptr2),y
        jmp @c
@e:     txa
        clc
        adc #3
        tay
        lda #0
        sta (ptr2),y
        ldx bs_f
        inx
        cpx nfields
        bne @f
        rts

        .segment "CODE"

drawmenubar:
        lda #0
        sta cy
        jsr clrrow
        ldx #0
@t:     stx dm_i
        lda mtx,x
        sta cx
        dec cx
        lda #0
        cpx mopen
        bne @n
        lda #1
@n:     sta inv
        jsr space
        ldx dm_i
        lda mtlo,x
        ldy mthi,x
        jsr prt
        jsr space
        lda #0
        sta inv
        ldx dm_i
        inx
        cpx #NMENUS
        bne @t
        jsr drawdbname
        POS 59, 0
        PRT apptitle
        POS 0, 1
        lda #G_OVER
        ldx #80
        jmp rep

; drawpull: pull-down for mopen with item mhil highlighted
drawpull:
        ldx mopen
        lda mbx,x
        sta dp_x
        lda mbw,x
        sta dp_w
        lda mcnt,x
        sta dp_n
        lda mstart,x
        sta dp_first
        lda #0
        sta dp_r
@r:     lda dp_r
        clc
        adc #2
        sta cy
        ldx dp_x
        dex
        stx cx
        lda #0
        sta inv
        lda #G_RBAR
        jsr putch
        lda dp_r
        cmp mhil
        bne @n
        lda #1
        sta inv
@n:     ldx dp_w
        jsr spaces
        lda dp_x
        sta cx
        inc cx
        lda dp_r
        clc
        adc dp_first
        tax
        stx dp_c
        lda milo,x
        ldy mihi,x
        jsr prt
        ldx dp_c
        lda mikey,x
        beq @nk
        pha
        lda dp_x
        clc
        adc dp_w
        sec
        sbc #3
        sta cx
        lda #G_OA
        jsr putch
        pla
        jsr putch
@nk:    lda mopen               ; the Sort menu marks the current order
        cmp #SORTMENU
        bne @nc
        lda dp_r
        cmp sortkey
        bne @nc
        cmp nfields
        bcs @nc
        lda dp_x
        sta cx
        lda #G_CHECK
        ldx sortdesc
        beq @ck
        lda #G_DOWN
@ck:    jsr putch
@nc:    lda #0
        sta inv
        lda dp_x
        clc
        adc dp_w
        sta cx
        lda #G_LBAR
        jsr putch
        inc dp_r
        lda dp_r
        cmp dp_n
        jne @r
        lda dp_n
        clc
        adc #2
        sta cy
        lda dp_x
        sta cx
        lda #G_OVER
        ldx dp_w
        jmp rep

; menuhit: A = column on row 0 -> A = menu index or $FF
menuhit:
        sta t0
        ldx #0
@l:     lda mtx,x
        sec
        sbc #1
        cmp t0
        beq @y
        bcs @n
        lda mtx,x
        clc
        adc mtw,x
        cmp t0
        bcs @y
@n:     inx
        cpx #NMENUS
        bne @l
        lda #$FF
        rts
@y:     txa
        rts

; itemhit: mouse position -> A = item in mopen or $FF
itemhit:
        ldx mopen
        lda mrow
        sec
        sbc #2
        bcc @no
        cmp mcnt,x
        bcs @no
        sta t0
        lda mcol
        cmp mbx,x
        bcc @no
        sec
        sbc mbx,x
        cmp mbw,x
        bcs @no
        lda t0
        rts
@no:    lda #$FF
        rts

; menuloop: A = menu to open, X = 0 mouse (button held) / 1 keyboard
; returns A = command or $FF
menuloop:
        sta mopen
        lda #$FF
        sta mhil
        cpx #0
        beq @m
        lda #0
        sta mhil
@m:     stx msticky
        jsr hidecursor
@open:  jsr drawmenubar         ; the title in inverse
        jsr savebox             ; keep what the pull-down covers
        jsr drawpull
@loop:  jsr showcursor
        jsr kbget
        bcc @mouse
        jmp @key
@mouse: lda hasmouse
        beq @loop
        jsr pollmouse
        lda mrow
        bne @items
        lda mcol
        jsr menuhit
        cmp #$FF
        beq @trans
        cmp mopen
        beq @trans
        ldx mbtn
        bmi @switch
        ldx mmoved              ; an open menu follows the pointer only
        beq @trans              ; when it moves over another title
        ldx msticky
        beq @trans
@switch:
        pha
        jsr hidecursor
        jsr restbox
        pla
        sta mopen
        lda #$FF
        sta mhil
        jmp @open
@items: jsr itemhit
        cmp mhil
        beq @trans
        ldx mmoved
        bne @seth
        ldx mbtn
        bpl @trans
@seth:  sta mhil
        jsr hidecursor
        jsr drawpull
@trans: lda mrel
        beq @press
        lda mrow
        bne @relit
        lda #1
        sta msticky
        jmp @loop
@relit: jsr itemhit
        cmp #$FF
        jne @select
        lda msticky
        bne @loop2
        jmp @close
@loop2: jmp @loop
@press: lda mpress
        beq @loop2
        lda mrow
        beq @loop2
        jsr itemhit
        cmp #$FF
        bne @loop2
        jmp @close
@key:   cmp #$1B
        jeq @close
        cmp #$08
        beq @left
        cmp #$15
        beq @right
        cmp #$0B
        beq @up
        cmp #$0A
        beq @down
        cmp #$0D
        bne @loop2
        lda mhil
        cmp #$FF
        beq @loop2
        jmp @select
@left:  ldx mopen
        dex
        bpl @setm
        ldx #NMENUS-1
@setm:  stx ms_new
        jsr hidecursor
        jsr restbox
        lda ms_new
        sta mopen
        lda #0
        sta mhil
        lda #1
        sta msticky
        jmp @open
@right: ldx mopen
        inx
        cpx #NMENUS
        bcc @setm
        ldx #0
        beq @setm
@up:    ldx mhil
        dex
        bpl @seth2
        ldy mopen
        ldx mcnt,y
        dex
@seth2: stx mhil
        jsr hidecursor
        jsr drawpull
        jmp @loop
@down:  ldx mhil
        inx
        ldy mopen
        txa
        cmp mcnt,y
        bcc @dn2
        ldx #0
@dn2:   stx mhil
        jsr hidecursor
        jsr drawpull
        jmp @loop
@select:
        clc
        ldx mopen
        adc mstart,x
        sta mcmd
        jmp @exit
@close: lda #$FF
        sta mcmd
@exit:  jsr hidecursor
        jsr restbox             ; put the screen back
        lda #$FF
        sta mopen
        jsr drawmenubar
        lda mcmd
        rts

; savebox / restbox: the screen under menu mopen's pull-down
MENUSAVE = $0D00
savebox:
        lda #0
        beq sbox
restbox:
        lda #$80
sbox:   sta sb_dir
        ldx mopen
        lda mbx,x
        sec
        sbc #1
        sta sb_x0
        lda mbw,x
        clc
        adc #2
        sta sb_w
        lda mcnt,x
        clc
        adc #1
        sta sb_h
        lda #<MENUSAVE
        sta rq
        lda #>MENUSAVE
        sta rq+1
        lda #2
        sta cy
@r:     lda sb_x0
        sta cx
        lda sb_w
        sta sb_n
@c:     ldy #0
        bit sb_dir
        bmi @put
        jsr getsc
        ldy #0
        sta (rq),y
        inc cx
        jmp @nx
@put:   lda (rq),y
        jsr putsc
@nx:    inc rq
        bne @n2
        inc rq+1
@n2:    dec sb_n
        bne @c
        inc cy
        dec sb_h
        bne @r
        rts

        .segment "BSS"
mopen:    .res 1
mhil:     .res 1
msticky:  .res 1
mcmd:     .res 1
dm_i:     .res 1
dp_x:     .res 1
dp_w:     .res 1
dp_n:     .res 1
dp_r:     .res 1
dp_c:     .res 1
dp_first: .res 1
bs_f:     .res 1
ms_new:   .res 1
sb_dir:   .res 1
sb_x0:    .res 1
sb_w:     .res 1
sb_h:     .res 1
sb_n:     .res 1
SORTNM:   .res MAXFIELDS*20
