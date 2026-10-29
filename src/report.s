; ---------------------------------------------------------------
; Sorting, and the Report
; ---------------------------------------------------------------
        .segment "CODE"

; cmd_sort: A = field.  Sorting by the same field again reverses it.
cmd_sort:
        cmp nfields
        bcc @ok
        rts
@ok:    ldx #2
        stx redraw
        cmp sortkey
        bne @new
        lda sortdesc
        eor #1
        sta sortdesc
        jmp @go
@new:   sta sortkey
        lda #0
        sta sortdesc
@go:    lda count
        cmp #2
        bcc @d
        lda #<s_sorting
        ldy #>s_sorting
        jsr statusmsg
        jsr treeon              ; By Part Of: tree order
        bcc @so
        lda #0
        sta sortdesc
        jsr dotree
        jmp @sd
@so:    jsr dosort
@sd:    jsr notab_inval
        lda #1
        sta dirty
@d:     jsr rebuildview
        lda #0
        sta sel
        sta top
        rts

; Shell sort of the record tables by field sortkey (gaps n/2 ... 1)
dosort: ldx sortkey
        jsr getfk
        lda foff,x
        sta rc2_off
        lda fsize,x
        sta rc2_len
        lda count
        lsr a
        sta so_g
@g:     lda so_g
        beq @d
        sta so_i
@i:     lda so_i
        cmp count
        bcs @ng
        sta so_j
@j:     lda so_j
        cmp so_g
        bcc @ni
        jsr recget2             ; rp2 = record j
        lda so_j
        sec
        sbc so_g
        sta so_k
        ldx sortkey
        jsr recgetf             ; rp = record j-gap
        jsr before              ; carry set: record j belongs before j-gap
        bcc @ni
        ldx so_j
        ldy so_k
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
        lda so_k
        sta so_j
        jmp @j
@ni:    inc so_i
        bne @i
@ng:    lsr so_g
        jmp @g
@d:     rts

; before: carry set if rp2 sorts before rp (descending: the other way)
before: lda sortdesc
        bne @rev
        jmp fless
@rev:   jsr @swap
        jsr fless
        php
        jsr @swap
        plp
        rts
@swap:  ldx rp
        lda rp2
        sta rp
        stx rp2
        ldx rp+1
        lda rp2+1
        sta rp+1
        stx rp2+1
        rts

        .segment "RODATA"
s_sorting: .byte "Sorting", G_DOTS, 0
        .segment "CODE"

; strless: carry set if string ptr1 < string ptr2 (case-insensitive)
strless:
        ldy #0
        lda (ptr1),y
        sta sl_a
        lda (ptr2),y
        sta sl_b
        ldx #0
@l:     cpx sl_a
        beq @end1
        cpx sl_b
        beq @ge
        txa
        tay
        iny
        lda (ptr2),y
        jsr toupper
        sta sl_c
        lda (ptr1),y
        jsr toupper
        cmp sl_c
        bcc @lt
        bne @ge
        inx
        bne @l
@end1:  cpx sl_b
        beq @ge
@lt:    sec
        rts
@ge:    clc
        rts

; ---------------------------------------------------------------
; Report: records grouped by one field, with the total of another
; ---------------------------------------------------------------
MAXGRP  = 9             ; named groups; the rest go in "All others"
GKEYW   = 21

        .segment "RODATA"
t_report: .byte "Report", 0
s_rgrp:   .byte "Group by:", 0
s_rsum:   .byte "Total of:", 0
s_rnone:  .byte "(none)", 0
s_rrecs:  .byte "Records", 0
s_rgroup: .byte "Group", 0
s_rtotal: .byte "Total", 0
s_rothers: .byte "All others", 0
s_rblank: .byte "(blank)", 0
s_ravg:   .byte "Average:", 0
s_rhigh:  .byte "Highest:", 0
s_rlow:   .byte "Lowest:", 0
t_report2: .byte "Report on the Selected Records", 0
s_rhint:  .byte G_LEFT, G_RIGHT, " change  TAB switch", 0
        .segment "CODE"

cmd_report:
        lda nfields
        bne @go
        rts
@go:    ; default choices
        jsr totfield
        lda #$FF
        bcs @ns
        lda st_f
@ns:    sta rs_f
        lda #$FF
        sta rg_f
        ldx nf_po               ; group by Part Of, if there is one
        cpx #$FF
        bne @gset
        ldx #1                  ; group by a short Text field after the
@tl:    cpx nfields             ; first, or else the first Yes/No field
        bcs @yn0
        lda fkind,x
        cmp #K_TEXT
        bne @tn
        lda flen,x
        cmp #21
        bcc @gset
