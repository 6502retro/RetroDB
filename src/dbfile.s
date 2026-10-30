; ---------------------------------------------------------------
; Several databases: New Database, Open, Save As, the shared
; "save changes?" prompt, and remembering the last database used.
;
; Databases are text files in the RetroDB folder whose first line is
; RETRODB1.  RETRODB.LAST holds the name of the one to open at startup.
; ---------------------------------------------------------------
        .segment "RODATA"
t_open:    .byte "Open Database", 0
s_openh:   .byte "Databases in this folder:", 0
b_open:    .byte "Open", 0
pk_open:   .word t_open, s_openh, b_open
t_saveas:  .byte "Save As", 0
s_sal1:    .byte "Save this database under a new", 0
s_sal2:    .byte "name in the RetroDB folder:", 0
nd_saveas: .word t_saveas, s_sal1, s_sal2, b_save, NEWNAME
s_noinv:   .byte "There are no databases in this|"
           .byte "folder yet. Choose New Database|"
           .byte "to start one.", 0
al_noinv:  .word t_open, s_noinv
           .byte 1
           .word b_ok
s_badinv:  .byte "That name belongs to a file that|"
           .byte "is not a database. Please|"
           .byte "choose another name.", 0
al_badinv: .word t_saveas, s_badinv
           .byte 1
           .word b_ok
al_badnm2: .word t_saveas, s_badname
           .byte 1
           .word b_ok
s_badname: .byte "A ProDOS name starts with a letter|"
           .byte "and has up to 15 letters, digits|"
           .byte "and periods.", 0
b_replace: .byte "Replace", 0
s_invex:   .byte "A database with that name|"
           .byte "already exists. Replace it?", 0
al_invex:  .word t_saveas, s_invex
           .byte 2
           .word b_replace, b_cancel
s_savq1:   .byte "Save changes to ", 0
s_savq2:   .byte "|before closing it?", 0
al_savech: .word t_alert, MSGBUF
           .byte 3
           .word b_save, b_dont, b_cancel
s_untitled: .byte "Untitled", 0
s_invlbl:  .byte "Database: ", 0
s_lastnm:  .byte 12, "RETRODB.LAST"

        .segment "DATA"
NEWNAME:   .byte 0
           .res 15
OLDNAME:   .res 16
nfi_p:     .byte $0A
           .word NEWNAME
           .byte 0
nfi_type:  .byte 0
           .res 13
lopen_p:   .byte 3
lo_path:   .word s_lastnm
           .word FILEBUF
lo_ref:    .byte 0
lcreate_p: .byte 7
           .word s_lastnm
           .byte $C3, $04
           .word $0000
           .byte $01
           .word 0, 0

        .segment "CODE"

; copy16: copy the 16-byte name at ptr1 to ptr2
copy16: ldy #15
@l:     lda (ptr1),y
        sta (ptr2),y
        dey
        bpl @l
        rts

; namecmp: Z set if length-prefixed names at ptr1 and ptr2 match
namecmp:
        ldy #0
        lda (ptr1),y
        cmp (ptr2),y
        bne @d
        tay
@l:     lda (ptr1),y
        cmp (ptr2),y
        bne @d
        dey
        bne @l
@d:     rts

; setp1 / setp2: ptr1 / ptr2 = A/Y
setp1:  sta ptr1
        sty ptr1+1
        rts
setp2:  sta ptr2
        sty ptr2+1
        rts

; ---------------------------------------------------------------
; the database name on the menu bar
; ---------------------------------------------------------------
drawdbname:
        lda #0
        sta cy
        sta inv
        lda #31
        sta cx
        PRT s_invlbl
        lda named
        bne @n
        PRT s_untitled
        rts
@n:     LDAY pathname
        jsr setp1
        jmp prtlen

; ---------------------------------------------------------------
; askdirty: if there are unsaved changes, offer to save them.
; Carry clear = go ahead, carry set = the user cancelled.
; ---------------------------------------------------------------
askdirty:
        lda dirty
        beq @ok
        jsr mb_reset
        LDAY s_savq1
        jsr mb_str
        lda named
        bne @nm
        LDAY s_untitled
        jsr mb_str
        jmp @q
@nm:    LDAY pathname
        jsr setp1
        jsr mb_fld
@q:     LDAY s_savq2
        jsr mb_str
        LDAY al_savech
        jsr alert
        cmp #1
        beq @ok                 ; Don't Save
        cmp #0
        bne @no                 ; Cancel
        jsr save_any
        bcs @no
@ok:    clc
        rts
@no:    sec
        rts

