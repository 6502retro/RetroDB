; ---------------------------------------------------------------
; Record memory.
;
; Records live in three pools, in this order: main memory $1000-$3FFF
; (over the title picture once it is gone), the auxiliary 64K
; ($0800-$BFFF, when the Apple has 128K and /RAM is empty), and main
; memory from the end of the program to $BAFF.  Every record of a form
; has the same size, so slot k of the pools is at a fixed place.
;
; PTRLO/PTRHI/PTRBK list the slots in record order; the first count
; are in use.  recget fetches a record: a main-memory record is used
; where it is, an auxiliary one is copied to CACHE1.  recput copies
; it back (it does nothing for main-memory records).
; ---------------------------------------------------------------
        .segment "CODE"

; ---------------------------------------------------------------
; auxinit: decide whether the auxiliary 64K can hold records.
; It can if the Apple has 128K and /RAM is absent or empty; an empty
; /RAM is disconnected (and put back when MouseDB quits).
; ---------------------------------------------------------------
auxinit:
        lda #0
        sta auxok
        sta ramoff
        sta ramfull
        lda MACHID
        and #$30
        cmp #$30
        bne @d                  ; not 128K
        lda DEVADR32
        cmp NODEV
        bne @ram
        lda DEVADR32+1
        cmp NODEV+1
        beq @ok                 ; no /RAM
@ram:   jsr ramempty
        bcs @full
        ldx DEVCNT              ; take /RAM out of the device list
@f:     lda DEVLST,x
        and #$F0
        cmp #$B0
        beq @got
        dex
        bpl @f
        bmi @nod
@got:   lda DEVLST,x
        sta ramunit
@sh:    cpx DEVCNT
        beq @sd
        lda DEVLST+1,x
        sta DEVLST,x
        inx
        bne @sh
@sd:    dec DEVCNT
@nod:   lda DEVADR32
        sta ramsave
        lda DEVADR32+1
        sta ramsave+1
        lda NODEV
        sta DEVADR32
        lda NODEV+1
        sta DEVADR32+1
        lda #1
        sta ramoff
@ok:    lda #1
        sta auxok
@d:     rts
@full:  lda #1
        sta ramfull
        rts

; ramempty: carry clear if /RAM holds no files
ramempty:
        lda #$B0
        sta rol_unit
        MLICALL $C5, rol_p
        bcs @no
        lda PREFIXBUF+1         ; "/" + volume name
        and #$0F
        beq @no
        tax
        inx
        stx mc_path
@cp:    lda PREFIXBUF,x
        sta mc_path,x
        dex
        cpx #1
        bne @cp
        lda #'/'
        sta mc_path+1
        MLICALL $C8, ropen_p
        bcs @no
        lda ro_ref
        sta rrd_ref
        sta rcl_ref
        MLICALL $CA, rread_p
        php
        MLICALL $CC, rclose_p
        plp
        bcs @no
        lda DIRBUF+$25          ; file count in the directory header
        ora DIRBUF+$26
        bne @no
        clc
        rts
@no:    sec
        rts

; raminstall: put /RAM back if auxinit took it out (on quitting)
raminstall:
        lda ramoff
        beq @d
        lda #0
        sta ramoff
        lda ramsave
        sta DEVADR32
        lda ramsave+1
        sta DEVADR32+1
        lda ramunit
        beq @fmt
        inc DEVCNT
        ldx DEVCNT
        sta DEVLST,x
@fmt:   lda #3                  ; FORMAT, the way Apple's Technical
        sta $42                 ; Note ProDOS #10 describes
        lda #$B0
        sta $43
        lda #$00
        sta $44
        lda #$20
        sta $45
        lda $C08B
        lda $C08B
        jsr @call
        bit $C082
@d:     rts
@call:  jmp (ramsave)

        .segment "DATA"
rol_p:    .byte 2
rol_unit: .byte $B0
          .word PREFIXBUF+1
ropen_p:  .byte 3
          .word mc_path
          .word FILEBUF
ro_ref:   .byte 0
rread_p:  .byte 4
rrd_ref:  .byte 0
          .word DIRBUF
          .word 512
          .word 0
rclose_p: .byte 1
rcl_ref:  .byte 0
        .segment "CODE"

; ---------------------------------------------------------------
; pools
; ---------------------------------------------------------------
; poolcaps: pc_cap0..2 = how many records of size A fit in each pool
; (each at most 250)
poolcaps:
        sta pc_sz
        lda #<(POOLA_END-POOLA)
        ldx #>(POOLA_END-POOLA)
        jsr @cap
        sta pc_cap0
        lda #0
        ldx auxok
        beq @na
        lda #<(AUXPOOL_END-AUXPOOL)
        ldx #>(AUXPOOL_END-AUXPOOL)
        jsr @cap