@tn:    inx
        bne @tl
@yn0:   ldx #0
@yn:    cpx nfields
        bcs @gd
        lda fkind,x
        cmp #K_YESNO
        beq @gset
        inx
        bne @yn
@gset:  stx rg_f
@gd:    lda #0
        sta rfoc
@full:  jsr tally
        jsr hidecursor
        jsr drawreport
@loop:  jsr getevent
        cmp #EV_KEY
        bne @mouse
        lda keych
        cmp #$0D
        beq @x
        cmp #$1B
        beq @x
        cmp #$09
        beq @tab
        cmp #$08
        beq @prev
        cmp #$15
        beq @next
        cmp #' '
        beq @next
        jmp @loop
@tab:   lda rfoc
        eor #1
        sta rfoc
        jsr drawrsel
        jmp @loop
@next:  lda #1
        bne @step
@prev:  lda #$FF
@step:  jsr rstep
        jmp @full
@mouse: lda mrow
        cmp #22
        bne @m1
        lda mcol
        cmp #64
        bcc @loop
        cmp #68
        bcc @x
        jmp @loop
@m1:    cmp #4
        bne @loop
        ldx #0
        lda mcol
        cmp #38
        bcc @m2
        inx
@m2:    stx rfoc
        lda mcol                ; the left arrow steps back
        cmp #20
        beq @prev
        cmp #50
        beq @prev
        bne @next
@x:     lda #2
        sta redraw
        rts

; rstep: A = +1/-1: the next choice for the focused selector
rstep:  sta rr_dir
        lda rfoc
        bne @sum
        lda rg_f                ; group: none, fields 0..n-1
        clc
        adc rr_dir
        cmp #$FE
        bne @g1
        ldx nfields
        dex
        txa
@g1:    cmp nfields
        bcc @g2
        cmp #$FF
        beq @g2
        lda #$FF
@g2:    sta rg_f
        rts
@sum:   lda rs_f                ; total: none, or a Number/Money field
@s1:    clc
        adc rr_dir
        cmp #$FE
        bne @s2
        lda nfields             ; back from none: the last field
        sec
        sbc #1
@s2:    cmp #$FF
        beq @set
        cmp nfields
        bcc @chk
        lda #$FF
        bne @set
@chk:   tax
        lda fkind,x
        jsr isnumk
        txa
        bcs @set
        jmp @s1
@set:   sta rs_f
        rts

; tally: count and total the records in the view
tally:  lda #0
        sta ng
        sta rothers
        sta rnb
        sta rt_i
        ldx #4
@z:     sta sum40,x
        sta roth_sum,x
        dex
        bpl @z
        sta roth_cnt
        lda #$FF
        sta rhi_r
        sta rlo_r
@l:     lda rt_i
        cmp vcount
        bcc @rec
        rts
@rec:   tax
        lda VIEW,x
        sta rt_r
        jsr recget
        lda #$FF
        sta rt_g
        lda rg_f
        cmp #$FF
        beq @sum
        jsr findgroup           ; rt_g = group index ($FF: All others)
@sum:   lda rs_f
        cmp #$FF
        beq @cnt
        tax
        jsr getfk
        jsr isblank
        beq @cnt
        inc rnb
        jsr addfld40            ; overall total
        lda rt_g
        cmp #$FF
        beq @oth
        jsr gsumptr
        jmp @add
@oth:   lda #<roth_sum
        sta ptr2
        lda #>roth_sum
        sta ptr2+1
@add:   jsr addfldp             ; group total
        jsr minmax
@cnt:   lda rg_f
        cmp #$FF
        beq @nx
        ldx rt_g
        cpx #$FF
        beq @oc
        inc gcnt,x
        jmp @nx
@oc:    inc roth_cnt
@nx:    inc rt_i
        jmp @l

; gsumptr: ptr2 = the total of group rt_g
gsumptr:
        lda rt_g
        asl a
        asl a
        adc rt_g
        adc #<gsum
        sta ptr2
        lda #>gsum
        adc #0
        sta ptr2+1
        rts

; addfldp: 5-byte total at ptr2 += field fk_* of rp
addfldp:
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
        ldx #0
        cmp #$80
        bcc @p
        dex
@p:     stx num+4
        ldy #0
        clc
        lda (ptr2),y
        adc num
        sta (ptr2),y
        iny
        lda (ptr2),y
        adc num+1
        sta (ptr2),y
        iny
        lda (ptr2),y
        adc num+2
        sta (ptr2),y
        iny
        lda (ptr2),y
        adc num+3
        sta (ptr2),y
        iny
        lda (ptr2),y
        adc num+4
        sta (ptr2),y
        rts