; save_any: Save, or Save As when the database has no name yet.
; Carry clear = saved.
save_any:
        lda named
        bne save_cur
        jmp saveas_flow
save_cur:
        LDAY s_saving
        jsr statusmsg
        jsr dosave
        bcc @ok
        jsr saveerror
        sec
        rts
@ok:    clc
        rts

; ---------------------------------------------------------------
; commands
; ---------------------------------------------------------------
cmd_save:
        lda #2
        sta redraw
        lda nfields
        beq @x                  ; nothing to save yet
        jmp save_any
@x:     rts

cmd_saveas:
        lda #2
        sta redraw
        lda nfields
        beq @x
        jmp saveas_flow
@x:     rts

cmd_newdb:
        lda #2
        sta redraw
        jsr askdirty
        bcs @x
        jsr clearform
        lda #0
        sta named
        sta dirty
        jsr drawall
        jmp cmd_design
@x:     rts

cmd_quit:
        lda #2
        sta redraw
        jsr askdirty
        bcs @x
        jmp doquit
@x:     rts

cmd_revert:
        lda #2
        sta redraw
        lda named
        beq @x
        lda dirty
        beq @x
        LDAY al_revert
        jsr alert
        cmp #0
        bne @x
        jsr doload
        bcc @ok
        pha
        lda #0
        sta named
        pla
        jsr loaderror
@ok:    jmp overwarn
@x:     rts

cmd_open:
        lda #2
        sta redraw
        jsr askdirty
        bcc @scan
        rts
@scan:  jsr drawall
        jsr scandb
        bcc @sc
        jmp loaderror
@sc:    lda ndir
        bne @pick
        LDAY al_noinv
        jmp alert
@pick:  LDAY pk_open
        jsr setpick
        jsr pickdialog
        bcc @chosen
        rts
@chosen:
        ; keep the current name, then switch to the chosen file
        LDAY pathname
        jsr setp1
        LDAY OLDNAME
        jsr setp2
        jsr copy16
        lda named
        sta oldnamed
        jsr dselptr
        LDAY pathname
        jsr setp2
        jsr copy16
        LDAY s_opening
        jsr statusmsg
        jsr doload
        bcc @ok
        ; couldn't open it: go back to the previous database
        pha
        LDAY OLDNAME
        jsr setp1
        LDAY pathname
        jsr setp2
        jsr copy16
        lda oldnamed
        sta named
        beq @nr
        jsr doload
        bcc @nr
        lda #0
        sta named
@nr:    pla
        jmp loaderror
@ok:    lda #1
        sta named
        jsr writelast
        jsr drawall
        jmp overwarn

        .segment "RODATA"
s_opening: .byte "Opening", G_DOTS, 0
        .segment "CODE"

; dselptr: ptr1 = DIRNAMES entry dsel
dselptr:
        lda dsel
dirptr: asl a
        asl a
        asl a
        asl a
        clc
        adc #<DIRNAMES
        sta ptr1
        lda #>DIRNAMES
        adc #0
        sta ptr1+1
        rts

; ---------------------------------------------------------------
; Save As
; ---------------------------------------------------------------
saveas_flow:
        ; suggest the current name
        lda named
        beq @blank
        LDAY pathname
        jsr setp1
        LDAY NEWNAME
        jsr setp2
        jsr copy16
        jmp @dlg
@blank: lda #0
        sta NEWNAME
@dlg:   LDAY nd_saveas
        jsr namedialog
        bcc @chk
        lda #2
        sta redraw
        sec
        rts
@chk:   lda #2
        sta redraw
        lda NEWNAME
        beq @bad
        lda NEWNAME+1
        cmp #'A'
        bcc @bad
        cmp #'Z'+1
        bcc @nown
@bad:   LDAY al_badnm2
        jsr alert
        jmp @dlg
@nown:  jsr ownname             ; RetroDB's own files
        beq @notinv
        ; does a file with this name exist already?
        MLICALL $C4, nfi_p
        bcs @free               ; no: fine
        lda nfi_type
        cmp #$04
        bne @notinv
        LDAY NEWNAME            ; a text file, but a database?
        jsr setp1
        jsr isdb
        bcs @notinv
        ; the database that is already open: just save over it
        lda named
        beq @ask
        LDAY NEWNAME
        jsr setp1
        LDAY pathname
        jsr setp2
        jsr namecmp
        beq @free
@ask:   LDAY al_invex
        jsr alert
        cmp #0
        beq @free
        jmp @dlg
@notinv:
        LDAY al_badinv
        jsr alert
        jmp @dlg