@na:    sta pc_cap1
        sec
        lda #<POOLB_END
        sbc #<POOLB
        tay
        lda #>POOLB_END
        sbc #>POOLB
        tax
        tya
        jsr @cap
        sta pc_cap2
        rts
; A/X = pool length -> A = min(250, length / pc_sz)
@cap:   sta dv_n
        stx dv_n+1
        lda #0
        sta dv_q
        sta dv_q+1
        lda pc_sz
        beq @big
        ldy #16
        lda #0
@dl:    asl dv_n
        rol dv_n+1
        rol a
        bcs @ds                 ; (a 9-bit remainder)
        cmp pc_sz
        bcc @dn
@ds:    sbc pc_sz
        inc dv_n
@dn:    dey
        bne @dl
        lda dv_n+1              ; quotient is in dv_n
        bne @big
        lda dv_n
        cmp #MAXREC
        bcc @r
@big:   lda #MAXREC
@r:     rts

; slotaddr: sa_k = slot, sa_sz = record size, caps from poolcaps
; -> sa_bank, sa_addr
slotaddr:
        lda sa_k
        cmp pc_cap0
        bcs @n0
        ldx #0
        stx sa_bank
        ldx #<POOLA
        ldy #>POOLA
        jmp @mul
@n0:    sec
        sbc pc_cap0
        cmp pc_cap1
        bcs @n1
        ldx #1
        stx sa_bank
        ldx #<AUXPOOL
        ldy #>AUXPOOL
        jmp @mul
@n1:    sbc pc_cap1
        ldx #0
        stx sa_bank
        ldx #<POOLB
        ldy #>POOLB
@mul:   stx sa_addr             ; sa_addr = base + A * sa_sz
        sty sa_addr+1
        sta t0
        lda #0
        sta t2
        lda sa_sz
        sta t1
        ldx #8
@ml:    lsr t1
        bcc @mn
        clc
        lda sa_addr
        adc t0
        sta sa_addr
        lda sa_addr+1
        adc t2
        sta sa_addr+1
@mn:    asl t0
        rol t2
        dex
        bne @ml
        rts

; initpool: lay out slots for records of recsize bytes; sets maxrec
initpool:
        lda recsize
        bne @s
        lda #1
@s:     sta sa_sz
        jsr poolcaps
        clc
        lda pc_cap0
        adc pc_cap1
        bcs @cap
        adc pc_cap2
        bcs @cap
        cmp #MAXREC
        bcc @st
@cap:   lda #MAXREC
@st:    sta maxrec
        lda #0
        sta sa_k
@l:     lda sa_k
        cmp maxrec
        bcs @d
        jsr slotaddr
        ldx sa_k
        lda sa_addr
        sta PTRLO,x
        lda sa_addr+1
        sta PTRHI,x
        lda sa_bank
        sta PTRBK,x
        inc sa_k
        bne @l
@d:     rts

; capfor: A = record size -> A = how many records of that size fit
capfor: jsr poolcaps
        clc
        lda pc_cap0
        adc pc_cap1
        bcs @cap
        adc pc_cap2
        bcs @cap
        cmp #MAXREC
        bcc @d
@cap:   lda #MAXREC
@d:     rts

; ---------------------------------------------------------------
; fetching and storing records
; ---------------------------------------------------------------
; recget: A = record index -> rp (whole record)
recget: tax
        lda #0
        sta rc_off
        lda recsize
        sta rc_len
        jmp rc_go
; recgetf: A = record index, X = field -> rp (only that field is valid)
recgetf:
        pha
        lda foff,x
        sta rc_off
        lda fsize,x
        sta rc_len
        pla
        tax
rc_go:  lda PTRLO,x
        sta rc_addr
        lda PTRHI,x
        sta rc_addr+1
        lda PTRBK,x
        sta rc_bank
        bne @aux
        lda #0
        sta rc_nofetch
        lda rc_addr
        sta rp
        lda rc_addr+1
        sta rp+1
        rts
@aux:   lda #<CACHE1
        sta rp
        lda #>CACHE1
        sta rp+1
        lda rc_nofetch
        bne @d
        lda rc_len
        beq @d
        clc                     ; aux -> CACHE1
        jsr rc_range
        clc
        jsr auxmv
@d:     lda #0
        sta rc_nofetch
        rts

; recgetw: like recget, for a record about to be written in full
recgetw:
        ldx #1
        stx rc_nofetch
        jmp recget

; recput: copy the record (range) fetched by recget back to aux memory
recput: lda rc_bank
        beq @d
        lda rc_len
        beq @d
        sec
        jsr rc_range
        sec
        jsr auxmv
@d:     rts