; minmax: the highest and lowest values so far (field fk_* of rp)
minmax: lda rhi_r
        cmp #$FF
        beq @set                ; the first one
        ldx #0                  ; value > highest?
        jsr cmpmm
        bcc @lo
        bne @hi
@lo:    ldx #4                  ; value < lowest?
        jsr cmpmm
        bcs @d
        jmp @setlo
@hi:    jmp @sethi
@set:   jsr @sethi
@setlo: ldy fk_o
        ldx #0
@l1:    lda (rp),y
        sta rlo_v,x
        iny
        inx
        cpx #4
        bne @l1
        lda rt_r
        sta rlo_r
@d:     rts
@sethi: ldy fk_o
        ldx #0
@l2:    lda (rp),y
        sta rhi_v,x
        iny
        inx
        cpx #4
        bne @l2
        lda rt_r
        sta rhi_r
        rts

; cmpmm: compare the field with rhi_v (X=0) or rlo_v (X=4), signed.
; carry set = field >= it (Z clear = field > it)
cmpmm:  ldy fk_o
        lda (rp),y
        cmp rhi_v,x
        bne @ne
        iny
        lda (rp),y
        cmp rhi_v+1,x
        bne @ne
        iny
        lda (rp),y
        cmp rhi_v+2,x
        bne @ne
        iny
        lda (rp),y
        cmp rhi_v+3,x
        bne @ne
        lda #0                  ; equal: carry set, Z set
        sec
        rts
@ne:    ldy fk_o
        sec
        lda (rp),y
        sbc rhi_v,x
        iny
        lda (rp),y
        sbc rhi_v+1,x
        iny
        lda (rp),y
        sbc rhi_v+2,x
        iny
        lda (rp),y
        sbc rhi_v+3,x
        bvc @v
        eor #$80
@v:     bmi @lt
        lda #1                  ; more: carry set, Z clear
        sec
        rts
@lt:    lda #1
        clc
        rts

; findgroup: rt_g = the group for field rg_f of rp (adding it if new)
findgroup:
        ldx rg_f
        jsr getfk
        lda #0
        sta f2t_mode
        jsr f2t
        cmp #GKEYW-1
        bcc @k
        lda #GKEYW-1
        tax
        lda #0
        sta TMPSTR,x
@k:     lda #0
        sta rt_g
@s:     lda rt_g                ; existing group?  (kept in order)
        cmp ng
        bcs @ins
        jsr gkeyptr
        jsr gkeycmp             ; A: 0 equal, 1 key < TMPSTR, 2 key > TMPSTR
        beq @d
        cmp #2
        beq @ins
        inc rt_g
        bne @s
@ins:   lda ng                  ; a new group at rt_g, if there is room
        cmp #MAXGRP
        bcc @room
        lda #$FF
        sta rt_g
@d:     rts
@room:  ldx ng                  ; move groups rt_g.. down one
@mv:    cpx rt_g
        beq @put
        dex
        stx fg_x
        jsr gmove
        ldx fg_x
        jmp @mv
@put:   inc ng
        ldx rt_g
        lda #0
        sta gcnt,x
        jsr gsumptr
        ldy #4
        lda #0
@zs:    sta (ptr2),y
        dey
        bpl @zs
        jsr gkeyptr             ; key = TMPSTR
        ldx #0
        ldy #1
@kc:    lda TMPSTR,x
        beq @ke
        sta (ptr1),y
        inx
        iny
        bne @kc
@ke:    txa
        ldy #0
        sta (ptr1),y
        rts

; gmove: group X -> group X+1
gmove:  lda gcnt,x
        sta gcnt+1,x
        txa                     ; sums: 5 bytes
        asl a
        asl a
        stx fg_y
        adc fg_y
        tay
        ldx #5
@s:     lda gsum,y
        sta gsum+5,y
        iny
        dex
        bne @s
        lda fg_y                ; keys: 21 bytes
        jsr gkeyoff
        tay
        ldx #GKEYW
@k:     lda gkey,y
        sta gkey+GKEYW,y
        iny
        dex
        bne @k
        ldx fg_y
        rts

; gkeyoff: A = group -> A = offset of its key (group * 21)
gkeyoff:
        sta t0
        asl a
        asl a
        sta t1                  ; *4
        asl a
        asl a                   ; *16
        clc
        adc t1
        adc t0                  ; *21
        rts