@free:  ; save under the new name; on failure keep the old one
        LDAY pathname
        jsr setp1
        LDAY OLDNAME
        jsr setp2
        jsr copy16
        lda named
        sta oldnamed
        LDAY NEWNAME
        jsr setp1
        LDAY pathname
        jsr setp2
        jsr copy16
        LDAY s_saving
        jsr statusmsg
        jsr dosave
        bcc @saved
        pha
        LDAY OLDNAME
        jsr setp1
        LDAY pathname
        jsr setp2
        jsr copy16
        lda oldnamed
        sta named
        pla
        jsr saveerror
        sec
        rts
@saved: lda #1
        sta named
        jsr writelast
        clc
        rts

; ownname: Z set if NEWNAME is RETRODB.LAST, .SAVING or .SYSTEM
ownname:
        LDAY NEWNAME
        jsr setp1
        LDAY s_lastnm
        jsr setp2
        jsr namecmp
        beq @d
        LDAY tmpname
        jsr setp2
        jsr namecmp
        beq @d
        LDAY s_sysnm
        jsr setp2
        jsr namecmp
@d:     rts

        .segment "RODATA"
s_sysnm:   .byte 14, "RETRODB.SYSTEM"
        .segment "CODE"

; ---------------------------------------------------------------
; scandb: DIRNAMES = the databases in the RetroDB folder
; ---------------------------------------------------------------
scandb: lda #$04
        sta sd_type
        jmp scandir

; dbfilter: keep only the databases among DIRNAMES sd_start..ndir-1
dbfilter:
        lda sd_start
        sta si_i
        sta si_o
@l:     lda si_i
        cmp ndir
        bcs @done
        sta dsel
        jsr dselptr
        LDAY s_lastnm           ; never list RETRODB.LAST
        jsr setp2
        jsr namecmp
        beq @skip
        jsr isdb
        bcs @skip
        ; move entry si_i down to si_o
        jsr dselptr
        lda si_o
        jsr dirptr2
        jsr copy16
        inc si_o
@skip:  inc si_i
        jmp @l
@done:  lda si_o
        sta ndir
        rts

; dirptr2: ptr2 = DIRNAMES entry A
dirptr2:
        asl a
        asl a
        asl a
        asl a
        clc
        adc #<DIRNAMES
        sta ptr2
        lda #>DIRNAMES
        adc #0
        sta ptr2+1
        rts

; isdb: does the file named at ptr1 start with RETRODB1?  carry clear = yes
isdb:   lda ptr1
        sta lo_path
        lda ptr1+1
        sta lo_path+1
        MLICALL $C8, lopen_p
        bcs @no
        lda lo_ref
        sta open_ref
        jsr setrefs
        MLICALL $C9, newline_p
        jsr readline
        php
        MLICALL $CC, close_p
        plp
        bcs @no
        jmp hdrok
@no:    sec
        rts

; ---------------------------------------------------------------
; RETRODB.LAST: remember the database in use
; ---------------------------------------------------------------
; writelast: errors (such as a write-protected disk) are ignored
writelast:
        LDAY s_lastnm
        sta lo_path
        sty lo_path+1
        MLICALL $C0, lcreate_p
        MLICALL $C8, lopen_p
        bcs @d
        lda lo_ref
        sta open_ref
        jsr setrefs
        MLICALL $D0, seteof_p
        jsr lb_reset
        LDAY pathname
        jsr setp1
        ldy #0
        lda (ptr1),y
        sta t1
@l:     cpy t1
        beq @w
        iny
        lda (ptr1),y
        jsr lb_char
        jmp @l
@w:     jsr lb_write
        MLICALL $CC, close_p
@d:     rts

; readlast: if RETRODB.LAST names a database, put it in pathname.
; carry set if there is none.
readlast:
        LDAY s_lastnm
        sta lo_path
        sty lo_path+1
        MLICALL $C8, lopen_p
        bcs @no
        lda lo_ref
        sta open_ref
        jsr setrefs
        MLICALL $C9, newline_p
        jsr readline
        php
        MLICALL $CC, close_p
        plp
        bcs @no
        ; check: 1-15 characters, starting with a letter
        lda LINEBUF
        cmp #'A'
        bcc @no
        cmp #'Z'+1
        bcs @no
        ldx #0
@n:     lda LINEBUF,x
        beq @len
        inx
        cpx #16
        bcc @n
@no:    sec
        rts
@len:   stx pathname
@cp:    lda LINEBUF-1,x
        sta pathname,x
        dex
        bne @cp
        LDAY pathname           ; only follow it to a database
        jsr setp1
        jmp isdb

        .segment "BSS"
named:    .res 1
oldnamed: .res 1
si_i:     .res 1
si_o:     .res 1
DIRNAMES: .res 14*16