; rc_range: carry clear = aux -> CACHE1, set = CACHE1 -> aux.
; Sets A1, A2 and A4 for AUXMOVE.
rc_range:
        php
        clc
        lda rc_addr
        adc rc_off
        sta rr_a
        lda rc_addr+1
        adc #0
        sta rr_a+1
        clc
        lda #<CACHE1
        adc rc_off
        sta rr_c
        lda #>CACHE1
        adc #0
        sta rr_c+1
        plp
        bcs @put
        lda rr_a                ; source: aux
        sta A1L
        lda rr_a+1
        sta A1L+1
        lda rr_c
        sta A4L
        lda rr_c+1
        sta A4L+1
        jmp @end
@put:   lda rr_c
        sta A1L
        lda rr_c+1
        sta A1L+1
        lda rr_a
        sta A4L
        lda rr_a+1
        sta A4L+1
@end:   clc                     ; A2 = A1 + len - 1
        lda A1L
        adc rc_len
        sta A2L
        lda A1L+1
        adc #0
        sta A2L+1
        lda A2L
        bne @dec
        dec A2L+1
@dec:   dec A2L
        rts

; auxmv: AUXMOVE with A1/A2/A4 set; carry set = main -> aux
auxmv:  php
        stx am_x
        sty am_y
        plp
        jsr AUXMOVE
        ldx am_x
        ldy am_y
        rts

; recget2: A = record index -> rp2 (whole record, aux ones in CACHE2).
; Used while sorting, together with recget.
recget2:
        tax
        lda PTRLO,x
        sta A1L
        lda PTRHI,x
        sta A1L+1
        lda PTRBK,x
        bne @aux
        lda A1L
        sta rp2
        lda A1L+1
        sta rp2+1
        rts
@aux:   lda #<CACHE2
        sta rp2
        sta A4L
        lda #>CACHE2
        sta rp2+1
        sta A4L+1
        lda rc2_off             ; only the bytes sorting needs
        clc
        adc A1L
        sta A1L
        bcc @a1
        inc A1L+1
@a1:    lda rc2_off
        clc
        adc A4L
        sta A4L
        bcc @a4
        inc A4L+1
@a4:    clc
        lda A1L
        adc rc2_len
        sta A2L
        lda A1L+1
        adc #0
        sta A2L+1
        lda A2L
        bne @dd
        dec A2L+1
@dd:    dec A2L
        clc
        jmp auxmv

; ---------------------------------------------------------------
; whole-slot copies for re-laying out the pools (design changes)
; bk_bank/bk_addr = slot, bk_len bytes, bk_buf = main buffer
; ---------------------------------------------------------------
blkread:
        lda bk_bank
        bne @aux
        lda bk_addr
        sta ptr1
        lda bk_addr+1
        sta ptr1+1
        lda bk_buf
        sta ptr2
        lda bk_buf+1
        sta ptr2+1
        jmp blkcopy
@aux:   lda bk_addr
        sta A1L
        lda bk_addr+1
        sta A1L+1
        lda bk_buf
        sta A4L
        lda bk_buf+1
        sta A4L+1
        jsr bk_end
        clc
        jmp auxmv

blkwrite:
        lda bk_bank
        bne @aux
        lda bk_buf
        sta ptr1
        lda bk_buf+1
        sta ptr1+1
        lda bk_addr
        sta ptr2
        lda bk_addr+1
        sta ptr2+1
        jmp blkcopy
@aux:   lda bk_buf
        sta A1L
        lda bk_buf+1
        sta A1L+1
        lda bk_addr
        sta A4L
        lda bk_addr+1
        sta A4L+1
        jsr bk_end
        sec
        jmp auxmv

bk_end: clc
        lda A1L
        adc bk_len
        sta A2L
        lda A1L+1
        adc #0
        sta A2L+1
        lda A2L
        bne @d
        dec A2L+1
@d:     dec A2L
        rts

; blkcopy: bk_len bytes from (ptr1) to (ptr2), main memory
blkcopy:
        ldy #0
@l:     cpy bk_len
        beq @d
        lda (ptr1),y
        sta (ptr2),y
        iny
        bne @l
@d:     rts

        .segment "BSS"
auxok:    .res 1
ramoff:   .res 1
ramfull:  .res 1
ramsave:  .res 2
ramunit:  .res 1
pc_sz:    .res 1
pc_cap0:  .res 1
pc_cap1:  .res 1
pc_cap2:  .res 1
dv_n:     .res 2
dv_q:     .res 2
sa_k:     .res 1
sa_sz:    .res 1
sa_bank:  .res 1
sa_addr:  .res 2
rc_addr:  .res 2
rc_bank:  .res 1
rc_off:   .res 1
rc_len:   .res 1
rc_nofetch: .res 1
rc2_off:  .res 1
rc2_len:  .res 1
rr_a:     .res 2
rr_c:     .res 2
am_x:     .res 1
am_y:     .res 1
bk_bank:  .res 1
bk_addr:  .res 2
bk_len:   .res 1
bk_buf:   .res 2
CACHE1:   .res 256
CACHE2:   .res 256