; gkeyptr: ptr1 = the key of group rt_g
gkeyptr:
        lda rt_g
        jsr gkeyoff
        clc
        adc #<gkey
        sta ptr1
        lda #>gkey
        adc #0
        sta ptr1+1
        rts

; gkeycmp: compare the key at ptr1 with TMPSTR (any case)
gkeycmp:
        ldy #0
        lda (ptr1),y
        sta t2
        ldx #0
@l:     cpx t2
        beq @kend
        lda TMPSTR,x
        beq @gt                 ; key is longer: key > text
        jsr toupper
        sta t3
        inx
        txa
        tay
        lda (ptr1),y
        jsr toupper
        cmp t3
        beq @l
        bcc @lt
@gt:    lda #2
        rts
@lt:    lda #1
        rts
@kend:  lda TMPSTR,x
        bne @lt                 ; key is shorter
        lda #0
        rts

; ---------------------------------------------------------------
; drawing the report
; ---------------------------------------------------------------
RG_NAME = 10
RG_CNT  = 34
RG_SUM  = 46
RG_SUMW = 18

drawreport:
        lda #8
        sta wx
        lda #2
        sta wy
        lda #64
        sta ww
        lda #20
        sta wh
        lda #<t_report
        ldy #>t_report
        ldx selactive
        beq @tt
        lda #<t_report2
        ldy #>t_report2
@tt:    jsr drawwin
        POS 44, 5
        PRT s_rhint
        POS RG_NAME, 4
        PRT s_rgrp
        POS 40, 4
        PRT s_rsum
        jsr drawrsel
        ; headings
        POS RG_NAME, 6
        lda rg_f
        cmp #$FF
        beq @gh
        tax
        jsr fnameptr
        jsr prtlen
        jmp @h2
@gh:    PRT s_rgroup
@h2:    POS RG_CNT, 6
        PRT s_rrecs
        lda rs_f
        cmp #$FF
        beq @h3
        tax
        jsr fnameptr
        jsr fld2tmp
        lda #1
        sta pf_right
        lda #RG_SUM
        sta cx
        lda #RG_SUMW
        jsr prtfit
@h3:    ; the groups
        lda #0
        sta rt_g
@g:     lda rt_g
        cmp ng
        bcs @oth
        clc
        adc #7
        sta cy
        jsr gkeyptr
        ldy #0
        lda (ptr1),y
        bne @gk
        LDAY s_rblank
        jsr strtmp
        jmp @gp
@gk:    jsr fld2tmp
@gp:    ldx rt_g
        lda gcnt,x
        sta rd_cnt
        jsr gsumptr
        jsr rrow
        inc rt_g
        bne @g
@oth:   lda roth_cnt
        beq @line
        lda ng
        clc
        adc #7
        sta cy
        LDAY s_rothers
        jsr strtmp
        lda roth_cnt
        sta rd_cnt
        lda #<roth_sum
        sta ptr2
        lda #>roth_sum
        sta ptr2+1
        jsr rrow
@line:  POS RG_NAME, 17
        lda #G_OVER
        ldx #54
        jsr rep
        lda #18
        sta cy
        LDAY s_rtotal
        jsr strtmp
        lda vcount
        sta rd_cnt
        lda #<sum40
        sta ptr2
        lda #>sum40
        sta ptr2+1
        jsr rrow
        lda rs_f                ; average, highest, lowest
        cmp #$FF
        jeq @btn
        lda rnb
        jeq @btn
        POS RG_NAME, 20
        PRT s_ravg
        POS RG_NAME+10, 20
        ldx #4
@ac:    lda sum40,x
        sta num,x
        dex
        bpl @ac
        jsr avg40
        ldx rs_f
        lda fkind,x
        jsr s40txt
        lda #0
        sta pf_right
        lda #20
        jsr prtfit
        POS RG_NAME, 21
        PRT s_rhigh
        lda rhi_r
        ldx #<rhi_v
        ldy #>rhi_v
        jsr rextreme
        POS RG_NAME, 22
        PRT s_rlow
        lda rlo_r
        ldx #<rlo_v
        ldy #>rlo_v
        jsr rextreme
@btn:   POS 64, 22
        lda #<s_ok
        ldy #>s_ok
        ldx #1
        jmp drawbtn

; rextreme: record A's first field, then the value at X/Y
rextreme:
        stx rq
        sty rq+1
        jsr recget
        lda #RG_NAME+10
        sta cx
        ldx nf_nm               ; the record's name: its first Text field
        cpx #$FF
        bne @nm
        ldx #0
@nm:    jsr getfk
        lda #0
        sta f2t_mode
        jsr f2t
        lda #0
        sta pf_right
        lda #24
        jsr prtfit
        jsr space
        ldy #3                  ; the value, sign-extended to 40 bits
        lda (rq),y
        ldx #0
        cmp #$80
        bcc @p
        dex
@p:     stx num+4
@c:     lda (rq),y
        sta num,y
        dey
        bpl @c
        ldx rs_f
        lda fkind,x
        jsr s40txt
        lda #0
        sta pf_right
        lda #16
        jmp prtfit

; rrow: one table row at cy: TMPSTR, rd_cnt records, total at ptr2
rrow:   lda #RG_NAME
        sta cx
        lda #0
        sta pf_right
        lda #22
        jsr prtfit
        lda #RG_CNT
        sta cx
        lda rd_cnt
        jsr setnum8
        ldx #7
        jsr prnum
        lda rs_f
        cmp #$FF
        beq @d
        ldy #4
@c:     lda (ptr2),y
        sta num,y
        dey
        bpl @c
        ldx rs_f
        lda fkind,x
        jsr s40txt
        lda #1
        sta pf_right
        lda #RG_SUM
        sta cx
        lda #RG_SUMW
        jsr prtfit
@d:     rts

; drawrsel: the two choices on row 4, the focused one in inverse
drawrsel:
        POS 20, 4
        lda #0
        jsr @one
        POS 50, 4
        lda #1
@one:   sta t4
        lda #G_LEFT
        jsr putch
        jsr space
        lda #0
        ldx t4
        cpx rfoc
        bne @n
        lda #1
@n:     sta inv
        lda rg_f
        ldx t4
        beq @g
        lda rs_f
@g:     cmp #$FF
        bne @f
        LDAY s_rnone
        jsr strtmp
        jmp @p
@f:     tax
        jsr fnameptr
        jsr fld2tmp
@p:     lda #0
        sta pf_right
        lda #MAXNAME
        jsr prtfit
        lda #0
        sta inv
        jsr space
        lda #G_RIGHT
        jmp putch

; strtmp: zero-terminated A/Y -> TMPSTR
strtmp: sta ptr3
        sty ptr3+1
        ldy #0
@l:     lda (ptr3),y
        sta TMPSTR,y
        beq @d
        iny
        bne @l
@d:     rts

; s40txt: num (signed 40-bit) as kind A -> TMPSTR ($ for Money)
s40txt: sta st_k
        lda #0
        sta f2_n
        lda num+4
        bpl @p
        jsr negnum
        lda #'-'
        jsr f2_put
@p:     lda st_k
        cmp #K_MONEY
        beq @m
        jsr fmtnum
        LDAY numbuf
        jmp @s
@m:     jsr fmtmoney0
        LDAY moneybuf
@s:     jsr f2_zstr
        ldx f2_n
        lda #0
        sta TMPSTR,x
        rts

; avg40: num (signed 40-bit) / rnb, rounded
avg40:  lda #0
        sta av_neg
        lda num+4
        bpl @p
        jsr negnum
        inc av_neg
@p:     lda #0                  ; num /= rnb, remainder in A
        ldy #40
@l:     asl num
        rol num+1
        rol num+2
        rol num+3
        rol num+4
        rol a
        bcs @sub                ; (9-bit remainder)
        cmp rnb
        bcc @n
@sub:   sbc rnb
        inc num
@n:     dey
        bne @l
        asl a                   ; round half up
        bcs @up
        cmp rnb
        bcc @r
@up:    lda #1
        jsr addnum8
@r:     lda av_neg
        beq @d
        jsr negnum
@d:     rts

        .segment "BSS"
skey:     .res 1
so_i:     .res 1
so_j:     .res 1
so_g:     .res 1
so_k:     .res 1
sl_a:     .res 1
sl_b:     .res 1
sl_c:     .res 1
rg_f:     .res 1
rs_f:     .res 1
rfoc:     .res 1
rr_dir:   .res 1
ng:       .res 1
gcnt:     .res MAXGRP+1
gsum:     .res (MAXGRP+1)*5
gkey:     .res (MAXGRP+1)*GKEYW
rothers:  .res 1
roth_cnt: .res 1
roth_sum: .res 5
rnb:      .res 1
rt_i:     .res 1
rt_r:     .res 1
rt_g:     .res 1
rhi_r:    .res 1
rlo_r:    .res 1
rhi_v:    .res 4
rlo_v:    .res 4
fg_x:     .res 1
fg_y:     .res 1
rd_cnt:   .res 1
st_k:     .res 1
av_neg:   .res 1
