; ============================================================
;  SHADOW NINJA -  Commodore 64 beat-'em-up  (ACME, MOS 6510)
;  build:  acme -f cbm -o ninja_shadow.prg ninja_game.asm
;  Music : "Night Patrol" SID player by the supplied sid33_ninja_fm.asm
;          (bass voice changed from pulse to a soft triangle wave).
;  The file is generated: [music defs][game][music player/data][assets]
; ============================================================
!cpu 6510

; ============ CONSTANTS ============
SPEED = 7            ; frames per 16th tick (7 = ~107 BPM)

; zero page
seq_lo   = $20
seq_hi   = $23
dur      = $26
insoff   = $29
note     = $2c
wpos     = $2f
ctrl     = $32
gmask    = $35
tbit     = $38
bfl      = $3b
bfh      = $3e
pwl      = $41
pwh      = $44
pwsp     = $47
age      = $4a
cutt     = $4d
vu       = $50
fmd      = $53
fmp      = $56
vibd     = $80      ; vibrato depth nibble (0 = off)
vibp     = $83      ; vibrato phase
vibdel   = $86      ; vibrato delay in frames
mvol     = $87      ; master volume 0..15
mtgt     = $88      ; fade target
mrate    = $89      ; frames per fade step
mcnt     = $8a      ; fade frame counter

slot     = $60
frame    = $61
syncmode = $62
digi     = $63
froute   = $64
fmode    = $65
fcut     = $66
fdir     = $67
fmin     = $68
fmax     = $69
swpl     = $6a
swph     = $6b
m0l      = $6c
m0h      = $6d
outl     = $6e
outh     = $6f
tmp      = $70
tmp2     = $71
tmp3     = $72
t0       = $73
t1       = $74
t2       = $75
xsave    = $76
ysave    = $77
spd      = $78
hrfr     = $79
trans    = $7a
secnew   = $7b
fenv     = $8b      ; bass filter envelope (added to cutoff, decays)

FENV_START = $70    ; cutoff boost at each bass note-on

tp       = $f9
zptr     = $fb
zp2      = $fd

; instruments
I_SILENT   = 0
I_LEAD1    = 1
I_LEAD2    = 2
I_LEAD3    = 3
I_BKICK    = 4
I_BPLAIN   = 5
I_BLONG    = 6
I_BDIVE    = 7
I_BSAW     = 8
I_STAB     = 9
I_ARPMIN   = 10
I_ARPMAJ   = 11
I_HAT      = 12
I_OHAT     = 13
I_SNARE    = 14
I_TOM      = 15
I_TOMH     = 16
I_TOML     = 17
I_CRASH    = 18
I_CLAP     = 19
I_RISER    = 20
I_RUN      = 21
I_TICK     = 22
I_SHAKE    = 23
I_GHOST    = 24
I_BONGO    = 25
I_BGHOST   = 26
I_BSUB     = 27
I_PLUCK    = 28
I_ECHO     = 29

; note names: n_<note><octave>, s = sharp (as1 = A#1 = Bb1), C-0 = 0
n_c1 = 12
n_cs1 = 13
n_d1 = 14
n_ds1 = 15
n_e1 = 16
n_f1 = 17
n_fs1 = 18
n_g1 = 19
n_gs1 = 20
n_a1 = 21
n_as1 = 22
n_b1 = 23

n_c2 = 24
n_cs2 = 25
n_d2 = 26
n_ds2 = 27
n_e2 = 28
n_f2 = 29
n_fs2 = 30
n_g2 = 31
n_gs2 = 32
n_a2 = 33
n_as2 = 34
n_b2 = 35

n_c3 = 36
n_cs3 = 37
n_d3 = 38
n_ds3 = 39
n_e3 = 40
n_f3 = 41
n_fs3 = 42
n_g3 = 43
n_gs3 = 44
n_a3 = 45
n_as3 = 46
n_b3 = 47

n_c4 = 48
n_cs4 = 49
n_d4 = 50
n_ds4 = 51
n_e4 = 52
n_f4 = 53
n_fs4 = 54
n_g4 = 55
n_gs4 = 56
n_a4 = 57
n_as4 = 58
n_b4 = 59

n_c5 = 60
n_cs5 = 61
n_d5 = 62
n_ds5 = 63
n_e5 = 64
n_f5 = 65
n_fs5 = 66
n_g5 = 67
n_gs5 = 68
n_a5 = 69
n_as5 = 70
n_b5 = 71

n_c6 = 72
n_cs6 = 73
n_d6 = 74
n_ds6 = 75
n_e6 = 76
n_f6 = 77
n_fs6 = 78
n_g6 = 79
n_gs6 = 80
n_a6 = 81
n_as6 = 82
n_b6 = 83

n_c7 = 84
n_cs7 = 85
n_d7 = 86
n_ds7 = 87
n_e7 = 88
n_f7 = 89
n_fs7 = 90
n_g7 = 91
n_gs7 = 92
n_a7 = 93
n_as7 = 94
n_b7 = 95

; ============ MACROS ============

!macro nt .n, .d { !byte .n, .d }
!macro rs .d { !byte $80, .d }
!macro setins .i { !byte $81, .i }
!macro setflt .i { !byte $82, .i }
!macro settrans .i { !byte $84, .i }
!macro setspd .i { !byte $85, .i }
!macro sect .i { !byte $86, .i }
!macro fade .v0, .v1, .v2 { !byte $87, .v0, .v1, .v2 }


; ============================================================
;  NINJA SHADOW  -  Commodore 64  -  ACME (MOS 6510)
;  Joystick port 2 or 1 (or SPACE = fire):
;    LEFT/RIGHT  walk (the world scrolls with parallax)
;    UP          jump
;    FIRE        punch (head)          FIRE in air / UP+FIRE  head kick
;    DOWN        guard (block)         DOWN+FIRE              throw shuriken
;
;  VIC-II tricks used: raster-IRQ split screen (sky/ground palette
;  gradients), per-band fine X scroll ($d016) = 6 parallax layers,
;  38-column mode, multicolour char graphics, per-band shared colours
;  ($d021-$d023), multicolour + X/Y-expanded sprites, sprite priority
;  (moon behind clouds), sprite shadow, opened bottom border, screen
;  shake ($d011 yscroll) and border flash on hits.
;  Music: "Night Patrol" 200 Hz SID player (triangle bass), SID sfx.
; ============================================================
OPEN_BORDER = 1          ; 0 = keep the normal bottom border

; ---------------- memory map ----------------
SCRRAM   = $8400
SPRPTR   = $87f8
GROUNDY  = 186
PXMIN    = 24
PXMAX    = 290
SCRL_R   = 200
SCRL_L   = 96

; ---------------- game zero page ($90-$bf) ----------------
pp       = $90
dp       = $92
zt1      = $94
zt2      = $95
zt3      = $96
zt4      = $97
zt5      = $98
zt6      = $99
dxa      = $9a
dxs      = $9b
joy      = $9c
joyp     = $9d
slw      = $9e
s16v     = $9f
s21v     = $a0
s22v     = $a1
s23v     = $a2
rndv     = $a4
ecur     = $a5
hreach   = $a6
hdmg     = $a7
hkd      = $a8
aaset    = $aa
aan      = $ab
aar      = $ac
aab      = $ad
aac      = $ae
pix      = $c100

; ---------------- game variables ($c000, not in the PRG) ----------------
sh_xl    = $c000
sh_y     = $c008
sh_p     = $c010
sh_msb   = $c018
sh_en    = $c019
vbl      = $c01a
lastv    = $c01b
evt      = $c01c
d011v    = $c01d
bord     = $c01e
shakev   = $c01f
bscr     = $c020
bco      = $c028
bold     = $c030
gstate   = $c038
gframe   = $c039
mbusy    = $c03a
shaket   = $c03b
walkf    = $c03d
gwait    = $c03e
pxl      = $c040
pxh      = $c041
py       = $c042
pvy      = $c043
pface    = $c044
pstate   = $c045
ptimer   = $c046
phealth      = $c047
pinv     = $c048
pblock   = $c049
pstars   = $c04a
pstart   = $c04b
pkbd     = $c04d
sc0      = $c050
sc1      = $c051
sc2      = $c052
sc3      = $c053
sc4      = $c054
gsl      = $c058
gsh      = $c059
cdl      = $c05a
cdh      = $c05b
cdc      = $c05c
es       = $c060
et       = $c062
ehp      = $c064
exl      = $c066
exh      = $c068
efc      = $c06a
ekd      = $c06c
sact     = $c078
sxl      = $c079
sxh      = $c07a
sdir     = $c07b
sy       = $c07c
pkt      = $c080
pkxl     = $c081
pkxh     = $c082
pky      = $c083
sfxt     = $c088
sfxf     = $c089
sfxs     = $c08a
sfxc     = $c08b
rawa     = $c0a0
rawb     = $c0a1
level    = $c0a2
armor    = $c0a3
svtl     = $c0a4
svth     = $c0a5
svn      = $c0a6
msgt     = $c0a7
tdelay   = $c0a8
blendv   = $c0b0
mooncol  = sp_c23+32
moonov   = sp_c23+34

PS_NORM  = 0
PS_PUNCH = 1
PS_KICK  = 2
PS_THROW = 3
PS_HURT  = 4
PF_IDLE1 = 0
PF_IDLE2 = 1
PF_WALK1 = 2
PF_JUMPUP = 6
PF_JUMPDN = 7
PF_PUNCHA = 8
PF_PUNCHB = 9
PF_KICKA = 10
PF_KICKB = 11
PF_BLOCK = 12
PF_THROWA = 13
PF_THROWB = 14
PF_HURT  = 15
ES_OFF     = 0
ES_WALK    = 1
ES_WIND    = 2
ES_STRIKE  = 3
ES_RECOVER = 4
ES_HURT    = 5
ES_DEAD    = 6
SFX_PUNCH = 0
SFX_KICK  = 1
SFX_THROW = 2
SFX_BLOCK = 3
SFX_HURT  = 4
SFX_KILL  = 5
SFX_JUMP  = 6
SFX_HIT   = 7

!macro ptxt .dst, .src {
        lda #<(.src)
        sta pp
        lda #>(.src)
        sta pp+1
        lda #<(.dst)
        sta dp
        lda #>(.dst)
        sta dp+1
        jsr put_text
}

; ============================================================
* = $0801
        !byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

!zone
start:
        sei
        cld
        ldx #$ff
        txs
        lda #$33                ; char ROM visible
        sta $01
        lda #<$d000             ; ROM chars 0-63 -> RAM charset
        sta pp
        lda #>$d000
        sta pp+1
        lda #<$8800
        sta dp
        lda #>$8800
        sta dp+1
        ldx #2
        jsr copy_pages
        lda #$35                ; I/O + RAM only
        sta $01
        lda #<tile_data
        sta pp
        lda #>tile_data
        sta pp+1
        lda #<$8a00
        sta dp
        lda #>$8a00
        sta dp+1
        ldx #TILE_PAGES
        jsr copy_pages
        lda #<spr_data
        sta pp
        lda #>spr_data
        sta pp+1
        lda #<$a000
        sta dp
        lda #>$a000
        sta dp+1
        ldx #SPR_PAGES
        jsr copy_pages
        jsr make_aa

        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #0
        sta $d01a
        lda #$ff
        sta $d019
        lda #<irq
        sta $fffe
        lda #>irq
        sta $ffff
        lda #<nmi
        sta $fffa
        lda #>nmi
        sta $fffb
        lda #$ff
        sta $dc02
        lda #$00
        sta $dc03
        lda #$ff
        sta $dc00
        lda $dd02
        ora #$03
        sta $dd02
        lda $dd00               ; VIC bank 2 ($8000-$bfff)
        and #$fc
        ora #$01
        sta $dd00
        lda #$12                ; screen $8400, charset $8800
        sta $d018
        lda #0
        sta $d020
        sta $d021
        sta $bfff               ; idle-state byte (open border)
        lda #$10
        sta $d016               ; multicolour, 38 columns
        lda #$1b
        sta $d011

        ; clear variable block
        lda #0
        tax
.cv:    sta $c000,x
        inx
        bne .cv
        lda #$5a
        sta rndv
        lda #3
        sta shakev
        lda #1
        sta blendv              ; colour blend on by default (key B toggles)
        lda #$1b
        sta d011v
        lda #$ff
        ldx #7
.bo:    sta bold,x
        dex
        bpl .bo

        jsr clear_screen
        jsr color_init
        jsr sprite_init
        jsr sid_reset
        jsr song_init
        jsr title_init
        jsr detect_ntsc

        lda #0
        sta evt
        lda ev_lo
        sta $d012
        lda #$1b
        sta $d011
        lda #$ff
        sta $d019
        lda #$01
        sta $d01a
        cli

!zone
mainloop:
        lda vbl
        cmp lastv
        beq mainloop
        sta lastv
        jsr update_bands
        jsr scroll_rows
        jsr game_update
        jsr build_sprites
        jmp mainloop

nmi:    rti

!zone
detect_ntsc:                    ; highest raster line seen: PAL 311, NTSC 262
        lda #0
        sta zt1
.w:     lda $d011
        bpl .w
.m:     lda $d011
        bpl .e
        lda $d012
        cmp zt1
        bcc .m
        sta zt1
        jmp .m
.e:     lda zt1
        cmp #20
        bcs .pal
        lda #0                  ; NTSC: no events beyond line 262
        sta evnext+20
.pal:   rts


!zone
copy_pages:                     ; pp -> dp, X pages
        ldy #0
.l:     lda (pp),y
        sta (dp),y
        iny
        bne .l
        inc pp+1
        inc dp+1
        dex
        bne .l
        rts

!zone
clear_screen:
        ldx #0
.l:     lda #$20
        sta $8400,x
        sta $8500,x
        sta $8600,x
        sta $8700,x
        inx
        bne .l
        rts

!zone
color_init:
        lda #<$d800
        sta dp
        lda #>$d800
        sta dp+1
        ldx #0
.r:     lda crow,x
        ldy #39
.f:     sta (dp),y
        dey
        bpl .f
        lda dp
        clc
        adc #40
        sta dp
        bcc .n
        inc dp+1
.n:     inx
        cpx #25
        bne .r
        rts

!zone
make_aa:                        ; build the fine-pixel (hires) edge layers from the body layers
        lda #0
        sta pix                 ; neighbours outside the 12 pixels
        sta pix+13
        lda #3
        sta aaset
.set:   ldx aaset
        lda aa_slo,x
        sta pp
        lda aa_shi,x
        sta pp+1
        lda aa_dlo,x
        sta dp
        lda aa_dhi,x
        sta dp+1
        lda aa_cnt,x
        sta aan
.blk:   lda #0
        sta aar
.row:   ldy aar
        ldx #1
.ub:    lda (pp),y              ; unpack 12 multicolour pixels of one row
        sta aab
        lsr
        lsr
        lsr
        lsr
        lsr
        lsr
        sta pix,x
        inx
        lda aab
        lsr
        lsr
        lsr
        lsr
        and #3
        sta pix,x
        inx
        lda aab
        lsr
        lsr
        and #3
        sta pix,x
        inx
        lda aab
        and #3
        sta pix,x
        inx
        iny
        cpx #13
        bne .ub
        ldy aar
        ldx #1
.ob:    lda #0
        sta aab
        lda #4
        sta aac
.px:    lda aab
        asl
        asl
        sta aab
        lda pix,x
        cmp #2
        bcc .nx                 ; only body / highlight pixels get a soft edge
        lda pix-1,x
        cmp #1
        bne .r1
        lda aab
        ora #2                  ; left half touches the outline
        sta aab
.r1:    lda pix+1,x
        cmp #1
        bne .nx
        lda aab
        ora #1                  ; right half touches the outline
        sta aab
.nx:    inx
        dec aac
        bne .px
        lda aab
        sta (dp),y
        iny
        cpx #13
        bne .ob
        lda aar
        clc
        adc #3
        sta aar
        cmp #63
        beq .rd
        jmp .row
.rd:    ldy #63
        lda #0
        sta (dp),y
        lda pp
        clc
        adc #64
        sta pp
        bcc .p1
        inc pp+1
.p1:    lda dp
        clc
        adc #64
        sta dp
        bcc .p2
        inc dp+1
.p2:    dec aan
        beq .bd
        jmp .blk
.bd:
        dec aaset
        bmi .done
        jmp .set
.done:  rts

!zone
sprite_init:
        lda #$56
        sta $d01c               ; multicolour: sprites 1,2,4,6 (colour layers)
        lda #0
        sta $d025               ; shared colour A = black (outline)
        lda #1
        sta $d026               ; shared colour B = white (highlights)
        lda #6
        sta $d027               ; 0 ninja fine edge pixels: dark blue
        lda #2
        sta $d028               ; 1 ninja detail: red headband / sash
        lda #14
        sta $d029               ; 2 ninja body: light blue
        lda #9
        sta $d02a               ; 3 samurai 1 fine edge pixels: brown
        lda #8
        sta $d02b               ; 4 samurai 1 armour
        lda #9
        sta $d02c               ; 5 samurai 2 fine edge pixels
        lda #13
        sta $d02d               ; 6 samurai 2 armour
        rts

; ============================================================
;  RASTER IRQ CHAIN
; ============================================================
!zone
irq:
        pha
        txa
        pha
        tya
        pha
        ldy evt                 ; event being serviced
        ldx evnext,y
        stx evt                 ; X = next event
        lda ev_lo,x
        sta $d012
        lda d011v
        ora ev_hi,x
        sta $d011
        lda #$01
        sta $d019
        lda ev_type,y
        bne .d1
        jmp .top
.d1:    cmp #1
        bne .d2
        jmp .mus
.d2:    cmp #2
        bne .d3
        jmp .spl
.d3:    cmp #4
        bne .d4
        jmp .mx1
.d4:    cmp #5
        bne .d5
        jmp .mx2
.d5:
        ; ---- type 3: open the bottom border ----
        lda #OPEN_BORDER
        beq .out
        lda d011v
        and #$f7
        sta d011v
        ora ev_hi,x
        sta $d011
.out:   pla
        tay
        pla
        tax
        pla
        rti

.mx1:   lda sh_xl+3             ; sprites 3 and 5 go back to the samurai
        sta $d006
        lda sh_y+3
        sta $d007
        lda sh_p+3
        sta SPRPTR+3
        lda sh_xl+5
        sta $d00a
        lda sh_y+5
        sta $d00b
        lda sh_p+5
        sta SPRPTR+5
        lda #9
        sta $d02a
        sta $d02c
        lda #0
        sta $d01b               ; sprites in front of the scenery again
        lda sh_msb
        and #$28
        pha
        lda $d010
        and #$d7
        sta $d010
        pla
        ora $d010
        sta $d010
        lda sh_en
        and #$28
        pha
        lda $d015
        and #$d7
        sta $d015
        pla
        ora $d015
        sta $d015
        lda #$7f                ; sprite 7: spark / shuriken (unexpanded)
        sta $d017
        sta $d01d
        lda $d010
        and #$7f
        sta $d010
        lda $d015
        and #$7f
        sta $d015
        lda pkt
        beq .m1s
        lda pkxl
        sta $d00e
        lda pky
        sta $d00f
        lda pkt
        and #1
        clc
        adc #SPR_SPK
        sta SPRPTR+7
        lda #7
        sta $d02e
        lda pkxh
        and #1
        beq .m1a
        lda $d010
        ora #$80
        sta $d010
.m1a:   lda $d015
        ora #$80
        sta $d015
        jmp .out
.m1s:   lda sact
        beq .m1o
        lda sxl
        sta $d00e
        lda sy
        sta $d00f
        lda vbl
        lsr
        and #1
        clc
        adc #SPR_SH
        sta SPRPTR+7
        lda #15
        sta $d02e
        lda sxh
        and #1
        beq .m1b
        lda $d010
        ora #$80
        sta $d010
.m1b:   lda $d015
        ora #$80
        sta $d015
.m1o:   jmp .out

.mx2:   lda #$7f                ; sprite 7 -> player shadow (X expanded)
        sta $d017
        lda #$ff
        sta $d01d
        lda #0
        sta $d01b
        lda pxl
        sta $d00e
        lda #226
        sta $d00f
        lda #SPR_SHAD
        sta SPRPTR+7
        lda #11
        sta $d02e
        lda $d010
        and #$7f
        sta $d010
        lda pxh
        and #1
        beq .m2a
        lda $d010
        ora #$80
        sta $d010
.m2a:   lda $d015
        ora #$80
        sta $d015
        jmp .out

.top:   inc vbl
        lda shakev
        ora #$18
        sta d011v
        ora ev_hi,x
        sta $d011
        lda bord
        sta $d020
        lda #0
        sta $d021
        lda #$10
        sta $d016
        lda vbl                 ; colour blend: alternate two colours per frame
        and blendv
        tax
        lda scol0,x
        sta $d029
        lda scol1,x
        sta $d02b
        lda scol2,x
        sta $d02d
        ldx #6                  ; shadow sprite regs -> hardware
.cs:    txa
        asl
        tay
        lda sh_xl,x
        sta $d000,y
        lda sh_y,x
        sta $d001,y
        lda sh_p,x
        sta SPRPTR,x
        dex
        bpl .cs
        lda #250                ; moon = two stacked sprites (3: craters/shade, 5: disc),
        sta $d006               ; borrowed from the samurai who are idle up here
        sta $d00a
        lda #66
        sta $d007
        sta $d00b
        lda #SPR_MOONO
        sta SPRPTR+3
        lda #SPR_MOON
        sta SPRPTR+5
        lda #$7f
        sta $d017
        sta $d01d
        lda #$28
        sta $d01b               ; behind the clouds
        lda vbl
        and blendv
        tax
        lda mooncol,x
        sta $d02c
        lda moonov,x
        sta $d02a
        lda sh_msb
        and #$d7
        sta $d010
        lda sh_en
        ora #$28
        and #$7f
        sta $d015
        jmp .out

.mus:   lda mbusy
        beq .m0
        jmp .out
.m0:
        lda #1
        sta mbusy
        lda ev_arg,y
        sta slot
        cli
        jsr music_play
        sei
        lda #0
        sta mbusy
        jmp .out

.spl:   ldx ev_arg,y
        lda sp_lw,x
        sta slw
        lda sp_band,x
        tay
        txa                     ; colour set = (frame + bar number) & 1:
        clc                     ; neighbouring bars flicker in opposite phase
        adc vbl
        and blendv
        beq .ev
        txa
        clc
        adc #16
        tax
.ev:    lda sp_c21,x
        sta s21v
        lda sp_c22,x
        sta s22v
        lda sp_c23,x
        sta s23v
        lda bscr,y
        ora #$10
        sta s16v
.sy:    lda $d012               ; wait for the line before the band
        cmp slw
        bcc .sy
        ldx #8
.bn:    dex
        bne .bn
        lda s16v
        ldx s21v
        ldy s22v
        sta $d016
        stx $d021
        sty $d022
        lda s23v
        sta $d023
        jmp .out

; ============================================================
;  MUSIC GLUE (player from sid33_ninja_fm.asm) + SFX on voice 3
; ============================================================
!zone
music_play:
        lda slot
        beq .s0
        cmp #1
        bne .fx
        lda #0
        sta tbit
        sta tbit+1
        sta tbit+2
        jmp .fx
.s0:    jsr frame_logic
.fx:    jsr fast_fx
        jsr filter_step
        lda sfxt
        beq .r
        lda sfxf
        sta $d40f
        lda #0
        sta $d40e
        sta $d413
        lda #$08
        sta $d411
        lda #$f0
        sta $d414
        lda sfxc
        sta $d412
        lda sfxf
        clc
        adc sfxs
        sta sfxf
        dec sfxt
        bne .r
        lda sfxc
        and #$fe
        sta $d412
.r:     rts

!zone
sfx_play:                       ; A = sfx id (Y clobbered)
        asl
        asl
        tay
        lda sfxtab,y
        sta sfxc
        lda sfxtab+1,y
        sta sfxf
        lda sfxtab+2,y
        sta sfxs
        lda sfxtab+3,y
        sta sfxt
        rts

; ============================================================
;  PARALLAX BANDS
; ============================================================
!zone
update_bands:
        inc cdc                 ; slow cloud drift
        lda cdc
        cmp #10
        bcc .d
        lda #0
        sta cdc
        inc cdl
        bne .d
        inc cdh
.d:
        lda gsl                 ; band 1: S/16
        sta zt1
        lda gsh
        sta zt2
        ldy #4
        jsr shr
        ldx #1
        jsr calc_band
        lda gsl                 ; band 2: S/8 + drift
        sta zt1
        lda gsh
        sta zt2
        ldy #3
        jsr shr
        lda zt1
        clc
        adc cdl
        sta zt1
        lda zt2
        adc cdh
        sta zt2
        ldx #2
        jsr calc_band
        lda gsl                 ; band 3: S/4
        sta zt1
        lda gsh
        sta zt2
        ldy #2
        jsr shr
        ldx #3
        jsr calc_band
        lda gsl                 ; band 4: S/2
        sta zt1
        lda gsh
        sta zt2
        ldy #1
        jsr shr
        ldx #4
        jsr calc_band
        lda gsl                 ; band 5: S - S/4
        sta zt1
        lda gsh
        sta zt2
        ldy #2
        jsr shr
        lda gsl
        sec
        sbc zt1
        sta zt1
        lda gsh
        sbc zt2
        sta zt2
        ldx #5
        jsr calc_band
        lda gsl                 ; band 6: S
        sta zt1
        lda gsh
        sta zt2
        ldx #6
        jmp calc_band

!zone
shr:                            ; zt2:zt1 >>= Y
.l:     lsr zt2
        ror zt1
        dey
        bne .l
        rts

!zone
calc_band:                      ; zt2:zt1 = pixel position, X = band
        lda zt1
        and #$07
        sta zt3
        beq .a
        lda #8
        sec
        sbc zt3
.a:     sta bscr,x
        lsr zt2                 ; position / 8 = map column
        ror zt1
        lsr zt2
        ror zt1
        lsr zt2
        ror zt1
        lda zt1
        ldy zt3
        beq .c
        clc
        adc #1
.c:     and bmask,x
        sta bco,x
        rts

!zone
scroll_rows:
        ldx #1
.b:     lda bco,x
        cmp bold,x
        beq .n
        sta bold,x
        txa
        pha
        jsr redraw_band
        pla
        tax
.n:     inx
        cpx #7
        bne .b
        rts

!zone
redraw_band:                    ; X = band
        lda brs,x
        sta zt5
        lda bre,x
        sta zt6
        lda bco,x
        sta zt3
.r:     ldy zt5
        lda prow_lo,y
        clc
        adc zt3
        sta pp
        lda prow_hi,y
        adc #0
        sta pp+1
        lda srow_lo,y
        sta dp
        lda srow_hi,y
        sta dp+1
        ldy #39
.c:     lda (pp),y
        sta (dp),y
        dey
        bpl .c
        inc zt5
        lda zt5
        cmp zt6
        bcc .r
        beq .r
        rts

; ============================================================
;  INPUT
; ============================================================
!zone
read_input:
        lda #$ff
        sta $dc00
        lda $dc00               ; port 2
        sta rawa
        lda $dc01               ; port 1
        sta rawb
        and rawa
        pha
        lda #$ef                ; keyboard column 4: SPACE (row 7), B (row 3)
        sta $dc00
        lda $dc01
        sta zt1
        and #$80
        bne .ns
        pla
        and #$ef                ; SPACE = fire
        pha
.ns:    lda zt1
        and #$08
        bne .nb
        pla
        and #$df                ; B = bit 5
        pha
.nb:    lda #$fd                ; keyboard column 1: RETURN (row 0)
        sta $dc00
        lda $dc01
        and #$01
        bne .nr
        pla
        and #$ef                ; RETURN = fire
        pha
.nr:    lda #$ff
        sta $dc00
        pla
        eor #$ff
        and #$3f
        sta joy
        rts

!zone
fire_edge:                      ; C=1 on fire press
        lda joy
        and #$10
        beq .no
        lda joyp
        and #$10
        bne .no
        sec
        rts
.no:    clc
        rts

!zone
rnd:
        lda rndv
        asl
        bcc .n
        eor #$1d
.n:     eor $d012
        sta rndv
        rts

; ============================================================
;  GAME STATES
; ============================================================
!zone
game_update:
        inc gframe
        jsr read_input
        lda joy                 ; B = colour blend on/off
        and #$20
        beq .nb
        lda joyp
        and #$20
        bne .nb
        lda blendv
        eor #1
        sta blendv
.nb:
        lda gstate
        beq .t
        cmp #1
        beq .p
        jsr gameover_update
        jmp .e
.t:     jsr title_update
        jmp .e
.p:     jsr play_update
.e:     lda joy
        sta joyp
        rts

!zone
title_init:
        lda #0
        sta gstate
        lda #30
        sta tdelay
        jsr clear_hud
        +ptxt SCRRAM+1, txt_title
        +ptxt SCRRAM+40+1, txt_hint
        +ptxt SCRRAM+40+32, txt_blend
        +ptxt SCRRAM+18, txt_beg
        +ptxt SCRRAM+30, txt_pro
        jsr copy_pal
        jmp draw_opts

!zone
draw_opts:                      ; selection brackets + colours
        lda #$20
        sta SCRRAM+17
        sta SCRRAM+26
        sta SCRRAM+29
        sta SCRRAM+33
        lda level
        bne .p
        lda #27                 ; '['
        sta SCRRAM+17
        lda #29                 ; ']'
        sta SCRRAM+26
        rts
.p:     lda #27
        sta SCRRAM+29
        lda #29
        sta SCRRAM+33
        rts

!zone
opt_colors:                     ; applied after the rainbow
        ldx #9
.a:     lda #6
        ldy level
        bne .a1
        lda #7
.a1:    sta $d811,x
        dex
        bpl .a
        ldx #4
.b:     lda #6
        ldy level
        beq .b1
        lda #7
.b1:    sta $d81d,x
        dex
        bpl .b
        rts

!zone
gameover_init:
        lda #2
        sta gstate
        lda #70
        sta gwait
        lda #0
        sta pinv
        sta pstate
        jsr clear_hud
        +ptxt SCRRAM+15, txt_over
        +ptxt SCRRAM+40+11, txt_press2
        lda #SFX_KILL
        jmp sfx_play

!zone
clear_hud:
        lda #$20
        ldx #79
.l:     sta SCRRAM,x
        dex
        bpl .l
        lda #1
        ldx #79
.c:     sta $d800,x
        dex
        bpl .c
        rts

!zone
put_text:
        ldy #0
.l:     lda (pp),y
        beq .d
        sta (dp),y
        iny
        bne .l
.d:     rts

!zone
rainbow:                        ; cycle colour RAM of the two HUD rows
        lda gframe
        lsr
        sta zt1
        ldx #79
.l:     txa
        clc
        adc zt1
        and #7
        tay
        lda coltab,y
        sta $d800,x
        dex
        bpl .l
        rts

!zone
title_update:
        inc gsl
        bne .a
        inc gsh
.a:     jsr rainbow
        jsr opt_colors
        lda tdelay
        beq .go
        dec tdelay
        rts
.go:    lda joy                 ; new direction press toggles the level
        and #$0f
        sta zt1
        lda joyp
        and #$0f
        eor #$ff
        and zt1
        beq .nt
        lda level
        eor #1
        sta level
        jsr draw_opts
        jsr copy_pal
        lda #SFX_JUMP
        jsr sfx_play
.nt:    lda joy
        and #$10
        beq .r
        jmp start_game
.r:     rts

!zone
gameover_update:
        inc gsl
        bne .a
        inc gsh
.a:     jsr rainbow
        lda gwait
        beq .w
        dec gwait
        rts
.w:     jsr fire_edge
        bcc .r
        jmp title_init
.r:     rts

!zone
copy_pal:                       ; scenery palette for the chosen level
        lda #<pal_b
        ldx #>pal_b
        ldy level
        beq .c
        lda #<pal_p
        ldx #>pal_p
.c:     sta pp
        stx pp+1
        ldy #100
.l:     dey
        lda (pp),y
        sta sp_c21,y
        cpy #0
        bne .l
        rts

!zone
start_game:
        lda #120
        sta pxl
        lda #0
        sta pxh
        sta pvy
        sta pstate
        sta ptimer
        sta pinv
        sta pblock
        sta pface
        sta sc0
        sta sc1
        sta sc2
        sta sc3
        sta sc4
        sta sact
        sta pkt
        sta pstart
        sta shaket
        sta bord
        sta armor
        sta svtl
        sta svth
        sta svn
        sta msgt
        lda #GROUNDY
        sta py
        ldx level
        lda php0,x
        sta phealth
        lda #5
        sta pstars
        lda #ES_OFF
        sta es
        sta es+1
        lda #50
        sta et
        lda #140
        sta et+1
        jsr copy_pal
        jsr clear_hud
        +ptxt SCRRAM+1, txt_score
        +ptxt SCRRAM+40+1, txt_health
        lda level
        bne .lp
        +ptxt SCRRAM+30, txt_beg
        jmp .lx
.lp:    +ptxt SCRRAM+30, txt_pro
.lx:    lda #TILE_STAR
        sta SCRRAM+24
        lda #24                 ; 'x'
        sta SCRRAM+25
        lda #7
        ldx #4
.y:     sta $d807,x
        dex
        bpl .y
        lda #3
        sta $d818
        lda #2
        ldx #7
.h:     sta $d830,x             ; hearts red
        dex
        bpl .h
        lda #3
        ldx #3
.ar:    sta $d839,x             ; armour = cyan hearts
        dex
        bpl .ar
        lda #7
        ldx #14
.m:     sta $d83e,x             ; message area yellow
        dex
        bpl .m
        lda #1
        sta gstate
        rts

; ============================================================
;  PLAY STATE
; ============================================================
!zone
play_update:
        lda #0
        sta bord
        lda #0
        sta walkf
        jsr pl_update
        ldx #0
        jsr en_one
        ldx #1
        jsr en_one
        jsr shur_update
        ; --- misc ---
        lda pkt
        beq .nk
        dec pkt
.nk:    ldx level
        inc pstart
        lda pstart
        cmp starreg,x
        bcc .ns
        lda #0
        sta pstart
        lda pstars
        cmp #9
        bcs .ns
        inc pstars
.ns:    lda shaket
        beq .no
        dec shaket
        and #1
        asl
        clc
        adc #2
        sta shakev
        jmp .dh
.no:    lda #3
        sta shakev
.dh:    inc svtl                ; survival time -> armour + bonus points
        bne .sv
        inc svth
.sv:    lda svth
        cmp #$03
        bcc .nm
        lda svtl
        cmp #$e8                ; 1000 frames = 20 s
        bcc .nm
        lda #0
        sta svtl
        sta svth
        jsr award
.nm:    lda msgt
        beq .dd
        dec msgt
        bne .dd
        lda #$20
        ldx #14
.cm:    sta SCRRAM+40+22,x
        dex
        bpl .cm
.dd:    jmp draw_hud

!zone
award:
        inc svn
        lda svn
        cmp #8
        bcc .a
        lda #8
        sta svn
.a:     lda armor
        cmp #4
        bcs .b
        inc armor
.b:     lda svn                 ; bonus = 3 + n hundreds
        clc
        adc #3
        tax
.l:     jsr addscore
        dex
        bne .l
        +ptxt SCRRAM+40+22, txt_bonus
        lda #140
        sta msgt
        lda #SFX_THROW
        jmp sfx_play

!zone
draw_hud:
        lda sc4
        ora #$30
        sta SCRRAM+7
        lda sc3
        ora #$30
        sta SCRRAM+8
        lda sc2
        ora #$30
        sta SCRRAM+9
        lda sc1
        ora #$30
        sta SCRRAM+10
        lda sc0
        ora #$30
        sta SCRRAM+11
        lda #2                  ; 'b' = blend indicator (yellow = on)
        sta SCRRAM+38
        lda #6
        ldx blendv
        beq .bi
        lda #7
.bi:    sta $d826
        lda pstars
        ora #$30
        sta SCRRAM+26
        ldx #0
.h:     cpx phealth
        bcc .f
        lda #TILE_HEARTE
        bne .p
.f:     lda #TILE_HEART
.p:     sta SCRRAM+40+8,x
        inx
        cpx #8
        bne .h
        ldx #0
.a:     cpx armor
        bcc .af
        lda #$20
        bne .ap
.af:    lda #TILE_HEART
.ap:    sta SCRRAM+40+17,x
        inx
        cpx #4
        bne .a
        rts

!zone
addkill:                        ; pro level pays double
        jsr addscore
        lda level
        beq .r
        jmp addscore
.r:     rts

!zone
addscore:                       ; +100
        inc sc2
        lda sc2
        cmp #10
        bcc .r
        lda #0
        sta sc2
        inc sc3
        lda sc3
        cmp #10
        bcc .r
        lda #0
        sta sc3
        inc sc4
        lda sc4
        cmp #10
        bcc .r
        lda #9
        sta sc4
.r:     rts

; ============================================================
;  PLAYER
; ============================================================
!zone
pl_update:
        lda pinv
        beq .a
        dec pinv
.a:     jsr pl_vert
        lda pstate
        bne .busy
        jmp pl_norm
.busy:  dec ptimer
        bne .go
        lda #PS_NORM
        sta pstate
        rts
.go:    lda pstate
        cmp #PS_PUNCH
        beq .pu
        cmp #PS_KICK
        beq .ki
        cmp #PS_THROW
        beq .th
        jmp pl_hurtmove
.pu:    lda ptimer
        cmp #6
        bne .r
        lda #40
        sta hreach
        lda #1
        sta hdmg
        jmp player_hit
.ki:    lda py                  ; flying kick may steer
        cmp #GROUNDY
        bcs .kh
        lda joy
        and #$08
        beq .kl
        jsr move_right
.kl:    lda joy
        and #$04
        beq .kh
        jsr move_left
.kh:    lda ptimer
        cmp #9
        bne .r
        lda #56
        sta hreach
        lda #2
        sta hdmg
        jmp player_hit
.th:    lda ptimer
        cmp #7
        bne .r
        jmp spawn_shuriken
.r:     rts

!zone
pl_vert:
        lda py
        clc
        adc pvy
        cmp #GROUNDY
        bcc .air
        lda #GROUNDY
        sta py
        lda #0
        sta pvy
        rts
.air:   sta py
        lda pvy
        cmp #8
        beq .r
        inc pvy
.r:     rts

!zone
pl_norm:
        jsr fire_edge
        bcc .nofire
        lda py
        cmp #GROUNDY
        bne .kick
        lda joy
        and #$02
        bne .throw
        lda joy
        and #$01
        bne .kick
        lda #PS_PUNCH
        sta pstate
        lda #10
        sta ptimer
        lda #SFX_PUNCH
        jmp sfx_play
.kick:  lda #PS_KICK
        sta pstate
        lda #14
        sta ptimer
        lda #SFX_KICK
        jmp sfx_play
.throw: lda pstars
        beq .nofire
        lda sact
        bne .nofire
        lda #PS_THROW
        sta pstate
        lda #12
        sta ptimer
        rts
.nofire:
        lda #0
        sta pblock
        lda py
        cmp #GROUNDY
        bne .move
        lda joy
        and #$02
        beq .move
        lda #1
        sta pblock
        lda joy                 ; turn while guarding
        and #$08
        beq .g1
        lda #0
        sta pface
.g1:    lda joy
        and #$04
        beq .g2
        lda #1
        sta pface
.g2:    rts
.move:  lda joy
        and #$08
        beq .nr
        lda #0
        sta pface
        jsr move_right
.nr:    lda joy
        and #$04
        beq .nl
        lda #1
        sta pface
        jsr move_left
.nl:    lda joy
        and #$01
        beq .nj
        lda py
        cmp #GROUNDY
        bne .nj
        lda #$f7
        sta pvy
        lda #SFX_JUMP
        jmp sfx_play
.nj:    rts

!zone
move_right:
        lda #1
        sta walkf
        lda pxh
        bne .sc
        lda pxl
        cmp #SCRL_R
        bcs .sc
        clc
        adc #2
        sta pxl
        rts
.sc:    lda gsl
        clc
        adc #2
        sta gsl
        bcc .d
        inc gsh
.d:     jmp world_left2

!zone
move_left:
        lda #1
        sta walkf
        lda pxh
        bne .px
        lda pxl
        cmp #SCRL_L+1
        bcc .sc
.px:    sec
        lda pxl
        sbc #2
        sta pxl
        bcs .r
        dec pxh
.r:     rts
.sc:    lda gsl
        sec
        sbc #2
        sta gsl
        bcs .d
        dec gsh
.d:     jmp world_right2

!zone
pl_hurtmove:
        lda ptimer
        cmp #8
        bcc .r
        lda pkbd
        bne .right
        lda pxh
        bne .l1
        lda pxl
        cmp #PXMIN+3
        bcc .r
.l1:    sec
        lda pxl
        sbc #3
        sta pxl
        bcs .r
        dec pxh
        rts
.right: lda pxh
        beq .r1
        lda pxl
        cmp #PXMAX-256-3
        bcs .r
.r1:    clc
        lda pxl
        adc #3
        sta pxl
        bcc .r
        inc pxh
.r:     rts

; ---- world shift when the screen scrolls ----
!zone
world_left2:                    ; objects X -= 2
        ldx #1
.e:     lda es,x
        beq .n
        sec
        lda exl,x
        sbc #2
        sta exl,x
        lda exh,x
        sbc #0
        sta exh,x
        bpl .n
        jsr despawn
.n:     dex
        bpl .e
        lda sact
        beq .s
        sec
        lda sxl
        sbc #2
        sta sxl
        lda sxh
        sbc #0
        sta sxh
        bpl .s
        lda #0
        sta sact
.s:     rts

!zone
world_right2:                   ; objects X += 2
        ldx #1
.e:     lda es,x
        beq .n
        clc
        lda exl,x
        adc #2
        sta exl,x
        lda exh,x
        adc #0
        sta exh,x
        cmp #2
        bcc .n
        jsr despawn
.n:     dex
        bpl .e
        lda sact
        beq .s
        clc
        lda sxl
        adc #2
        sta sxl
        lda sxh
        adc #0
        sta sxh
        cmp #2
        bcc .s
        lda #0
        sta sact
.s:     rts

despawn:                        ; X = enemy (keeps X)
        lda #ES_OFF
        sta es,x
        lda #40
        sta et,x
        rts

; ---- |enemy - player| ----
!zone
dx_enemy:
        ldx ecur
        lda exl,x
        sta zt1
        lda exh,x
        sta zt2
        lda pxl
        sta zt3
        lda pxh
        sta zt4
diffabs:                        ; |zt2:zt1 - zt4:zt3| -> dxa, side -> dxs (0 = a>=b)
        lda zt1
        sec
        sbc zt3
        sta zt5
        lda zt2
        sbc zt4
        sta zt6
        bmi .neg
        lda #0
        sta dxs
        lda zt6
        bne .big
        lda zt5
        sta dxa
        rts
.neg:   lda #1
        sta dxs
        lda #0
        sec
        sbc zt5
        sta zt5
        lda #0
        sbc zt6
        sta zt6
        bne .big
        lda zt5
        sta dxa
        rts
.big:   lda #255
        sta dxa
        rts

!zone
player_hit:                     ; hreach, hdmg : hit enemies in front of the player
        ldx #1
.l:     stx ecur
        lda es,x
        beq .n
        cmp #ES_HURT
        bcs .n
        jsr dx_enemy
        lda dxa
        cmp #10
        bcc .front
        lda dxs
        cmp pface
        bne .n
.front: lda dxa
        cmp hreach
        bcs .n
        lda dxs
        sta hkd
        ldx ecur
        jsr enemy_damage
.n:     ldx ecur
        dex
        bpl .l
        rts

!zone
enemy_damage:                   ; X = enemy, hdmg, hkd
        lda ehp,x
        sec
        sbc hdmg
        beq .dead
        bcc .dead
        sta ehp,x
        lda #ES_HURT
        sta es,x
        lda #12
        sta et,x
        lda hkd
        sta ekd,x
        lda #SFX_HIT
        jsr sfx_play
        jmp .fx
.dead:  lda #0
        sta ehp,x
        lda #ES_DEAD
        sta es,x
        lda #36
        sta et,x
        lda hkd
        sta ekd,x
        jsr addkill
        lda #SFX_KILL
        jsr sfx_play
.fx:    lda exl,x
        clc
        adc #12
        sta pkxl
        lda exh,x
        adc #0
        sta pkxh
        lda #GROUNDY+4
        sta pky
        lda #8
        sta pkt
        lda #1
        sta bord
        lda #4
        sta shaket
        rts

; ============================================================
;  SHURIKEN
; ============================================================
!zone
spawn_shuriken:
        lda pstars
        beq .r
        lda sact
        bne .r
        dec pstars
        lda #1
        sta sact
        lda pface
        sta sdir
        lda pxl
        sta sxl
        lda pxh
        sta sxh
        lda pface
        bne .left
        lda sxl
        clc
        adc #30
        sta sxl
        bcc .y
        inc sxh
        jmp .y
.left:  lda sxl
        sec
        sbc #6
        sta sxl
        bcs .y
        dec sxh
.y:     lda py
        clc
        adc #14
        sta sy
        lda #SFX_THROW
        jmp sfx_play
.r:     rts

!zone
shur_update:
        lda sact
        bne .go
        rts
.go:    lda sdir
        bne .left
        lda sxl
        clc
        adc #7
        sta sxl
        bcc .chk
        inc sxh
        lda sxh
        cmp #2
        bcc .chk
        lda #0
        sta sact
        rts
.left:  lda sxl
        sec
        sbc #7
        sta sxl
        bcs .chk
        lda sxh
        beq .kill
        dec sxh
.chk:   ldx #1
.e:     stx ecur
        lda es,x
        beq .n
        cmp #ES_HURT
        bcs .n
        lda exl,x
        sta zt1
        lda exh,x
        sta zt2
        lda sxl                 ; shuriken centre vs enemy centre
        sec
        sbc #12
        sta zt3
        lda sxh
        sbc #0
        sta zt4
        jsr diffabs
        lda dxa
        cmp #24
        bcs .n
        lda #1
        sta hdmg
        lda sdir
        sta hkd
        ldx ecur
        jsr enemy_damage
        lda #0
        sta sact
        rts
.n:     ldx ecur
        dex
        bpl .e
        rts
.kill:  lda #0
        sta sact
        rts

; ============================================================
;  ENEMIES
; ============================================================
!zone
en_one:
        stx ecur
        lda es,x
        bne .a
        jmp en_off
.a:     cmp #ES_WALK
        bne .b
        jmp en_walk
.b:     cmp #ES_WIND
        bne .c
        jmp en_wind
.c:     cmp #ES_STRIKE
        bne .d
        jmp en_strike
.d:     cmp #ES_RECOVER
        bne .e
        jmp en_rec
.e:     cmp #ES_HURT
        bne .f
        jmp en_hurt
.f:     jmp en_dead

!zone
en_off:
        lda et,x
        beq .sp
        dec et,x
        rts
.sp:    lda #<360
        sta exl,x
        lda #>360
        sta exh,x
        ldy level
        lda hp_tab,y
        sta ehp,x
        lda #1
        sta efc,x
        lda #ES_WALK
        sta es,x
        rts

!zone
en_walk:
        jsr dx_enemy
        ldx ecur
        lda dxs
        eor #1
        sta efc,x
        lda dxa
        cmp #34
        bcc .near
        ldy level
        bne .pro
        lda gframe              ; beginner: 3/4 speed
        and #3
        beq .r
        jmp em1
.pro:   jsr em1                 ; pro: 1.5 px / frame
        lda gframe
        and #1
        beq .r
        ldx ecur
        jmp em1
.r:     rts
.near:  jsr rnd
        ldy level
        and hes_mask,y
        bne .w
        ldx ecur
        lda #ES_WIND
        sta es,x
        lda wind_tab,y
        sta et,x
.w:     rts

!zone
em1:                            ; X: one pixel towards the player (dxs)
        lda dxs
        bne .mr
        lda exl,x
        sec
        sbc #1
        sta exl,x
        lda exh,x
        sbc #0
        sta exh,x
        rts
.mr:    lda exl,x
        clc
        adc #1
        sta exl,x
        bcc .r
        inc exh,x
.r:     rts

!zone
en_wind:
        dec et,x
        bne .r
        lda #ES_STRIKE
        sta es,x
        lda #8
        sta et,x
.r:     rts

!zone
en_strike:
        dec et,x
        lda et,x
        cmp #6
        bne .n
        jsr en_hitplayer
        ldx ecur
.n:     lda et,x
        bne .r
        lda #ES_RECOVER
        sta es,x
        ldy level
        lda rec_tab,y
        sta et,x
.r:     rts

!zone
en_rec:
        dec et,x
        bne .r
        lda #ES_WALK
        sta es,x
.r:     rts

!zone
en_hurt:
        dec et,x
        lda et,x
        cmp #7
        bcc .n
        jsr kb3
        ldx ecur
.n:     lda et,x
        bne .r
        lda #ES_WALK
        sta es,x
.r:     rts

!zone
en_dead:
        dec et,x
        lda et,x
        cmp #26
        bcc .n
        jsr kb3
        ldx ecur
.n:     lda et,x
        bne .r
        lda #ES_OFF
        sta es,x
        jsr rnd
        and #$3f
        ldy level
        clc
        adc respb,y
        ldx ecur
        sta et,x
.r:     rts

!zone
kb3:                            ; X: move 3 px along ekd (0 = +X)
        lda ekd,x
        bne .m
        lda exl,x
        clc
        adc #3
        sta exl,x
        bcc .r
        inc exh,x
        rts
.m:     lda exl,x
        sec
        sbc #3
        sta exl,x
        bcs .r
        dec exh,x
.r:     rts

!zone
en_hitplayer:
        jsr dx_enemy
        lda dxa
        cmp #46
        bcs .miss
        lda pinv
        bne .miss
        lda py
        cmp #GROUNDY-14
        bcc .miss               ; jumped over it
        lda pblock
        beq .hit
        lda pface
        cmp dxs
        bne .hit
        jmp player_parry
.hit:   jmp player_damage
.miss:  rts

!zone
player_parry:
        ldx ecur
        lda #ES_HURT
        sta es,x
        lda #9
        sta et,x
        lda dxs
        sta ekd,x
        lda pxl
        clc
        adc #20
        sta pkxl
        lda pxh
        adc #0
        sta pkxh
        lda #GROUNDY+6
        sta pky
        lda #8
        sta pkt
        lda #SFX_BLOCK
        jmp sfx_play

!zone
player_damage:
        lda armor
        beq .hp
        dec armor
        jmp .after
.hp:    dec phealth
.after:
        lda #45
        sta pinv
        lda #PS_HURT
        sta pstate
        lda #14
        sta ptimer
        lda dxs
        sta pkbd
        lda pxl
        clc
        adc #14
        sta pkxl
        lda pxh
        adc #0
        sta pkxh
        lda #GROUNDY
        sta pky
        lda #8
        sta pkt
        lda #1
        sta bord
        lda #8
        sta shaket
        lda #SFX_HURT
        jsr sfx_play
        lda phealth
        bne .ok
        jsr draw_hud
        jmp gameover_init
.ok:    rts
        rts


; ============================================================
;  SPRITE SHADOWS
; ============================================================
!zone
build_sprites:
        lda #0
        sta sh_msb
        sta sh_en
        ; ---------- player: choose animation frame ----------
        lda gstate
        cmp #2
        bne .ps
        lda #PF_HURT
        jmp .pf
.ps:    lda pstate
        cmp #PS_HURT
        bne .p1
        lda #PF_HURT
        jmp .pf
.p1:    cmp #PS_PUNCH
        bne .p2
        lda ptimer
        cmp #7
        bcs .pa
        lda #PF_PUNCHB
        jmp .pf
.pa:    lda #PF_PUNCHA
        jmp .pf
.p2:    cmp #PS_KICK
        bne .p3
        lda ptimer
        cmp #10
        bcs .ka
        lda #PF_KICKB
        jmp .pf
.ka:    lda #PF_KICKA
        jmp .pf
.p3:    cmp #PS_THROW
        bne .p4
        lda ptimer
        cmp #8
        bcs .ta
        lda #PF_THROWB
        jmp .pf
.ta:    lda #PF_THROWA
        jmp .pf
.p4:    lda pblock
        beq .p5
        lda #PF_BLOCK
        jmp .pf
.p5:    lda py
        cmp #GROUNDY
        bcs .p6
        lda pvy
        bmi .up
        lda #PF_JUMPDN
        jmp .pf
.up:    lda #PF_JUMPUP
        jmp .pf
.p6:    lda walkf
        beq .pi
        lda gframe
        lsr
        lsr
        and #3
        clc
        adc #PF_WALK1
        jmp .pf
.pi:    lda gframe
        lsr
        lsr
        lsr
        lsr
        and #1
.pf:    sta zt1                 ; frame number
        ldx pface
        beq .pr
        clc
        adc #32
.pr:    clc
        adc #SPR_P
        sta sh_p+2              ; body layer
        clc
        adc #16
        sta sh_p+1              ; detail layer
        lda zt1
        ldx pface
        beq .aq
        clc
        adc #AA_PL
        jmp .ar
.aq:    clc
        adc #AA_PR
.ar:    sta sh_p+0              ; fine edge pixels (front)
        lda pxl
        sta sh_xl
        sta sh_xl+1
        sta sh_xl+2
        lda py
        sta sh_y
        sta sh_y+1
        sta sh_y+2
        lda pxh
        and #1
        beq .pm
        lda #7
        sta sh_msb
.pm:    lda pinv
        beq .pe
        and #4
        bne .pn
.pe:    lda #7
        sta sh_en
.pn:
        ; ---------- enemies (2 sprites each) ----------
        ldx #0
.e:     stx zt2
        lda es,x
        bne .eact
        jmp .eoff
.eact:  cmp #ES_WALK
        bne .e1
        lda gframe
        lsr
        lsr
        sta zt3
        txa
        asl
        clc
        adc zt3
        and #3
        jmp .ef
.e1:    cmp #ES_WIND
        bne .e2
        lda #4
        jmp .ef
.e2:    cmp #ES_STRIKE
        bne .e3
        lda #5
        jmp .ef
.e3:    cmp #ES_RECOVER
        bne .e4
        lda #0
        jmp .ef
.e4:    lda #6
.ef:    sta zt3                 ; frame 0-6
        ldy efc,x
        beq .er
        clc
        adc #7
.er:    clc
        adc #SPR_E
        sta zt4                 ; body pointer
        lda zt3
        ldy efc,x
        beq .ea
        clc
        adc #AA_EL
        jmp .eb
.ea:    clc
        adc #AA_ER
.eb:    sta zt5                 ; fine-edge pointer
        txa
        asl
        tay
        lda zt4
        sta sh_p+4,y
        lda zt5
        sta sh_p+3,y
        lda exl,x
        sta sh_xl+3,y
        sta sh_xl+4,y
        lda #GROUNDY
        sta sh_y+3,y
        sta sh_y+4,y
        lda exh,x
        cmp #2
        bcs .eoff
        and #1
        beq .nm
        lda epair,x
        ora sh_msb
        sta sh_msb
.nm:    lda es,x
        cmp #ES_DEAD
        bne .on
        lda et,x
        and #2
        bne .eoff
.on:    lda epair,x
        ora sh_en
        sta sh_en
.eoff:  ldx zt2
        inx
        cpx #2
        beq .ed
        jmp .e
.ed:    rts

; ============================================================
;  DATA
; ============================================================
epair:  !byte $18,$60

crow:   !byte 1,1, 9,9,9, 10,10,10, 14,14,14,14,14, 8,8,8,8, 13,13,13,13,13, 13,13,13

; band index -> first / last screen row
brs:    !byte 0, 2, 5, 8, 13, 17, 22
bre:    !byte 0, 4, 7, 12, 16, 21, 24

; raster events (split IRQs fire 3 lines before the write line): line, type (0 top,1 music,2 split,3 open border), arg
ev_lo:  !byte 2, 14, 63, 79, 87, 92, 95, 111, 118, 127, 143, 151, 167, 170, 183, 199, 216, 223, 231, 248, 252, 0, 10, 20
ev_hi:  !byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, $80,$80,$80
ev_type:!byte 0, 1, 2, 2, 2, 1, 2, 2, 4, 2, 2, 2, 2, 1, 2, 2, 5, 2, 2, 3, 1, 2, 2, 2
ev_arg: !byte 0, 0, 0, 1, 2, 1, 3, 4, 0, 5, 6, 7, 8, 2, 9, 10, 0, 11, 12, 0, 3, 13, 14, 15
evnext: !byte 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,0

; palette splits: write line (low byte), scroll band
sp_lw:  !byte 66,82,90,98,114,130,146,154,170,186,202,226,234,2,12,22
sp_band:!byte 1,1,2,2,3,3,3,4,4,5,5,6,6,6,6,6
; $d021 / $d022 / $d023 : 16 values for even frames then 16 for odd frames.
; The big sky/ground bars ($d021) never blend (they are the same in both halves).
; Small shapes ($d022/$d023) blend between two colours of the same luminance and a
; near hue when blending is on (key B): the flicker amplitude stays tiny at 50 Hz,
; and neighbouring bars run in opposite phase (see the .spl handler).
sp_c21: !byte 6,4,4,2,10,8,7,7,7,0,0,9,9,11,12,0,6,4,4,2,10,8,7,7,7,0,0,9,9,11,12,0
sp_c22: !byte 1,1,7,7,11,11,11,7,7,6,6,8,8,8,8,8,1,1,13,13,2,2,2,13,13,9,9,4,4,4,4,4
sp_c23: !byte 1,1,10,10,4,4,4,6,6,13,13,12,12,12,12,12,1,1,14,14,8,8,8,9,9,7,7,14,14,14,14,14
        !byte 7,13                      ; moon base colours (even/odd frame)
        !byte 12,12                      ; moon crater/shade layer
; the same 100 bytes for the two levels (copied into the tables above)
pal_b:  !byte 6,4,4,2,10,8,7,7,7,0,0,9,9,11,12,0,6,4,4,2,10,8,7,7,7,0,0,9,9,11,12,0
        !byte 1,1,7,7,11,11,11,7,7,6,6,8,8,8,8,8,1,1,13,13,2,2,2,13,13,9,9,4,4,4,4,4
        !byte 1,1,10,10,4,4,4,6,6,13,13,12,12,12,12,12,1,1,14,14,8,8,8,9,9,7,7,14,14,14,14,14
        !byte 7,13
        !byte 12,12
pal_p:  !byte 0,6,4,2,2,2,8,8,8,0,0,9,9,11,0,0,0,6,4,2,2,2,8,8,8,0,0,9,9,11,0,0
        !byte 1,1,2,2,6,6,6,7,7,6,6,9,9,9,9,9,1,1,11,11,9,9,9,13,13,9,9,6,6,6,6,6
        !byte 1,1,4,4,2,2,2,2,2,5,5,11,11,11,11,11,1,1,8,8,11,11,11,11,11,5,5,2,2,2,2,2
        !byte 2,11
        !byte 11,11

; sprite colour blends (even / odd frame): player body, samurai 1, samurai 2
; (equal luminance, nearby hue; only used while blending is on)
scol0:  !byte 14,12
scol1:  !byte 8,4
scol2:  !byte 13,7
scol3:  !byte 15,15

; difficulty tables: [beginner, pro]
hp_tab:   !byte 2,4
php0:     !byte 8,6
wind_tab: !byte 22,12
rec_tab:  !byte 34,20
hes_mask: !byte 15,3
respb:    !byte 70,35
starreg:  !byte 150,250

; sfx: ctrl+gate, start freq hi, step per slot, length in slots
sfxtab: !byte $81,$18,$ff,8     ; punch
        !byte $81,$14,$ff,12    ; kick
        !byte $21,$30,$03,10    ; throw
        !byte $41,$50,$fe,8     ; block (pulse)
        !byte $81,$0a,$00,20    ; hurt
        !byte $21,$38,$fe,24    ; kill
        !byte $11,$10,$02,8     ; jump
        !byte $81,$30,$fe,6     ; hit

coltab: !byte 2,2,7,7,1,1,7,7

txt_title: !scr "ninja shadow",0
txt_press: !scr "press fire to start",0
txt_press2:!scr "press fire to retry",0
txt_over:  !scr "game over",0
txt_score: !scr "score 00000",0
txt_health:!scr "health",0
txt_hint:  !scr "left/right: level  fire: start",0
txt_blend: !scr "b:blend",0
txt_beg:   !scr "beginner",0
txt_pro:   !scr "pro",0
txt_bonus: !scr "armor up! bonus",0

; ================= MUSIC PLAYER =================
!zone
frame_logic:
        jsr vol_fade
        inc frame
        lda frame
        cmp spd
        bcc .fl_notick
        lda #0
        sta frame
        jsr seq_step
.fl_notick:
        lda frame
        cmp hrfr
        bne .fl_nohr
        jsr hard_restart
.fl_nohr:
        ldx #2
.fl_v:  jsr voice_frame
        dex
        bpl .fl_v
        rts


!zone
seq_step:
        ldx #2
.ss_each: dec dur,x
        bne .ss_next
        jsr read_event
.ss_next: dex
        bpl .ss_each
        rts


!zone
read_event:
        lda seq_lo,x
        sta zptr
        lda seq_hi,x
        sta zptr+1
        ldy #0
.re_fetch: lda (zptr),y
        bmi .re_cmd
        iny
        clc
        adc trans
        sta note,x
        lda (zptr),y
        iny
        sta dur,x
        tya
        pha
        jsr note_on
        pla
        tay
        jmp .re_done
.re_cmd:  iny
        cmp #$80
        beq .re_rest
        cmp #$81
        beq .re_setins
        cmp #$82
        beq .re_setflt
        cmp #$83
        beq .re_kick
        cmp #$84
        beq .re_trans
        cmp #$85
        beq .re_spd
        cmp #$86
        beq .re_sect
        cmp #$87
        bne .re_nf
        jsr fade_cmd
        jmp .re_fetch
.re_nf:
        cmp #$fe
        beq .re_loop
        jmp .re_done
.re_rest: lda (zptr),y
        iny
        sta dur,x
        lda #$fe
        sta gmask,x
        jmp .re_done
.re_setins: lda (zptr),y
        iny
        asl
        asl
        asl
        sta insoff,x
        jmp .re_fetch
.re_setflt: lda (zptr),y
        iny
        jsr set_filter
        jmp .re_fetch
.re_kick: lda #12
        sta digi
        jmp .re_fetch
.re_trans: lda (zptr),y
        iny
        sta trans
        jmp .re_fetch
.re_spd: lda (zptr),y
        iny
        sta spd
        sec
        sbc #1
        sta hrfr
        jmp .re_fetch
.re_sect: lda (zptr),y
        iny
        sta secnew
        jmp .re_fetch
.re_loop: lda stream_lo,x
        sta zptr
        lda stream_hi,x
        sta zptr+1
        ldy #0
        jmp .re_fetch
.re_done: tya
        clc
        adc zptr
        sta seq_lo,x
        lda zptr+1
        adc #0
        sta seq_hi,x
        rts


!zone
note_on:
        clc
        lda insoff,x
        adc #<instab
        sta zp2
        lda #>instab
        adc #0
        sta zp2+1
        ldy #0
        lda (zp2),y
        sta t0
        iny
        lda (zp2),y
        sta t1
        iny
        lda (zp2),y
        sta wpos,x
        iny
        lda (zp2),y
        sta pwh,x
        iny
        lda (zp2),y
        sta pwsp,x
        iny
        lda (zp2),y
        sta cutt,x
        iny
        lda (zp2),y
        sta fmd,x
        iny
        lda (zp2),y
        sta t2
        lda #0
        sta pwl,x
        sta fmp,x
        sta age,x
        sta tbit,x
        sta vibp,x
        sta vibd,x
        lda t2
        and #$10
        beq .no_vib
        lda fmd,x           ; vibrato spec = delay<<4 | depth nibble
        and #$0f
        sta vibd,x
        lda fmd,x
        lsr
        lsr
        lsr
        lsr
        asl                 ; delay in frames = nibble * 2
        sta vibdel,x
        lda #0
        sta fmd,x           ; vibrato instruments do not use the FM wobble
.no_vib:
        lda #$ff
        sta gmask,x
        lda #31
        sta vu,x
        ldy voff,x
        lda t0
        sta $d405,y
        lda t1
        sta $d406,y
        lda t2
        and #1
        beq .no_test
        lda #8
        sta tbit,x
.no_test:
        lda t2
        and #2
        beq .no_digi
        lda #12
        sta digi
.no_digi:
        lda t2
        and #$20
        beq .no_fenv
        cpx #1
        bne .no_fenv
        lda #FENV_START
        sta fenv
.no_fenv:
        cpx #0
        bne .no_end
        lda t2
        and #8
        beq .no_sync
        lda #$80
        sta syncmode
        lda #0
        sta swpl
        lda #2
        sta swph
        jmp .no_end
.no_sync:
        lda #0
        sta syncmode
.no_end: rts


!zone
hard_restart:
        ldx #2
.hr_l:  lda dur,x
        cmp #1
        bne .hr_n
        lda #$fe
        sta gmask,x
        ldy voff,x
        lda #0
        sta $d405,y
        sta $d406,y
.hr_n:  dex
        bpl .hr_l
        rts


!zone
voice_frame:
        lda age,x
        cmp #$ff
        beq .vf_aged
        inc age,x
.vf_aged:
        lda cutt,x
        beq .vf_nocut
        cmp age,x
        bne .vf_nocut
        lda #$fe
        sta gmask,x
.vf_nocut:
        lda vu,x
        beq .vf_vz
        sec
        sbc #1
        sta vu,x
        lda gmask,x
        cmp #$ff
        beq .vf_vz
        lda vu,x
        sec
        sbc #2
        bcs .vf_st
        lda #0
.vf_st: sta vu,x
.vf_vz:
        ldy wpos,x
.vf_row: lda wavetab,y
        cmp #$ff
        bne .vf_norm
        lda wavetab+1,y
        tay
        jmp .vf_row
.vf_norm:
        sta ctrl,x
        lda wavetab+1,y
        sta tmp
        iny
        iny
        sty wpos,x
        lda tmp
        bmi .vf_abs
        and #$40
        bne .vf_sub
        lda tmp
        clc
        adc note,x
        jmp .vf_look
.vf_sub: lda tmp
        and #$3f
        sta tmp
        lda note,x
        sec
        sbc tmp
        jmp .vf_look
.vf_abs: and #$7f
.vf_look: tay
        lda ntlo,y
        sta bfl,x
        lda nthi,y
        sta bfh,x
        rts


!zone
fast_fx:
        ldx #0
.ff_l:  jsr fx_voice
        inx
        cpx #3
        bne .ff_l
        rts


!zone
fx_voice:
        lda #0
        sta tmp2
        sta tmp3
        lda fmd,x
        beq .fx_nofm
        jsr fm_calc
.fx_nofm:
        lda vibd,x
        beq .fx_novib
        jsr vib_calc
.fx_novib:
        clc
        lda bfl,x
        adc tmp2
        sta outl
        lda bfh,x
        adc tmp3
        sta outh
        lda pwsp,x
        beq .fx_nopwm
        jsr pwm_step
.fx_nopwm:
        lda syncmode
        bpl .fx_normal
        cpx #1
        beq .fx_normal
        cpx #2
        beq .fx_master
        jsr sync_sweep
        jmp .fx_normal
.fx_master:
        lda m0l
        sta $d40e
        lda m0h
        sta $d40f
        lda #$10
        sta $d412
        rts
.fx_normal:
        ldy voff,x
        lda outl
        sta $d400,y
        lda outh
        sta $d401,y
        lda pwl,x
        sta $d402,y
        lda pwh,x
        sta $d403,y
        lda ctrl,x
        and gmask,x
        ora tbit,x
        sta $d404,y
        rts


!zone
fm_calc:
        lda fmd,x
        lsr
        lsr
        lsr
        lsr
        clc
        adc fmp,x
        sta fmp,x
        and #$0f
        tay
        lda fmtab,y
        sta tmp2
        bmi .fm_neg
        lda #0
        beq .fm_ext
.fm_neg: lda #$ff
.fm_ext: sta tmp3
        lda fmd,x
        and #$0f
        tay
        beq .fm_ret
.fm_sh: asl tmp2
        rol tmp3
        dey
        bne .fm_sh
.fm_ret: rts


!zone
vib_calc:
        lda age,x
        sec
        sbc vibdel,x
        bcc .vb_ret         ; delay not over yet
        inc vibp,x
        lda vibp,x
        and #$1f
        tay
        lda vibtab,y
        sta tmp             ; signed -8..8
        bpl .vb_abs
        eor #$ff
        clc
        adc #1              ; |t|
.vb_abs: tay
        beq .vb_ret         ; zero crossing, nothing to add
        lda #0
        sta t0
        sta t1
.vb_mul: lda t0             ; t1:t0 = hi byte of frequency * |t|
        clc
        adc bfh,x
        sta t0
        bcc .vb_nc
        inc t1
.vb_nc: dey
        bne .vb_mul
        ldy vibd,x          ; depth nibble n -> shift right by n-1
        dey
        beq .vb_sd
.vb_sh: lsr t1
        ror t0
        dey
        bne .vb_sh
.vb_sd: lda tmp
        bmi .vb_neg
        clc
        lda tmp2
        adc t0
        sta tmp2
        lda tmp3
        adc t1
        sta tmp3
.vb_ret: rts
.vb_neg: sec
        lda tmp2
        sbc t0
        sta tmp2
        lda tmp3
        sbc t1
        sta tmp3
        rts


!zone
fade_cmd:                   ; stream command $87: start, target, frames per step
        lda (zptr),y
        iny
        sta mvol
        lda (zptr),y
        iny
        sta mtgt
        lda (zptr),y
        iny
        sta mrate
        lda #0
        sta mcnt
        rts


!zone
vol_fade:                   ; 50 Hz: step master volume towards target
        lda mvol
        cmp mtgt
        beq .vf_done
        inc mcnt
        lda mcnt
        cmp mrate
        bcc .vf_done
        lda #0
        sta mcnt
        lda mvol
        cmp mtgt
        bcc .vf_up
        dec mvol
        rts
.vf_up: inc mvol
.vf_done: rts


!zone
pwm_step:
        lda pwsp,x
        bpl .pw_pos
        lda #$ff
        bne .pw_ext
.pw_pos: lda #0
.pw_ext: sta tmp
        clc
        lda pwl,x
        adc pwsp,x
        sta pwl,x
        lda pwh,x
        adc tmp
        sta pwh,x
        bmi .pw_wlow
        cmp #$0d
        bcs .pw_whigh
        cmp #$03
        bcs .pw_ok
.pw_wlow: lda #$03
        sta pwh,x
        bne .pw_flip
.pw_whigh: lda #$0c
        sta pwh,x
.pw_flip: lda pwsp,x
        eor #$ff
        clc
        adc #1
        sta pwsp,x
.pw_ok: rts


!zone
sync_sweep:
        lda outl
        sta m0l
        lda outh
        sta m0h
        lda swph
        cmp #$30
        bcs .ss_nosw
        clc
        lda swpl
        adc #$80
        sta swpl
        bcc .ss_nosw
        inc swph
.ss_nosw:
        clc
        lda outl
        adc swpl
        sta outl
        lda outh
        adc swph
        sta outh
        rts


!zone
filter_step:
        lda fdir
        beq .fs_nosweep
        bmi .fs_down
        clc
        adc fcut
        bcs .fs_top
        cmp fmax
        bcc .fs_store
.fs_top: lda fmax
        jsr flipdir
        jmp .fs_store
.fs_down:
        clc
        adc fcut
        bcc .fs_bot
        cmp fmin
        bcs .fs_store
.fs_bot: lda fmin
        jsr flipdir
.fs_store: sta fcut
.fs_nosweep:
        lda fcut
        clc
        adc fenv
        bcc .fs_nc
        lda #$ff
.fs_nc: sta $d416
        lda fenv            ; envelope decay: fenv -= fenv/16 (min 1)
        beq .fs_fe
        lsr
        lsr
        lsr
        lsr
        bne .fs_fd
        lda #1
.fs_fd: sta tmp
        lda fenv
        sec
        sbc tmp
        sta fenv
.fs_fe: lda #0
        sta $d415
        lda froute
        sta $d417
        ldx digi
        beq .fs_novol
        lda digitab-1,x
        dec digi
        cmp mvol
        bcc .fs_vol
        lda mvol
        jmp .fs_vol
.fs_novol: lda mvol
.fs_vol: ora fmode
        ora syncmode
        sta $d418
        rts


!zone
flipdir:
        pha
        lda fdir
        eor #$ff
        clc
        adc #1
        sta fdir
        pla
        rts


!zone
set_filter:
        stx xsave
        sty ysave
        sta tmp
        asl
        clc
        adc tmp
        asl
        tax
        lda fpresets,x
        sta froute
        lda fpresets+1,x
        sta fmode
        lda fpresets+2,x
        sta fcut
        lda fpresets+3,x
        sta fdir
        lda fpresets+4,x
        sta fmin
        lda fpresets+5,x
        sta fmax
        ldx xsave
        ldy ysave
        rts


!zone
sid_reset:
        ldx #$18
        lda #0
.sr_l:  sta $d400,x
        dex
        bpl .sr_l
        rts


!zone
song_init:
        ldx #2
.si_l:  lda stream_lo,x
        sta seq_lo,x
        lda stream_hi,x
        sta seq_hi,x
        lda #1
        sta dur,x
        lda #$fe
        sta gmask,x
        dex
        bpl .si_l
        lda #SPEED
        sta spd
        lda #SPEED-1
        sta hrfr
        sta frame
        lda #0
        sta trans
        sta secnew
        lda #0
        jsr set_filter
        rts


voff:   !byte 0, 7, 14

fmtab:  !byte 0,2,4,6,8,6,4,2,0,-2,-4,-6,-8,-6,-4,-2

; volume-register kick: shallow duck, never below 8 (stored reversed)
; plays 10,8,9,11,13,14,15,15,15,15,15,15 at 200 Hz
digitab: !byte 15,15,15,15,15,15,14,13,11,9,8,10

; vibrato sine, 32 steps, +/-8 (read at 200 Hz = 6.25 Hz)
vibtab: !byte 0,2,3,4,6,7,7,8,8,8,7,7,6,4,3,2
        !byte 0,-2,-3,-4,-6,-7,-7,-8,-8,-8,-7,-7,-6,-4,-3,-2

; filter presets: route|res, mode, start cutoff, step, min, max
fpresets:
        !byte $00,$00,$80,$00,$00,$ff   ; 0 off
        !byte $32,$10,$34,$00,$00,$ff   ; 1 LP on bass only, dark base, env does the pluck
        !byte $41,$10,$70,$02,$70,$f0   ; 2 LP on lead, bright floor (unused)
        !byte $24,$40,$10,$01,$08,$40   ; 3 HP on percussion (unused)
        !byte $32,$10,$4c,$00,$00,$ff   ; 4 LP on bass only, brighter base
        !byte $42,$10,$38,$01,$38,$a0   ; 5 resonant LP on bass, slow opening (build)
        !byte $37,$10,$d0,$00,$00,$ff   ; 6 static LP, all voices (lead stack)

; PAL note table, index 0 = C-0, 12 per octave (985248 Hz clock)
ntlo:
        !byte $16,$27,$39,$4b,$5f,$74,$8a,$a1,$ba,$d4,$f0,$0e
        !byte $2d,$4e,$71,$96,$be,$e7,$14,$42,$74,$a9,$e0,$1b
        !byte $5a,$9c,$e2,$2d,$7b,$cf,$27,$85,$e8,$51,$c1,$37
        !byte $b4,$38,$c4,$59,$f7,$9d,$4e,$0a,$d0,$a2,$81,$6d
        !byte $67,$70,$89,$b2,$ed,$3b,$9c,$13,$a0,$45,$02,$da
        !byte $ce,$e0,$11,$64,$da,$76,$39,$26,$40,$89,$04,$b4
        !byte $9c,$c0,$23,$c8,$b4,$eb,$72,$4c,$80,$12,$08,$68
        !byte $39,$80,$45,$90,$68,$d6,$e3,$99,$00,$24,$10,$ff
nthi:
        !byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02
        !byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04
        !byte $04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08
        !byte $08,$09,$09,$0a,$0a,$0b,$0c,$0d,$0d,$0e,$0f,$10
        !byte $11,$12,$13,$14,$15,$17,$18,$1a,$1b,$1d,$1f,$20
        !byte $22,$24,$27,$29,$2b,$2e,$31,$34,$37,$3a,$3e,$41
        !byte $45,$49,$4e,$52,$57,$5c,$62,$68,$6e,$75,$7c,$83
        !byte $8b,$93,$9c,$a5,$af,$b9,$c4,$d0,$dd,$ea,$f8,$ff

; ============ INSTRUMENTS ============
; AD, SR, wave start, PW hi, PWM speed, staccato cut, FM or vibrato spec, flags
; flags: bit0 test-bit pulse, bit1 digi kick, bit3 sync lead, bit4 VIBRATO
; bit5 = bass filter envelope (voice 2 only)
;        (bit4: spec byte = delay(x2 frames)<<4 | depth nibble, 2 = +/-0.27 semitone)
instab:
        !byte $00,$00, w_bsub-wavetab, $08,$00,$00,$00,$00   ; 0 SILENT
        !byte $35,$98, w_lead1-wavetab, $06,$28,$00,$32,$11   ; 1 LEAD1
        !byte $25,$88, w_lead2-wavetab, $08,$00,$00,$42,$10   ; 2 LEAD2
        !byte $35,$78, w_lead3-wavetab, $04,$d8,$00,$52,$11   ; 3 LEAD3
        !byte $26,$b5, w_bkick-wavetab, $08,$00,$00,$12,$23   ; 4 BKICK  (square + soft FM + filter env)
        !byte $26,$b5, w_bplain-wavetab, $08,$00,$00,$12,$20   ; 5 BPLAIN (square + soft FM + filter env)
        !byte $29,$e7, w_blong-wavetab, $08,$00,$00,$12,$20   ; 6 BLONG (square)
        !byte $26,$b5, w_bdive-wavetab, $08,$00,$00,$12,$20   ; 7 BDIVE (square)
        !byte $25,$b5, w_bsaw-wavetab, $08,$00,$00,$12,$20   ; 8 BSAW (now square, unused)
        !byte $05,$c5, w_lpower-wavetab, $06,$38,$05,$11,$01   ; 9 STAB
        !byte $08,$c6, w_lmin-wavetab, $06,$28,$00,$12,$01   ; 10 ARPMIN
        !byte $08,$c6, w_lmaj-wavetab, $06,$28,$00,$12,$01   ; 11 ARPMAJ
        !byte $03,$00, w_hat-wavetab, $08,$00,$02,$00,$00   ; 12 HAT
        !byte $05,$00, w_ohat-wavetab, $08,$00,$08,$00,$00   ; 13 OHAT
        !byte $07,$00, w_snare-wavetab, $08,$00,$06,$00,$00   ; 14 SNARE
        !byte $08,$00, w_tom-wavetab, $08,$00,$0a,$00,$00   ; 15 TOM
        !byte $08,$00, w_tomh-wavetab, $08,$00,$08,$00,$00   ; 16 TOMH
        !byte $09,$00, w_toml-wavetab, $08,$00,$0c,$00,$00   ; 17 TOML
        !byte $09,$00, w_crash-wavetab, $08,$00,$1c,$00,$00   ; 18 CRASH
        !byte $01,$00, w_clap-wavetab, $08,$00,$06,$00,$00   ; 19 CLAP
        !byte $a8,$f0, w_riser-wavetab, $08,$00,$00,$00,$00   ; 20 RISER
        !byte $05,$c4, w_lstac-wavetab, $06,$50,$05,$12,$01   ; 21 RUN
        !byte $01,$02, w_tick-wavetab, $04,$00,$00,$00,$00   ; 22 TICK
        !byte $50,$03, w_shake-wavetab, $08,$00,$00,$00,$00   ; 23 SHAKE
        !byte $40,$04, w_ghost-wavetab, $08,$00,$00,$00,$00   ; 24 GHOST
        !byte $05,$00, w_bongo-wavetab, $08,$00,$05,$00,$00   ; 25 BONGO
        !byte $15,$85, w_bplain-wavetab, $08,$00,$03,$12,$20   ; 26 BGHOST (square)
        !byte $06,$c6, w_bsub-wavetab, $08,$00,$00,$00,$00   ; 27 BSUB (square)
        !byte $07,$64, w_lead3-wavetab, $06,$12,$00,$00,$01   ; 28 PLUCK (pulse arp)
        !byte $05,$54, w_lead3-wavetab, $04,$d8,$00,$52,$11   ; 29 ECHO (soft pulse, vibrato)

; ============ WAVE TABLES (236 bytes, max 256) ============
; ctrl, note.  note: bit7 absolute | bit6 semitones below | else semitones above
; ctrl $ff = jump to row offset
wavetab:
w_lead1:  !byte $41,$40|2
          !byte $41,$40|1
w_lead1_l: !byte $41,0
        !byte $ff,w_lead1_l-wavetab
w_lead2:  !byte $21,0
        !byte $ff,w_lead2-wavetab
w_lead3:  !byte $41,0
        !byte $ff,w_lead3-wavetab
w_bsub:   !byte $11,0
        !byte $ff,w_bsub-wavetab
w_bkick:  !byte $11,36
          !byte $11,24
          !byte $11,12
w_bkick_l:        !byte $11,0
        !byte $ff,w_bkick_l-wavetab
w_bplain: !byte $11,12
w_bplain_l:        !byte $11,0
        !byte $ff,w_bplain_l-wavetab
w_blong:  !byte $11,0
          !byte $11,0
          !byte $11,0
          !byte $11,0
        !byte $ff,w_blong-wavetab
w_bdive:  !byte $11,24
          !byte $11,18
          !byte $11,12
          !byte $11,6
w_bdive_l:        !byte $11,0
        !byte $ff,w_bdive_l-wavetab
w_bsaw:   !byte $11,12
w_bsaw_l:        !byte $11,0
        !byte $ff,w_bsaw_l-wavetab
w_lpower: !byte $41,0
          !byte $41,7
          !byte $41,0
          !byte $41,12
        !byte $ff,w_lpower-wavetab
w_lmin:   !byte $41,0
          !byte $41,3
          !byte $51,7
          !byte $41,12
        !byte $ff,w_lmin-wavetab
w_lmaj:   !byte $41,0
          !byte $41,4
          !byte $51,7
          !byte $41,12
        !byte $ff,w_lmaj-wavetab
w_lstac:  !byte $41,12
          !byte $51,0
w_lstac_l:        !byte $41,0
        !byte $ff,w_lstac_l-wavetab
w_hat:    !byte $81,$80|82
          !byte $81,$80|80
w_hat_l:        !byte $80,$80|80
        !byte $ff,w_hat_l-wavetab
w_ohat:   !byte $81,$80|82
          !byte $81,$80|81
          !byte $81,$80|80
w_ohat_l:        !byte $81,$80|79
        !byte $ff,w_ohat_l-wavetab
w_snare:  !byte $81,$80|76
          !byte $81,$80|72
          !byte $41,$80|54
w_snare_l:        !byte $81,$80|68
        !byte $ff,w_snare_l-wavetab
w_tom:    !byte $15,$80|52
          !byte $15,$80|49
          !byte $15,$80|46
          !byte $15,$80|43
w_tom_l:        !byte $15,$80|40
        !byte $ff,w_tom_l-wavetab
w_tomh:   !byte $15,$80|58
          !byte $15,$80|55
          !byte $15,$80|52
w_tomh_l:        !byte $15,$80|49
        !byte $ff,w_tomh_l-wavetab
w_toml:   !byte $15,$80|46
          !byte $15,$80|43
          !byte $15,$80|40
w_toml_l:        !byte $15,$80|37
        !byte $ff,w_toml_l-wavetab
w_crash:  !byte $81,$80|86
          !byte $81,$80|84
w_crash_l:        !byte $81,$80|82
        !byte $ff,w_crash_l-wavetab
w_clap:   !byte $81,$80|70
          !byte $80,$80|70
          !byte $81,$80|68
          !byte $80,$80|68
w_clap_l:        !byte $81,$80|66
        !byte $ff,w_clap_l-wavetab
w_riser:  !byte $81,$80|36
          !byte $81,$80|40
          !byte $81,$80|44
          !byte $81,$80|48
          !byte $81,$80|52
          !byte $81,$80|56
          !byte $81,$80|60
          !byte $81,$80|64
          !byte $81,$80|68
          !byte $81,$80|72
          !byte $81,$80|76
w_riser_l:        !byte $81,$80|80
        !byte $ff,w_riser_l-wavetab
w_tick:   !byte $81,$80|90
          !byte $41,$80|78
w_tick_l: !byte $40,$80|78
        !byte $ff,w_tick_l-wavetab
w_shake:  !byte $81,$80|88
w_shake_l: !byte $80,$80|88
        !byte $ff,w_shake_l-wavetab
w_ghost:  !byte $81,$80|76
w_ghost_l: !byte $80,$80|70
        !byte $ff,w_ghost_l-wavetab
w_bongo:  !byte $11,$80|72
          !byte $11,$80|68
w_bongo_l: !byte $11,$80|66
        !byte $ff,w_bongo_l-wavetab

; ============ SONG DATA ============
stream_lo: !byte <s_v1, <s_v2, <s_v3
stream_hi: !byte >s_v1, >s_v2, >s_v3
; 112 bars x 16 ticks = 1792 ticks in every stream (checked by the generator).
; bars 1-24 INTRO | 25-88 MIDSECTION (8 x 8) | 89-112 OUTRO
; V3 stream also carries the global commands (speed, transpose, filter, title).

!zone
s_v1:
; bar 1  INTRO a
        +setins I_LEAD1
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
; bar 2  INTRO a
        +nt n_e5, 6
        +nt n_fs5, 2
        +nt n_g5, 8
; bar 3  INTRO a
        +nt n_c6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e5, 6
        +nt n_g5, 2
; bar 4  INTRO a
        +nt n_fs5, 4
        +nt n_a5, 4
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 4
; bar 5  INTRO a
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
; bar 6  INTRO a
        +nt n_a5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 4
; bar 7  INTRO a
        +nt n_c6, 2
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
        +nt n_g5, 2
        +nt n_a5, 2
; bar 8  INTRO a
        +nt n_b5, 8
        +nt n_ds6, 2
        +nt n_b5, 2
        +nt n_fs5, 4
; bar 9  INTRO b
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_a5, 4
; bar 10  INTRO b
        +nt n_c6, 2
        +nt n_d6, 2
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
; bar 11  INTRO b
        +nt n_g6, 6
        +nt n_e6, 2
        +nt n_c6, 4
        +nt n_e6, 4
; bar 12  INTRO b
        +nt n_d6, 4
        +nt n_fs6, 4
        +nt n_e6, 4
        +nt n_d6, 4
; bar 13  INTRO b
        +nt n_e6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_b5, 4
; bar 14  INTRO b
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 4
        +nt n_d6, 4
        +nt n_b5, 4
; bar 15  INTRO b
        +nt n_ds6, 6
        +nt n_fs6, 2
        +nt n_b5, 4
        +nt n_a5, 2
        +nt n_fs5, 2
; bar 16  INTRO b
        +nt n_e5, 8
        +nt n_f5, 2
        +nt n_e5, 2
        +rs 4
; bar 17  INTRO c (build)
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_e6, 2
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_e6, 2
; bar 18  INTRO c (build)
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_e6, 2
        +nt n_d6, 2
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_b5, 2
; bar 19  INTRO c (build)
        +nt n_c5, 2
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_c6, 2
        +nt n_e6, 2
        +nt n_c6, 2
        +nt n_g5, 2
        +nt n_e5, 2
; bar 20  INTRO c (build)
        +nt n_d5, 2
        +nt n_fs5, 2
        +nt n_a5, 2
        +nt n_d6, 2
        +nt n_fs6, 2
        +nt n_d6, 2
        +nt n_a5, 2
        +nt n_fs5, 2
; bar 21  INTRO c (build)
        +nt n_e6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e6, 4
        +nt n_g6, 4
; bar 22  INTRO c (build)
        +nt n_a5, 2
        +nt n_c6, 2
        +nt n_e6, 4
        +nt n_d6, 2
        +nt n_c6, 2
        +nt n_a5, 4
; bar 23  INTRO c (build)
        +nt n_ds6, 4
        +nt n_fs6, 4
        +nt n_b5, 4
        +nt n_ds6, 4
; bar 24  INTRO c (build)
        +nt n_b5, 8
        +nt n_a5, 2
        +nt n_b5, 2
        +rs 4
; bar 25  MID 1 square bass + arps
        +setins I_ARPMIN
        +nt n_e4, 6
        +rs 2
        +nt n_e4, 6
        +rs 2
; bar 26  MID 1 square bass + arps
        +setins I_ARPMIN
        +nt n_e4, 6
        +rs 2
        +nt n_e4, 6
        +rs 2
; bar 27  MID 1 square bass + arps
        +setins I_ARPMAJ
        +nt n_d4, 6
        +rs 2
        +nt n_d4, 6
        +rs 2
; bar 28  MID 1 square bass + arps
        +setins I_ARPMAJ
        +nt n_d4, 6
        +rs 2
        +nt n_d4, 6
        +rs 2
; bar 29  MID 1 square bass + arps
        +setins I_ARPMAJ
        +nt n_c4, 6
        +rs 2
        +nt n_c4, 6
        +rs 2
; bar 30  MID 1 square bass + arps
        +setins I_ARPMAJ
        +nt n_c4, 6
        +rs 2
        +nt n_c4, 6
        +rs 2
; bar 31  MID 1 square bass + arps
        +setins I_ARPMAJ
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 32  MID 1 square bass + arps
        +setins I_ARPMAJ
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 33  MID 2 theme A over bass
        +setins I_LEAD1
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
; bar 34  MID 2 theme A over bass
        +nt n_e5, 6
        +nt n_fs5, 2
        +nt n_g5, 8
; bar 35  MID 2 theme A over bass
        +nt n_c6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e5, 6
        +nt n_g5, 2
; bar 36  MID 2 theme A over bass
        +nt n_fs5, 4
        +nt n_a5, 4
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 4
; bar 37  MID 2 theme A over bass
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
; bar 38  MID 2 theme A over bass
        +nt n_a5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 4
; bar 39  MID 2 theme A over bass
        +nt n_c6, 2
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
        +nt n_g5, 2
        +nt n_a5, 2
; bar 40  MID 2 theme A over bass
        +nt n_b5, 8
        +nt n_ds6, 2
        +nt n_b5, 2
        +nt n_fs5, 4
; bar 41  MID 3 walking bass + arps
        +setins I_ARPMIN
        +nt n_e4, 6
        +rs 2
        +nt n_e4, 6
        +rs 2
; bar 42  MID 3 walking bass + arps
        +setins I_RUN
        +nt n_c5, 2
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_g4, 2
        +nt n_a4, 2
; bar 43  MID 3 walking bass + arps
        +setins I_ARPMAJ
        +nt n_d4, 6
        +rs 2
        +nt n_d4, 6
        +rs 2
; bar 44  MID 3 walking bass + arps
        +setins I_RUN
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_b4, 2
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_b4, 2
; bar 45  MID 3 walking bass + arps
        +setins I_ARPMIN
        +nt n_a3, 6
        +rs 2
        +nt n_a3, 6
        +rs 2
; bar 46  MID 3 walking bass + arps
        +setins I_RUN
        +nt n_c5, 2
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_g4, 2
        +nt n_a4, 2
; bar 47  MID 3 walking bass + arps
        +setins I_ARPMAJ
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 48  MID 3 walking bass + arps
        +setins I_ARPMAJ
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 49  MID 4 gallop bass + stabs
        +setins I_RUN
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_b4, 2
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_b4, 2
; bar 50  MID 4 gallop bass + stabs
        +setins I_ARPMAJ
        +nt n_g3, 6
        +rs 2
        +nt n_g3, 6
        +rs 2
; bar 51  MID 4 gallop bass + stabs
        +setins I_RUN
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_b4, 2
        +nt n_a4, 2
        +nt n_b4, 2
; bar 52  MID 4 gallop bass + stabs
        +setins I_ARPMIN
        +nt n_a3, 6
        +rs 2
        +nt n_a3, 6
        +rs 2
; bar 53  MID 4 gallop bass + stabs
        +setins I_STAB
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
; bar 54  MID 4 gallop bass + stabs
        +rs 2
        +nt n_g3, 2
        +rs 2
        +nt n_g3, 2
        +rs 2
        +nt n_g3, 2
        +rs 2
        +nt n_g3, 2
; bar 55  MID 4 gallop bass + stabs
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
; bar 56  MID 4 gallop bass + stabs
        +setins I_ARPMAJ
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 57  MID 5 half-time + slow theme
        +setins I_LEAD1
        +nt n_c6, 6
        +nt n_b5, 2
        +nt n_a5, 8
; bar 58  MID 5 half-time + slow theme
        +nt n_e5, 4
        +nt n_a5, 4
        +nt n_c6, 8
; bar 59  MID 5 half-time + slow theme
        +nt n_b5, 6
        +nt n_g5, 2
        +nt n_e5, 8
; bar 60  MID 5 half-time + slow theme
        +nt n_g5, 4
        +nt n_b5, 4
        +nt n_e6, 8
; bar 61  MID 5 half-time + slow theme
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 8
; bar 62  MID 5 half-time + slow theme
        +nt n_g5, 4
        +nt n_c6, 4
        +nt n_e6, 4
        +nt n_g6, 4
; bar 63  MID 5 half-time + slow theme
        +nt n_fs6, 6
        +nt n_e6, 2
        +nt n_d6, 4
        +nt n_a5, 4
; bar 64  MID 5 half-time + slow theme
        +nt n_ds6, 4
        +nt n_fs6, 4
        +nt n_b5, 8
; bar 65  MID 6 stabs + runs
        +setins I_STAB
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
        +rs 1
        +nt n_e4, 2
; bar 66  MID 6 stabs + runs
        +rs 2
        +nt n_d4, 2
        +rs 2
        +nt n_d4, 2
        +rs 2
        +nt n_d4, 2
        +rs 2
        +nt n_d4, 2
; bar 67  MID 6 stabs + runs
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
        +rs 1
        +nt n_c4, 2
; bar 68  MID 6 stabs + runs
        +rs 2
        +nt n_b3, 2
        +rs 2
        +nt n_b3, 2
        +rs 2
        +nt n_b3, 2
        +rs 2
        +nt n_b3, 2
; bar 69  MID 6 stabs + runs
        +setins I_ARPMIN
        +nt n_e4, 6
        +rs 2
        +nt n_e4, 6
        +rs 2
; bar 70  MID 6 stabs + runs
        +setins I_RUN
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_b4, 2
        +nt n_a4, 2
        +nt n_b4, 2
; bar 71  MID 6 stabs + runs
        +setins I_ARPMAJ
        +nt n_c4, 6
        +rs 2
        +nt n_c4, 6
        +rs 2
; bar 72  MID 6 stabs + runs
        +setins I_ARPMAJ
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 73  MID 7 theme B full drive
        +setins I_LEAD1
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_a5, 4
; bar 74  MID 7 theme B full drive
        +nt n_c6, 2
        +nt n_d6, 2
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
; bar 75  MID 7 theme B full drive
        +nt n_g6, 6
        +nt n_e6, 2
        +nt n_c6, 4
        +nt n_e6, 4
; bar 76  MID 7 theme B full drive
        +nt n_d6, 4
        +nt n_fs6, 4
        +nt n_e6, 4
        +nt n_d6, 4
; bar 77  MID 7 theme B full drive
        +nt n_e6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_b5, 4
; bar 78  MID 7 theme B full drive
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 4
        +nt n_d6, 4
        +nt n_b5, 4
; bar 79  MID 7 theme B full drive
        +nt n_ds6, 6
        +nt n_fs6, 2
        +nt n_b5, 4
        +nt n_a5, 2
        +nt n_fs5, 2
; bar 80  MID 7 theme B full drive
        +nt n_e5, 8
        +nt n_f5, 2
        +nt n_e5, 2
        +rs 4
; bar 81  MID 8 build + bass break
        +setins I_ARPMIN
        +nt n_e4, 6
        +rs 2
        +nt n_e4, 6
        +rs 2
; bar 82  MID 8 build + bass break
        +setins I_ARPMAJ
        +nt n_d4, 6
        +rs 2
        +nt n_d4, 6
        +rs 2
; bar 83  MID 8 build + bass break
        +nt n_c4, 6
        +rs 2
        +nt n_c4, 6
        +rs 2
; bar 84  MID 8 build + bass break
        +nt n_b3, 6
        +rs 2
        +nt n_b3, 6
        +rs 2
; bar 85  MID 8 build + bass break
        +setins I_RUN
        +nt n_a3, 2
        +nt n_c4, 2
        +nt n_d4, 2
        +nt n_e4, 2
        +nt n_g4, 2
        +nt n_a4, 2
        +nt n_c5, 2
        +nt n_d5, 2
; bar 86  MID 8 build + bass break
        +nt n_a4, 2
        +nt n_c5, 2
        +nt n_d5, 2
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_c6, 2
        +nt n_d6, 2
; bar 87  MID 8 build + bass break
        +nt n_b3, 1
        +nt n_c4, 1
        +nt n_ds4, 1
        +nt n_e4, 1
        +nt n_fs4, 1
        +nt n_g4, 1
        +nt n_a4, 1
        +nt n_b4, 1
        +nt n_c5, 1
        +nt n_ds5, 1
        +nt n_e5, 1
        +nt n_fs5, 1
        +nt n_g5, 1
        +nt n_a5, 1
        +nt n_b5, 1
        +nt n_c6, 1
; bar 88  MID 8 build + bass break
        +rs 16
; bar 89  OUTRO a
        +setins I_LEAD1
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
; bar 90  OUTRO a
        +nt n_e5, 6
        +nt n_fs5, 2
        +nt n_g5, 8
; bar 91  OUTRO a
        +nt n_c6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e5, 6
        +nt n_g5, 2
; bar 92  OUTRO a
        +nt n_fs5, 4
        +nt n_a5, 4
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 4
; bar 93  OUTRO a
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
; bar 94  OUTRO a
        +nt n_a5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 4
; bar 95  OUTRO a
        +nt n_c6, 2
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
        +nt n_g5, 2
        +nt n_a5, 2
; bar 96  OUTRO a
        +nt n_b5, 8
        +nt n_ds6, 2
        +nt n_b5, 2
        +nt n_fs5, 4
; bar 97  OUTRO b (reprise)
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_a5, 4
; bar 98  OUTRO b (reprise)
        +nt n_c6, 2
        +nt n_d6, 2
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
; bar 99  OUTRO b (reprise)
        +nt n_g6, 6
        +nt n_e6, 2
        +nt n_c6, 4
        +nt n_e6, 4
; bar 100  OUTRO b (reprise)
        +nt n_d6, 4
        +nt n_fs6, 4
        +nt n_e6, 4
        +nt n_d6, 4
; bar 101  OUTRO b (reprise)
        +nt n_e6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_b5, 4
; bar 102  OUTRO b (reprise)
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 4
        +nt n_d6, 4
        +nt n_b5, 4
; bar 103  OUTRO b (reprise)
        +nt n_ds6, 6
        +nt n_fs6, 2
        +nt n_b5, 4
        +nt n_a5, 2
        +nt n_fs5, 2
; bar 104  OUTRO b (reprise)
        +nt n_e5, 8
        +nt n_f5, 2
        +nt n_e5, 2
        +rs 4
; bar 105  OUTRO closing (key lift +2)
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
        +nt n_a5, 4
; bar 106  OUTRO closing (key lift +2)
        +nt n_c6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
; bar 107  OUTRO closing (key lift +2)
        +nt n_d6, 6
        +nt n_fs6, 2
        +nt n_e6, 4
        +nt n_d6, 4
; bar 108  OUTRO closing (key lift +2)
        +nt n_b5, 8
        +nt n_a5, 2
        +nt n_fs5, 2
        +nt n_ds5, 4
; bar 109  OUTRO closing (key lift +2)
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_b5, 4
        +nt n_e6, 4
        +nt n_g6, 4
; bar 110  OUTRO closing (key lift +2)
        +nt n_g6, 4
        +nt n_e6, 2
        +nt n_g6, 2
        +nt n_c6, 8
; bar 111  OUTRO closing (key lift +2)
        +nt n_fs6, 4
        +nt n_ds6, 4
        +nt n_b5, 8
; bar 112  OUTRO closing (key lift +2)
        +nt n_b4, 2
        +nt n_e5, 14
        !byte $fe

!zone
s_v2:
; bar 1  INTRO a
        +setins I_PLUCK
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 2  INTRO a
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 3  INTRO a
        +nt n_c3, 4
        +nt n_g3, 4
        +nt n_c4, 4
        +nt n_e4, 4
; bar 4  INTRO a
        +nt n_d3, 4
        +nt n_a3, 4
        +nt n_d4, 4
        +nt n_fs4, 4
; bar 5  INTRO a
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 6  INTRO a
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 7  INTRO a
        +nt n_c3, 4
        +nt n_g3, 4
        +nt n_c4, 4
        +nt n_e4, 4
; bar 8  INTRO a
        +nt n_b2, 4
        +nt n_fs3, 4
        +nt n_b3, 4
        +nt n_ds4, 4
; bar 9  INTRO b
        +nt n_a3, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_e4, 2
; bar 10  INTRO b
        +nt n_a3, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_e4, 2
; bar 11  INTRO b
        +nt n_c3, 2
        +nt n_g3, 2
        +nt n_c4, 2
        +nt n_e4, 2
        +nt n_c4, 2
        +nt n_g3, 2
        +nt n_c4, 2
        +nt n_g3, 2
; bar 12  INTRO b
        +nt n_d3, 2
        +nt n_a3, 2
        +nt n_d4, 2
        +nt n_fs4, 2
        +nt n_d4, 2
        +nt n_a3, 2
        +nt n_d4, 2
        +nt n_a3, 2
; bar 13  INTRO b
        +nt n_e3, 2
        +nt n_b3, 2
        +nt n_e4, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_e4, 2
        +nt n_b3, 2
; bar 14  INTRO b
        +nt n_g3, 2
        +nt n_d4, 2
        +nt n_g4, 2
        +nt n_b4, 2
        +nt n_g4, 2
        +nt n_d4, 2
        +nt n_g4, 2
        +nt n_d4, 2
; bar 15  INTRO b
        +nt n_b2, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_fs3, 2
; bar 16  INTRO b
        +nt n_b2, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_fs3, 2
; bar 17  INTRO c (build)
        +nt n_e3, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
; bar 18  INTRO c (build)
        +nt n_e3, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
; bar 19  INTRO c (build)
        +nt n_c3, 2
        +nt n_c4, 2
        +nt n_g3, 2
        +nt n_e4, 2
        +nt n_c4, 2
        +nt n_g3, 2
        +nt n_e4, 2
        +nt n_c4, 2
; bar 20  INTRO c (build)
        +nt n_d3, 2
        +nt n_d4, 2
        +nt n_a3, 2
        +nt n_fs4, 2
        +nt n_d4, 2
        +nt n_a3, 2
        +nt n_fs4, 2
        +nt n_d4, 2
; bar 21  INTRO c (build)
        +nt n_e3, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
; bar 22  INTRO c (build)
        +nt n_a3, 2
        +nt n_a4, 2
        +nt n_e4, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_e4, 2
        +nt n_c5, 2
        +nt n_a4, 2
; bar 23  INTRO c (build)
        +nt n_b2, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
; bar 24  INTRO c (build)
        +nt n_b2, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
; bar 25  MID 1 square bass + arps [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 26  MID 1 square bass + arps [Em sync]
        +setins I_BKICK
        +nt n_e2, 3
        +setins I_BPLAIN
        +nt n_e2, 3
        +nt n_e3, 2
        +setins I_BKICK
        +nt n_e2, 3
        +setins I_BPLAIN
        +nt n_d3, 3
        +nt n_b2, 2
; bar 27  MID 1 square bass + arps [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 28  MID 1 square bass + arps [D sync]
        +setins I_BKICK
        +nt n_d2, 3
        +setins I_BPLAIN
        +nt n_d2, 3
        +nt n_d3, 2
        +setins I_BKICK
        +nt n_d2, 3
        +setins I_BPLAIN
        +nt n_c3, 3
        +nt n_a2, 2
; bar 29  MID 1 square bass + arps [C drive]
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_g2, 2
; bar 30  MID 1 square bass + arps [C sync]
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_c2, 3
        +nt n_c3, 2
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_as2, 3
        +nt n_g2, 2
; bar 31  MID 1 square bass + arps [B drive]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_fs2, 2
; bar 32  MID 1 square bass + arps [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 33  MID 2 theme A over bass [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 34  MID 2 theme A over bass [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 35  MID 2 theme A over bass [C sync]
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_c2, 3
        +nt n_c3, 2
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_as2, 3
        +nt n_g2, 2
; bar 36  MID 2 theme A over bass [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 37  MID 2 theme A over bass [Em gallop]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_e3, 1
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_e3, 1
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_e3, 1
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_b2, 1
        +nt n_d3, 1
; bar 38  MID 2 theme A over bass [Em sync]
        +setins I_BKICK
        +nt n_e2, 3
        +setins I_BPLAIN
        +nt n_e2, 3
        +nt n_e3, 2
        +setins I_BKICK
        +nt n_e2, 3
        +setins I_BPLAIN
        +nt n_d3, 3
        +nt n_b2, 2
; bar 39  MID 2 theme A over bass [C drive]
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_g2, 2
; bar 40  MID 2 theme A over bass [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 41  MID 3 walking bass + arps [Em walk]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_g2, 2
        +nt n_b2, 2
        +nt n_g2, 2
        +setins I_BKICK
        +nt n_e3, 2
        +setins I_BPLAIN
        +nt n_b2, 2
        +nt n_g2, 2
        +nt n_e2, 2
; bar 42  MID 3 walking bass + arps [C drive]
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_g2, 2
; bar 43  MID 3 walking bass + arps [D walk]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_fs2, 2
        +nt n_a2, 2
        +nt n_fs2, 2
        +setins I_BKICK
        +nt n_d3, 2
        +setins I_BPLAIN
        +nt n_a2, 2
        +nt n_fs2, 2
        +nt n_d2, 2
; bar 44  MID 3 walking bass + arps [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 45  MID 3 walking bass + arps [Am walk]
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_e2, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_a2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_c2, 2
        +nt n_a1, 2
; bar 46  MID 3 walking bass + arps [C sync]
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_c2, 3
        +nt n_c3, 2
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_as2, 3
        +nt n_g2, 2
; bar 47  MID 3 walking bass + arps [B drive]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_fs2, 2
; bar 48  MID 3 walking bass + arps [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 49  MID 4 gallop bass + stabs [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 50  MID 4 gallop bass + stabs [G gallop]
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 1
        +nt n_g2, 1
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 1
        +nt n_g2, 1
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 1
        +nt n_g2, 1
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_d2, 1
        +nt n_f2, 1
; bar 51  MID 4 gallop bass + stabs [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 52  MID 4 gallop bass + stabs [Am sync]
        +setins I_BKICK
        +nt n_a1, 3
        +setins I_BPLAIN
        +nt n_a1, 3
        +nt n_a2, 2
        +setins I_BKICK
        +nt n_a1, 3
        +setins I_BPLAIN
        +nt n_g2, 3
        +nt n_e2, 2
; bar 53  MID 4 gallop bass + stabs [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 54  MID 4 gallop bass + stabs [G gallop]
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 1
        +nt n_g2, 1
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 1
        +nt n_g2, 1
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 1
        +nt n_g2, 1
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_d2, 1
        +nt n_f2, 1
; bar 55  MID 4 gallop bass + stabs [C sync]
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_c2, 3
        +nt n_c3, 2
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_as2, 3
        +nt n_g2, 2
; bar 56  MID 4 gallop bass + stabs [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 57  MID 5 half-time + slow theme [Am half]
        +setins I_BKICK
        +nt n_a1, 4
        +setins I_BPLAIN
        +nt n_a2, 1
        +nt n_a1, 1
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_a1, 4
        +setins I_BPLAIN
        +nt n_g2, 1
        +nt n_e2, 1
        +nt n_d2, 2
; bar 58  MID 5 half-time + slow theme [Am half]
        +setins I_BKICK
        +nt n_a1, 4
        +setins I_BPLAIN
        +nt n_a2, 1
        +nt n_a1, 1
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_a1, 4
        +setins I_BPLAIN
        +nt n_g2, 1
        +nt n_e2, 1
        +nt n_d2, 2
; bar 59  MID 5 half-time + slow theme [Em half]
        +setins I_BKICK
        +nt n_e2, 4
        +setins I_BPLAIN
        +nt n_e3, 1
        +nt n_e2, 1
        +nt n_b2, 2
        +setins I_BKICK
        +nt n_e2, 4
        +setins I_BPLAIN
        +nt n_d3, 1
        +nt n_b2, 1
        +nt n_a2, 2
; bar 60  MID 5 half-time + slow theme [Em half]
        +setins I_BKICK
        +nt n_e2, 4
        +setins I_BPLAIN
        +nt n_e3, 1
        +nt n_e2, 1
        +nt n_b2, 2
        +setins I_BKICK
        +nt n_e2, 4
        +setins I_BPLAIN
        +nt n_d3, 1
        +nt n_b2, 1
        +nt n_a2, 2
; bar 61  MID 5 half-time + slow theme [C half]
        +setins I_BKICK
        +nt n_c2, 4
        +setins I_BPLAIN
        +nt n_c3, 1
        +nt n_c2, 1
        +nt n_g2, 2
        +setins I_BKICK
        +nt n_c2, 4
        +setins I_BPLAIN
        +nt n_as2, 1
        +nt n_g2, 1
        +nt n_f2, 2
; bar 62  MID 5 half-time + slow theme [C half]
        +setins I_BKICK
        +nt n_c2, 4
        +setins I_BPLAIN
        +nt n_c3, 1
        +nt n_c2, 1
        +nt n_g2, 2
        +setins I_BKICK
        +nt n_c2, 4
        +setins I_BPLAIN
        +nt n_as2, 1
        +nt n_g2, 1
        +nt n_f2, 2
; bar 63  MID 5 half-time + slow theme [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 64  MID 5 half-time + slow theme [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 65  MID 6 stabs + runs [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 66  MID 6 stabs + runs [D sync]
        +setins I_BKICK
        +nt n_d2, 3
        +setins I_BPLAIN
        +nt n_d2, 3
        +nt n_d3, 2
        +setins I_BKICK
        +nt n_d2, 3
        +setins I_BPLAIN
        +nt n_c3, 3
        +nt n_a2, 2
; bar 67  MID 6 stabs + runs [C drive]
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_g2, 2
; bar 68  MID 6 stabs + runs [B sync]
        +setins I_BKICK
        +nt n_b1, 3
        +setins I_BPLAIN
        +nt n_b1, 3
        +nt n_b2, 2
        +setins I_BKICK
        +nt n_b1, 3
        +setins I_BPLAIN
        +nt n_a2, 3
        +nt n_fs2, 2
; bar 69  MID 6 stabs + runs [Em walk]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_g2, 2
        +nt n_b2, 2
        +nt n_g2, 2
        +setins I_BKICK
        +nt n_e3, 2
        +setins I_BPLAIN
        +nt n_b2, 2
        +nt n_g2, 2
        +nt n_e2, 2
; bar 70  MID 6 stabs + runs [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 71  MID 6 stabs + runs [C sync]
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_c2, 3
        +nt n_c3, 2
        +setins I_BKICK
        +nt n_c2, 3
        +setins I_BPLAIN
        +nt n_as2, 3
        +nt n_g2, 2
; bar 72  MID 6 stabs + runs [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 73  MID 7 theme B full drive [Am drive]
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 2
        +nt n_a2, 2
        +nt n_a1, 2
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 2
        +nt n_a2, 2
        +nt n_e2, 2
; bar 74  MID 7 theme B full drive [Am gallop]
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 1
        +nt n_a2, 1
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 1
        +nt n_a2, 1
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 1
        +nt n_a2, 1
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_g2, 1
; bar 75  MID 7 theme B full drive [C drive]
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_g2, 2
; bar 76  MID 7 theme B full drive [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 77  MID 7 theme B full drive [Em gallop]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_e3, 1
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_e3, 1
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_e3, 1
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_b2, 1
        +nt n_d3, 1
; bar 78  MID 7 theme B full drive [G drive]
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 2
        +nt n_g2, 2
        +nt n_g1, 2
        +setins I_BKICK
        +nt n_g1, 2
        +setins I_BPLAIN
        +nt n_g1, 2
        +nt n_g2, 2
        +nt n_d2, 2
; bar 79  MID 7 theme B full drive [B sync]
        +setins I_BKICK
        +nt n_b1, 3
        +setins I_BPLAIN
        +nt n_b1, 3
        +nt n_b2, 2
        +setins I_BKICK
        +nt n_b1, 3
        +setins I_BPLAIN
        +nt n_a2, 3
        +nt n_fs2, 2
; bar 80  MID 7 theme B full drive [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 81  MID 8 build + bass break [Em drive]
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_e2, 2
        +setins I_BKICK
        +nt n_e2, 2
        +setins I_BPLAIN
        +nt n_e2, 2
        +nt n_e3, 2
        +nt n_b2, 2
; bar 82  MID 8 build + bass break [D drive]
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_d2, 2
        +setins I_BKICK
        +nt n_d2, 2
        +setins I_BPLAIN
        +nt n_d2, 2
        +nt n_d3, 2
        +nt n_a2, 2
; bar 83  MID 8 build + bass break [C drive]
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_c2, 2
        +setins I_BKICK
        +nt n_c2, 2
        +setins I_BPLAIN
        +nt n_c2, 2
        +nt n_c3, 2
        +nt n_g2, 2
; bar 84  MID 8 build + bass break [B gallop]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 1
        +nt n_b2, 1
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 1
        +nt n_b2, 1
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 1
        +nt n_b2, 1
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_fs2, 1
        +nt n_a2, 1
; bar 85  MID 8 build + bass break [Am drive]
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 2
        +nt n_a2, 2
        +nt n_a1, 2
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 2
        +nt n_a2, 2
        +nt n_e2, 2
; bar 86  MID 8 build + bass break [Am gallop]
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 1
        +nt n_a2, 1
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 1
        +nt n_a2, 1
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_a1, 1
        +nt n_a2, 1
        +setins I_BKICK
        +nt n_a1, 2
        +setins I_BPLAIN
        +nt n_e2, 1
        +nt n_g2, 1
; bar 87  MID 8 build + bass break [B sync]
        +setins I_BKICK
        +nt n_b1, 3
        +setins I_BPLAIN
        +nt n_b1, 3
        +nt n_b2, 2
        +setins I_BKICK
        +nt n_b1, 3
        +setins I_BPLAIN
        +nt n_a2, 3
        +nt n_fs2, 2
; bar 88  MID 8 build + bass break [B fill]
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +nt n_b2, 2
        +nt n_b1, 2
        +setins I_BKICK
        +nt n_b1, 2
        +setins I_BPLAIN
        +nt n_b1, 2
        +setins I_BDIVE
        +nt n_b1, 4
; bar 89  OUTRO a
        +setins I_PLUCK
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 90  OUTRO a
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 91  OUTRO a
        +nt n_c3, 4
        +nt n_g3, 4
        +nt n_c4, 4
        +nt n_e4, 4
; bar 92  OUTRO a
        +nt n_d3, 4
        +nt n_a3, 4
        +nt n_d4, 4
        +nt n_fs4, 4
; bar 93  OUTRO a
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 94  OUTRO a
        +nt n_e3, 4
        +nt n_b3, 4
        +nt n_e4, 4
        +nt n_g4, 4
; bar 95  OUTRO a
        +nt n_c3, 4
        +nt n_g3, 4
        +nt n_c4, 4
        +nt n_e4, 4
; bar 96  OUTRO a
        +nt n_b2, 4
        +nt n_fs3, 4
        +nt n_b3, 4
        +nt n_ds4, 4
; bar 97  OUTRO b (reprise)
        +nt n_a3, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_e4, 2
; bar 98  OUTRO b (reprise)
        +nt n_a3, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_c5, 2
        +nt n_a4, 2
        +nt n_e4, 2
        +nt n_a4, 2
        +nt n_e4, 2
; bar 99  OUTRO b (reprise)
        +nt n_c3, 2
        +nt n_g3, 2
        +nt n_c4, 2
        +nt n_e4, 2
        +nt n_c4, 2
        +nt n_g3, 2
        +nt n_c4, 2
        +nt n_g3, 2
; bar 100  OUTRO b (reprise)
        +nt n_d3, 2
        +nt n_a3, 2
        +nt n_d4, 2
        +nt n_fs4, 2
        +nt n_d4, 2
        +nt n_a3, 2
        +nt n_d4, 2
        +nt n_a3, 2
; bar 101  OUTRO b (reprise)
        +nt n_e3, 2
        +nt n_b3, 2
        +nt n_e4, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_e4, 2
        +nt n_b3, 2
; bar 102  OUTRO b (reprise)
        +nt n_g3, 2
        +nt n_d4, 2
        +nt n_g4, 2
        +nt n_b4, 2
        +nt n_g4, 2
        +nt n_d4, 2
        +nt n_g4, 2
        +nt n_d4, 2
; bar 103  OUTRO b (reprise)
        +nt n_b2, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_fs3, 2
; bar 104  OUTRO b (reprise)
        +nt n_b2, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_b3, 2
        +nt n_fs3, 2
; bar 105  OUTRO closing
        +nt n_e3, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
; bar 106  OUTRO closing
        +nt n_c3, 2
        +nt n_c4, 2
        +nt n_g3, 2
        +nt n_e4, 2
        +nt n_c4, 2
        +nt n_g3, 2
        +nt n_e4, 2
        +nt n_c4, 2
; bar 107  OUTRO closing
        +nt n_d3, 2
        +nt n_d4, 2
        +nt n_a3, 2
        +nt n_fs4, 2
        +nt n_d4, 2
        +nt n_a3, 2
        +nt n_fs4, 2
        +nt n_d4, 2
; bar 108  OUTRO closing
        +nt n_b2, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
        +nt n_fs3, 2
        +nt n_ds4, 2
        +nt n_b3, 2
; bar 109  OUTRO closing
        +nt n_e3, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
        +nt n_b3, 2
        +nt n_g4, 2
        +nt n_e4, 2
; bar 110  OUTRO closing
        +nt n_c3, 4
        +nt n_g3, 4
        +nt n_c4, 4
        +nt n_e4, 4
; bar 111  OUTRO closing
        +nt n_b2, 4
        +nt n_fs3, 4
        +nt n_b3, 4
        +nt n_ds4, 4
; bar 112  OUTRO final hold
        +setins I_LEAD2
        +nt n_b3, 2
        +nt n_e4, 14
        !byte $fe

!zone
s_v3:
; bar 1  INTRO (echo of the lead, 3 ticks late)
        +setspd SPEED
        +settrans 0
        +setflt 6
        +sect 1
        +fade 0,15,60
        +setins I_ECHO
        +rs 3
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 6
        +nt n_fs5, 2
        +nt n_g5, 8
        +nt n_c6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_a5, 4
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 4
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
        +nt n_a5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 4
        +nt n_c6, 2
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 8
        +nt n_ds6, 2
        +nt n_b5, 2
        +nt n_fs5, 4
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_a5, 4
        +nt n_c6, 2
        +nt n_d6, 2
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_g6, 6
        +nt n_e6, 2
        +nt n_c6, 4
        +nt n_e6, 4
        +nt n_d6, 4
        +nt n_fs6, 4
        +nt n_e6, 4
        +nt n_d6, 4
        +nt n_e6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_b5, 4
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 4
        +nt n_d6, 4
        +nt n_b5, 4
        +nt n_ds6, 6
        +nt n_fs6, 2
        +nt n_b5, 4
        +nt n_a5, 2
        +nt n_fs5, 2
        +nt n_e5, 8
        +nt n_f5, 2
        +nt n_e5, 2
        +rs 4
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_e6, 2
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_e6, 2
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_e6, 2
        +nt n_d6, 2
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_b5, 2
        +nt n_c5, 2
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_c6, 2
        +nt n_e6, 2
        +nt n_c6, 2
        +nt n_g5, 2
        +nt n_e5, 2
        +nt n_d5, 2
        +nt n_fs5, 2
        +nt n_a5, 2
        +nt n_d6, 2
        +nt n_fs6, 2
        +nt n_d6, 2
        +nt n_a5, 2
        +nt n_fs5, 2
        +nt n_e6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e6, 4
        +nt n_g6, 4
        +nt n_a5, 2
        +nt n_c6, 2
        +nt n_e6, 4
        +nt n_d6, 2
        +nt n_c6, 2
        +nt n_a5, 4
        +nt n_ds6, 4
        +nt n_fs6, 4
        +nt n_b5, 4
        +nt n_ds6, 4
        +nt n_b5, 8
        +nt n_a5, 2
        +nt n_b5, 2
        +rs 1
; bar 25  MID 1 square bass + arps
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 1
        +sect 2
        +setins I_CRASH
        +nt 0, 2
        +setins I_SHAKE
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 26  MID 1 square bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
; bar 27  MID 1 square bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 28  MID 1 square bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 29  MID 1 square bass + arps
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
; bar 30  MID 1 square bass + arps
        +nt 0, 1
        +rs 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
; bar 31  MID 1 square bass + arps
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
; bar 32  MID 1 square bass + arps
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 33  MID 2 theme A over bass
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 1
        +sect 3
        +setins I_CRASH
        +nt 0, 2
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 34  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 35  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 36  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 37  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 38  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 39  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 40  MID 2 theme A over bass
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 41  MID 3 walking bass + arps
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 4
        +sect 4
        +setins I_CRASH
        +nt 0, 2
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 42  MID 3 walking bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_OHAT
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
; bar 43  MID 3 walking bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 44  MID 3 walking bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_OHAT
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
; bar 45  MID 3 walking bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 46  MID 3 walking bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_OHAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 47  MID 3 walking bass + arps
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 48  MID 3 walking bass + arps
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 49  MID 4 gallop bass + stabs
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 4
        +sect 5
        +setins I_CRASH
        +nt 0, 2
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 50  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 51  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 52  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 53  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 54  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 55  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 56  MID 4 gallop bass + stabs
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 57  MID 5 half-time + slow theme
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 1
        +sect 6
        +setins I_CRASH
        +nt 0, 2
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 58  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 59  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 60  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TOM
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
; bar 61  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 62  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 63  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 64  MID 5 half-time + slow theme
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 65  MID 6 stabs + runs
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 4
        +sect 7
        +setins I_CRASH
        +nt 0, 2
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 66  MID 6 stabs + runs
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_OHAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 67  MID 6 stabs + runs
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 68  MID 6 stabs + runs
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +rs 1
        +setins I_SHAKE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SHAKE
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_CLAP
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_OHAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 69  MID 6 stabs + runs
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
; bar 70  MID 6 stabs + runs
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 71  MID 6 stabs + runs
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 72  MID 6 stabs + runs
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 73  MID 7 theme B full drive
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 4
        +sect 8
        +setins I_CRASH
        +nt 0, 2
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 74  MID 7 theme B full drive
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 75  MID 7 theme B full drive
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 76  MID 7 theme B full drive
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 77  MID 7 theme B full drive
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
; bar 78  MID 7 theme B full drive
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 79  MID 7 theme B full drive
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 80  MID 7 theme B full drive
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
        +setins I_BONGO
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
; bar 81  MID 8 build + bass break
        +setspd SPEED
        +settrans 0
        +fade 15,15,1
        +setflt 5
        +sect 9
        +setins I_CRASH
        +nt 0, 2
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 82  MID 8 build + bass break
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 83  MID 8 build + bass break
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 84  MID 8 build + bass break
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +rs 1
        +setins I_HAT
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +rs 1
        +setins I_TICK
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_HAT
        +nt 0, 1
        +setins I_TICK
        +nt 0, 1
; bar 85  MID 8 build + bass break
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
; bar 86  MID 8 build + bass break
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_GHOST
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
; bar 87  MID 8 build + bass break
        +setins I_GHOST
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
; bar 88  MID 8 build + bass break
        +setins I_RISER
        +nt 0, 8
        +setins I_TOMH
        +nt 0, 1
        +setins I_TOM
        +nt 0, 1
        +nt 0, 1
        +setins I_TOML
        +nt 0, 1
        +setins I_SNARE
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
        +nt 0, 1
; bar 89  OUTRO (echo of the lead)
        +setspd SPEED
        +settrans 0
        +setflt 6
        +sect 10
        +fade 15,15,1
        +setins I_ECHO
        +rs 3
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 6
        +nt n_fs5, 2
        +nt n_g5, 8
        +nt n_c6, 4
        +nt n_b5, 2
        +nt n_g5, 2
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_a5, 4
        +nt n_fs5, 2
        +nt n_e5, 2
        +nt n_d5, 4
        +nt n_b4, 4
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
        +nt n_a5, 6
        +nt n_g5, 2
        +nt n_fs5, 4
        +nt n_e5, 4
        +nt n_c6, 2
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 8
        +nt n_ds6, 2
        +nt n_b5, 2
        +nt n_fs5, 4
        +sect 11
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_a5, 4
        +nt n_c6, 2
        +nt n_d6, 2
        +nt n_e6, 6
        +nt n_d6, 2
        +nt n_c6, 4
        +nt n_g6, 6
        +nt n_e6, 2
        +nt n_c6, 4
        +nt n_e6, 4
        +nt n_d6, 4
        +nt n_fs6, 4
        +nt n_e6, 4
        +nt n_d6, 4
        +fade 15,0,95
        +nt n_e6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_b5, 4
        +nt n_g5, 2
        +nt n_a5, 2
        +nt n_b5, 4
        +nt n_d6, 4
        +nt n_b5, 4
        +nt n_ds6, 6
        +nt n_fs6, 2
        +nt n_b5, 4
        +nt n_a5, 2
        +nt n_fs5, 2
        +nt n_e5, 8
        +nt n_f5, 2
        +nt n_e5, 2
        +rs 1
        +settrans 2
        +sect 12
        +rs 3
        +nt n_e5, 6
        +nt n_g5, 2
        +nt n_b5, 4
        +nt n_a5, 4
        +nt n_c6, 6
        +nt n_b5, 2
        +nt n_g5, 4
        +nt n_e5, 4
        +nt n_d6, 6
        +nt n_fs6, 2
        +nt n_e6, 4
        +nt n_d6, 4
        +nt n_b5, 8
        +nt n_a5, 2
        +nt n_fs5, 2
        +nt n_ds5, 4
        +nt n_e5, 2
        +nt n_g5, 2
        +nt n_b5, 4
        +nt n_e6, 4
        +nt n_g6, 4
        +setspd SPEED+1
        +nt n_g6, 4
        +nt n_e6, 2
        +nt n_g6, 2
        +nt n_c6, 8
        +setspd SPEED+2
        +nt n_fs6, 4
        +nt n_ds6, 4
        +nt n_b5, 8
        +setspd SPEED+4
        +nt n_b4, 2
        +nt n_e5, 11
        !byte $fe

; ===== generated assets =====
SPR_P = 128
SPR_E = 192
SPR_SH = 206
SPR_SPK = 208
SPR_MOON = 210
SPR_MOONO = 211
SPR_SHAD = 212
AA_PR = 0
AA_PL = 213
AA_ER = 229
AA_EL = 236
TILE_HEART = 64
TILE_HEARTE = 65
TILE_STAR = 66
TILE_PAGES = 6
SPR_PAGES = 22
tile_data:
        !byte $00,$66,$ff,$ff,$ff,$7e,$3c,$18,$00,$66,$99,$81,$81,$42,$24,$18
        !byte $18,$18,$7e,$ff,$7e,$3c,$66,$42,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$00,$00,$aa,$00,$00,$00,$aa,$ff,$ff,$ff,$ff
        !byte $ff,$00,$00,$00,$ff,$00,$00,$00,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
        !byte $aa,$aa,$aa,$aa,$aa,$aa,$ff,$00,$00,$00,$00,$00,$aa,$ff,$ff,$ff
        !byte $3c,$3c,$3c,$3c,$3c,$3c,$3c,$3c,$aa,$ff,$00,$00,$00,$00,$00,$00
        !byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$00,$00,$aa,$ff,$ff,$ff,$ff,$ff
        !byte $00,$80,$a8,$6a,$76,$75,$75,$f5,$00,$00,$00,$00,$00,$00,$55,$aa
        !byte $ff,$ff,$ff,$ff,$0c,$0c,$0c,$00,$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0
        !byte $00,$aa,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$03,$03
        !byte $00,$00,$00,$00,$00,$aa,$ff,$ff,$55,$aa,$ff,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$55,$aa,$aa,$00,$00,$00,$aa,$aa,$ff,$ff,$ff
        !byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$aa,$aa,$aa,$ff,$00,$00,$00,$00
        !byte $00,$00,$00,$08,$00,$0c,$3c,$3c,$b0,$b0,$b0,$b0,$b0,$b0,$b0,$b0
        !byte $2c,$2c,$2c,$2c,$2c,$2c,$2c,$2c,$ff,$ff,$55,$00,$00,$00,$00,$00
        !byte $ff,$00,$00,$00,$00,$00,$00,$00,$00,$a8,$ff,$ff,$c0,$c0,$c0,$aa
        !byte $02,$02,$02,$02,$02,$02,$02,$02,$5a,$56,$57,$d7,$f7,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$00,$00,$c0,$03,$03,$03,$03,$03,$03,$03,$03
        !byte $00,$00,$00,$00,$00,$a0,$a8,$da,$00,$00,$00,$00,$a0,$aa,$da,$dd
        !byte $a0,$a8,$da,$d6,$d5,$d5,$f5,$fd,$00,$00,$00,$00,$00,$00,$00,$02
        !byte $00,$00,$00,$00,$02,$0a,$ab,$af,$0c,$aa,$ff,$ff,$3f,$3f,$3f,$aa
        !byte $ff,$ff,$ff,$ff,$ff,$57,$00,$00,$00,$00,$00,$02,$0a,$ab,$af,$ff
        !byte $f0,$00,$c0,$fc,$00,$00,$00,$00,$00,$00,$00,$03,$3f,$ff,$ff,$aa
        !byte $dd,$dd,$fd,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$55
        !byte $aa,$aa,$aa,$aa,$ff,$00,$00,$00,$00,$00,$00,$00,$55,$aa,$aa,$aa
        !byte $aa,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$02,$cf,$3f,$00,$00,$00,$0a
        !byte $00,$a0,$fc,$ff,$00,$00,$00,$a8,$c0,$c0,$c0,$80,$f0,$f0,$f0,$fc
        !byte $00,$00,$02,$02,$a2,$fe,$0e,$02,$ff,$0f,$bf,$ff,$00,$00,$00,$00
        !byte $ff,$ff,$ff,$ff,$03,$03,$03,$00,$ff,$ff,$ff,$ff,$30,$30,$30,$00
        !byte $00,$00,$80,$a0,$68,$5a,$56,$55,$6a,$5a,$5d,$5d,$dd,$fd,$ff,$ff
        !byte $f5,$fd,$ff,$ff,$ff,$ff,$ff,$ff,$d6,$d7,$d7,$f7,$ff,$ff,$ff,$ff
        !byte $3c,$3f,$3f,$ef,$ff,$ff,$ff,$ff,$00,$03,$0f,$03,$0b,$3f,$03,$3f
        !byte $00,$00,$00,$00,$00,$80,$a0,$68,$00,$00,$00,$a0,$fc,$ff,$00,$00
        !byte $40,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$80,$aa,$6a,$7d,$7d,$00,$02,$2a,$ab,$bf,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$00,$80,$a0,$00,$00,$0a,$2a,$af,$bf,$ff,$ff
        !byte $00,$00,$00,$00,$c0,$00,$c0,$f0,$ff,$ff,$c0,$c0,$ea,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$00,$aa,$ff,$ff,$ff,$ff,$ff,$55,$00,$00,$00
        !byte $aa,$aa,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2a,$aa,$bf,$ff
        !byte $00,$80,$a0,$68,$5a,$56,$55,$d5,$00,$00,$00,$00,$08,$0c,$0c,$0c
        !byte $3c,$3f,$3c,$38,$3f,$3f,$ff,$ff,$ff,$08,$0c,$0c,$0f,$0c,$0c,$0c
        !byte $ff,$20,$30,$30,$f0,$30,$30,$30,$b2,$b1,$ba,$be,$a2,$fe,$5e,$b2
        !byte $03,$0f,$3f,$03,$2f,$ff,$0f,$ff,$00,$00,$00,$0a,$2a,$0a,$00,$00
        !byte $2a,$ab,$bf,$ff,$ff,$ff,$ff,$ff,$ff,$dd,$30,$00,$00,$00,$00,$00
        !byte $00,$03,$03,$03,$0e,$0f,$03,$0f,$00,$40,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$80,$a0,$6a,$5a,$5f
        !byte $fd,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$80,$a8,$6a,$76,$75,$75
        !byte $0a,$0b,$2f,$af,$bf,$ff,$ff,$ff,$da,$d6,$d5,$d5,$f5,$fd,$ff,$ff
        !byte $00,$08,$00,$0c,$3c,$3f,$ff,$ff,$3f,$ff,$00,$aa,$ff,$ff,$ff,$ff
        !byte $f4,$fc,$f6,$fc,$fe,$ff,$ff,$fd,$ff,$ff,$ff,$54,$00,$00,$00,$00
        !byte $15,$6a,$aa,$aa,$aa,$aa,$aa,$aa,$00,$54,$a9,$aa,$aa,$ff,$00,$00
        !byte $80,$a8,$6a,$76,$77,$77,$f7,$ff,$c0,$c0,$c0,$cb,$cb,$8b,$fb,$fb
        !byte $00,$00,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
        !byte $55,$aa,$aa,$ff,$00,$00,$00,$00,$00,$aa,$aa,$aa,$ff,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$00,$02,$0a,$00,$00,$02,$0a,$2b,$af,$bf,$ff
        !byte $a8,$6a,$76,$75,$75,$f5,$fd,$ff,$00,$00,$00,$00,$a8,$aa,$f6,$f5
        !byte $da,$dd,$dd,$dd,$fd,$ff,$ff,$ff,$6a,$7f,$7f,$7f,$ff,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00,$80,$00
        !byte $00,$03,$03,$03,$03,$03,$0f,$0f,$c0,$c0,$f0,$f0,$fc,$f0,$fc,$ff
        !byte $00,$02,$00,$03,$0f,$3f,$ff,$ff,$0f,$bb,$ff,$ff,$ff,$ff,$ff,$ff
        !byte $00,$00,$0a,$af,$ff,$ff,$ff,$ff,$f0,$fc,$ff,$c0,$c0,$ea,$ff,$ff
        !byte $c0,$f0,$fc,$aa,$ff,$ff,$ff,$ff,$bf,$bf,$bf,$ff,$bf,$bf,$bf,$ff
        !byte $ae,$af,$ac,$6c,$94,$ac,$ac,$ac,$0e,$c3,$c2,$c2,$fe,$c3,$f2,$fc
        !byte $ff,$ff,$ff,$ff,$7f,$01,$00,$00,$c0,$f0,$fc,$c0,$f0,$ff,$f0,$fc
        !byte $2c,$14,$14,$2c,$2c,$2c,$2c,$2c,$ff,$f0,$fc,$ff,$00,$00,$00,$00
        !byte $ff,$ff,$ff,$fd,$f0,$00,$00,$00,$03,$00,$02,$0f,$00,$00,$00,$00
        !byte $ff,$ff,$5f,$05,$00,$00,$00,$00,$80,$a0,$aa,$6a,$5a,$5d,$dd,$fd
        !byte $cb,$cb,$4b,$cb,$cb,$cb,$cb,$cb,$00,$00,$a0,$a8,$a1,$a0,$a0,$00
        !byte $00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$00
        !byte $bf,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ab,$bf,$ff,$ff,$ff,$ff,$ff,$ff
        !byte $5f,$5f,$df,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$20,$30,$30,$30
        !byte $03,$aa,$ff,$ff,$0f,$0f,$0f,$aa,$00,$0a,$3f,$ff,$00,$00,$00,$2a
        !byte $3f,$bf,$ff,$ab,$ff,$ff,$ff,$ff,$00,$08,$ac,$f0,$00,$2c,$2c,$2c
        !byte $00,$00,$00,$c0,$c0,$e0,$f0,$c0,$00,$0a,$2b,$2f,$2f,$ef,$3f,$2f
        !byte $2f,$2f,$ef,$3f,$2f,$2f,$ef,$3f,$ff,$fd,$34,$3c,$3c,$3c,$3c,$3c
        !byte $b2,$b2,$b2,$b2,$b2,$b2,$b2,$b1,$f0,$fc,$ff,$fc,$ff,$ff,$fc,$ff
        !byte $c2,$f2,$fe,$f1,$fe,$fe,$f2,$fe,$00,$00,$00,$03,$00,$00,$00,$00
        !byte $02,$02,$02,$a2,$fa,$fe,$fe,$f1,$00,$54,$a9,$fc,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$2a,$aa,$00,$00,$00,$00,$80,$a0,$68,$5a
        !byte $80,$aa,$6a,$7d,$7d,$7d,$fd,$ff,$a8,$da,$d6,$d7,$d7,$f7,$ff,$ff
        !byte $d5,$f5,$fd,$ff,$ff,$ff,$ff,$ff,$80,$a0,$68,$5a,$56,$57,$d7,$f7
        !byte $aa,$aa,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$30,$c0,$00,$00,$00,$00
        !byte $00,$80,$f3,$fc,$00,$00,$aa,$af,$00,$02,$0f,$aa,$ff,$ff,$ff,$ff
        !byte $ff,$ff,$ff,$ae,$ff,$ff,$ff,$ff,$ff,$bf,$ff,$0c,$0c,$0c,$00,$aa
        !byte $fc,$ff,$ff,$30,$30,$ba,$ff,$ff,$ff,$ff,$3f,$3f,$3f,$0a,$af,$ff
        !byte $00,$00,$00,$00,$00,$00,$a0,$f8,$00,$02,$02,$02,$0e,$af,$f3,$02
        !byte $f0,$d8,$f0,$f8,$fc,$ff,$f4,$dc,$0a,$2b,$2f,$2f,$ef,$3f,$2f,$2f
        !byte $f8,$f0,$f8,$fc,$f7,$fc,$74,$c0,$00,$20,$00,$30,$f0,$fc,$ff,$ff
        !byte $ff,$fd,$04,$00,$00,$00,$00,$00,$ab,$fa,$3f,$0b,$0b,$0b,$05,$0b
        !byte $ff,$ff,$ff,$ff,$00,$00,$00,$00,$3f,$03,$2f,$ff,$00,$00,$00,$00
        !byte $ff,$ff,$77,$03,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$3d,$00,$00
        !byte $00,$00,$96,$aa,$aa,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00
        !byte $10,$00,$00,$00,$00,$00,$00,$00,$00,$10,$54,$10,$00,$00,$00,$00
        !byte $00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$05,$5a,$55,$aa,$aa,$aa,$ff,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$a0,$a8,$00,$00,$00,$00,$0a,$aa,$af,$ff
spr_data:
        !byte $00,$54,$00,$01,$ed,$00,$00,$a9,$00,$01,$a9,$00,$01,$65,$00,$01
        !byte $69,$00,$00,$65,$10,$01,$ea,$74,$01,$aa,$50,$06,$69,$90,$06,$69
        !byte $40,$01,$6a,$40,$00,$6a,$40,$00,$6a,$40,$01,$a9,$40,$01,$5a,$40
        !byte $06,$56,$50,$06,$96,$d0,$05,$56,$50,$1a,$41,$a4,$15,$51,$55,$00
        !byte $00,$00,$00,$00,$54,$00,$01,$f5,$00,$01,$a9,$00,$00,$a9,$00,$01
        !byte $69,$00,$01,$65,$00,$00,$69,$10,$01,$a9,$74,$01,$ea,$90,$06,$69
        !byte $50,$05,$6a,$40,$01,$69,$40,$01,$6a,$40,$00,$69,$40,$01,$5a,$40
        !byte $06,$56,$50,$06,$96,$d0,$05,$56,$50,$1a,$41,$a4,$15,$51,$55,$00
        !byte $00,$54,$00,$01,$ed,$00,$01,$a9,$00,$00,$a9,$00,$01,$65,$00,$01
        !byte $69,$00,$00,$65,$00,$01,$ea,$40,$01,$a9,$d0,$01,$6a,$40,$01,$a9
        !byte $40,$01,$aa,$40,$07,$6a,$40,$00,$6a,$40,$01,$95,$40,$01,$56,$90
        !byte $06,$56,$50,$05,$91,$b4,$19,$40,$65,$55,$40,$69,$15,$00,$15,$00
        !byte $00,$00,$00,$00,$54,$00,$01,$f5,$00,$00,$a9,$00,$01,$a9,$00,$01
        !byte $69,$00,$01,$65,$00,$00,$69,$00,$01,$a9,$40,$01,$ea,$40,$01,$69
        !byte $40,$01,$6a,$40,$00,$7a,$40,$00,$6a,$40,$00,$69,$40,$00,$19,$90
        !byte $00,$19,$40,$00,$6b,$40,$01,$59,$40,$00,$5a,$40,$00,$15,$50,$00
        !byte $00,$54,$00,$01,$ed,$00,$01,$a9,$00,$00,$a9,$00,$01,$65,$00,$01
        !byte $69,$00,$00,$65,$00,$01,$ea,$50,$01,$a9,$74,$06,$69,$90,$06,$69
        !byte $40,$05,$6a,$40,$1d,$6a,$40,$04,$65,$40,$00,$65,$00,$00,$5a,$40
        !byte $01,$56,$50,$05,$d1,$a4,$19,$40,$65,$55,$40,$69,$15,$00,$15,$00
        !byte $00,$00,$00,$00,$54,$00,$01,$f5,$00,$00,$a9,$00,$01,$a9,$00,$01
        !byte $69,$00,$01,$65,$00,$00,$69,$00,$01,$a9,$40,$01,$ea,$40,$01,$69
        !byte $40,$01,$6b,$40,$00,$6a,$40,$00,$6a,$40,$01,$69,$40,$00,$69,$d0
        !byte $00,$69,$40,$00,$6a,$40,$01,$55,$40,$00,$5a,$40,$00,$15,$50,$00
        !byte $00,$54,$00,$01,$ed,$00,$01,$a9,$00,$04,$a9,$10,$1d,$65,$74,$05
        !byte $69,$d0,$05,$65,$50,$01,$ea,$40,$01,$a9,$40,$01,$6a,$40,$01,$69
        !byte $40,$01,$6a,$40,$01,$6a,$40,$00,$5a,$40,$01,$96,$50,$01,$a5,$b4
        !byte $01,$55,$54,$06,$96,$90,$15,$55,$54,$05,$41,$50,$00,$00,$00,$00
        !byte $00,$54,$00,$01,$ed,$00,$00,$a9,$00,$01,$a9,$00,$01,$65,$00,$01
        !byte $69,$00,$00,$65,$00,$15,$ea,$54,$76,$a9,$6d,$15,$6a,$54,$01,$69
        !byte $40,$01,$6a,$40,$00,$6a,$40,$00,$6a,$40,$01,$65,$40,$06,$96,$90
        !byte $06,$56,$d0,$05,$96,$90,$19,$46,$50,$15,$51,$a4,$05,$41,$55,$00
        !byte $01,$50,$00,$07,$e4,$00,$02,$a4,$00,$06,$a4,$00,$05,$94,$00,$05
        !byte $a4,$00,$01,$94,$00,$06,$ad,$40,$06,$b5,$d0,$05,$aa,$40,$01,$69
        !byte $40,$01,$6a,$40,$00,$6a,$40,$00,$6a,$40,$01,$95,$40,$01,$56,$90
        !byte $06,$56,$50,$05,$91,$b4,$19,$41,$94,$1a,$40,$69,$55,$40,$55,$00
        !byte $00,$15,$00,$00,$7e,$40,$00,$2a,$40,$00,$6a,$40,$00,$59,$41,$00
        !byte $5a,$57,$00,$19,$75,$00,$6a,$d4,$01,$6a,$50,$05,$59,$90,$01,$69
        !byte $40,$01,$6a,$40,$00,$6a,$40,$00,$6a,$40,$01,$95,$40,$01,$56,$90
        !byte $06,$56,$50,$05,$91,$b4,$19,$40,$65,$1a,$40,$69,$55,$40,$15,$00
        !byte $00,$00,$00,$01,$50,$00,$07,$94,$00,$02,$a4,$00,$06,$a4,$00,$05
        !byte $a4,$00,$05,$94,$00,$01,$a4,$40,$16,$a5,$d0,$77,$a5,$40,$15,$a5
        !byte $50,$05,$6a,$b4,$01,$6a,$94,$00,$6a,$a4,$00,$56,$94,$01,$a5,$55
        !byte $01,$94,$54,$01,$a4,$00,$01,$54,$00,$06,$90,$00,$05,$54,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$05,$40,$00,$1e,$d0,$00,$0a,$90,$01,$1e
        !byte $90,$05,$16,$50,$19,$56,$90,$15,$d6,$50,$65,$5a,$a4,$59,$1a,$95
        !byte $54,$19,$a9,$90,$75,$a9,$40,$11,$a9,$40,$01,$65,$00,$06,$94,$00
        !byte $06,$50,$00,$06,$90,$00,$06,$50,$00,$06,$90,$00,$05,$54,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$54,$00,$01,$f5,$00,$00
        !byte $a9,$40,$01,$ab,$d0,$01,$6a,$90,$01,$6a,$50,$00,$79,$90,$01,$a9
        !byte $40,$01,$aa,$40,$01,$69,$40,$01,$6a,$40,$01,$69,$40,$00,$6a,$40
        !byte $00,$65,$40,$05,$95,$90,$19,$41,$b4,$1a,$41,$a5,$55,$40,$55,$00
        !byte $01,$50,$00,$07,$e4,$00,$02,$a4,$00,$06,$a4,$00,$05,$94,$00,$05
        !byte $a4,$00,$1d,$94,$00,$06,$ad,$00,$06,$a5,$00,$05,$ab,$40,$01,$69
        !byte $40,$01,$6a,$40,$00,$6a,$40,$00,$6a,$40,$01,$a9,$40,$01,$5a,$40
        !byte $06,$56,$50,$06,$96,$d0,$05,$56,$50,$1a,$41,$a4,$15,$51,$55,$00
        !byte $00,$15,$00,$00,$7e,$40,$00,$2a,$40,$00,$6a,$40,$00,$59,$40,$00
        !byte $5a,$55,$00,$19,$77,$00,$6a,$d5,$01,$6a,$50,$05,$59,$90,$1d,$69
        !byte $40,$05,$6a,$40,$00,$6a,$40,$00,$6a,$40,$01,$95,$40,$01,$56,$90
        !byte $06,$56,$50,$05,$91,$b4,$19,$40,$65,$1a,$40,$69,$55,$40,$15,$00
        !byte $00,$00,$00,$05,$40,$00,$1f,$51,$00,$1a,$97,$40,$0a,$95,$00,$16
        !byte $9d,$00,$16,$94,$00,$06,$a4,$00,$16,$94,$00,$67,$a9,$00,$55,$a5
        !byte $00,$d5,$a9,$00,$45,$a5,$00,$01,$6a,$40,$00,$69,$40,$01,$9a,$40
        !byte $01,$96,$50,$01,$55,$d0,$06,$51,$94,$06,$91,$a5,$15,$50,$55,$00
        !byte $00,$00,$00,$00,$00,$00,$02,$a8,$00,$08,$3c,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$a8,$00,$02,$3c,$00,$08
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$00,$02,$00,$00,$08,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$a8,$00,$02,$3c,$00,$08,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$00,$02,$00,$00,$08,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$a8,$00,$08,$3c,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$a8,$00,$02,$3c,$00,$08,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$00,$02,$00,$00,$08,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$a8,$00,$08,$3c,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$a8,$00,$02,$3c,$00,$08,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$00,$02,$00,$00,$08,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$02,$a8,$00,$08,$3c,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$0a,$a0,$00,$20,$f0,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$aa,$00,$02,$0f,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$a0,$00,$20,$f0,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2a,$80,$00,$83
        !byte $c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$0a,$a8,$00,$28,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
        !byte $a8,$00,$08,$3c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$aa,$00
        !byte $0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$0a,$a0,$00,$20,$f0,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$aa,$00,$02,$0f,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$02,$aa,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$80,$00,$23,$c0,$00,$80
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$00,$02,$00,$00,$08,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$15,$00,$00,$7b,$40,$00,$6a,$00,$00,$6a,$40,$00,$59,$40,$00
        !byte $69,$40,$04,$59,$00,$1d,$ab,$40,$05,$aa,$40,$06,$69,$90,$01,$69
        !byte $90,$01,$a9,$40,$01,$a9,$00,$01,$a9,$00,$01,$6a,$40,$01,$a5,$40
        !byte $05,$95,$90,$07,$96,$90,$05,$95,$50,$1a,$41,$a4,$55,$45,$54,$00
        !byte $00,$00,$00,$00,$15,$00,$00,$5f,$40,$00,$6a,$40,$00,$6a,$00,$00
        !byte $69,$40,$00,$59,$40,$04,$69,$00,$1d,$6a,$40,$06,$ab,$40,$05,$69
        !byte $90,$01,$a9,$50,$01,$69,$40,$01,$a9,$40,$01,$69,$00,$01,$a5,$40
        !byte $05,$95,$90,$07,$96,$90,$05,$95,$50,$1a,$41,$a4,$55,$45,$54,$00
        !byte $00,$15,$00,$00,$7b,$40,$00,$6a,$40,$00,$6a,$00,$00,$59,$40,$00
        !byte $69,$40,$00,$59,$00,$01,$ab,$40,$07,$6a,$40,$01,$a9,$40,$01,$6a
        !byte $40,$01,$aa,$40,$01,$a9,$d0,$01,$a9,$00,$01,$56,$40,$06,$95,$40
        !byte $05,$95,$90,$1e,$46,$50,$59,$01,$64,$69,$01,$55,$54,$00,$54,$00
        !byte $00,$00,$00,$00,$15,$00,$00,$5f,$40,$00,$6a,$00,$00,$6a,$40,$00
        !byte $69,$40,$00,$59,$40,$00,$69,$00,$01,$6a,$40,$01,$ab,$40,$01,$69
        !byte $40,$01,$a9,$40,$01,$ad,$00,$01,$a9,$00,$01,$69,$00,$06,$64,$00
        !byte $01,$64,$00,$01,$e9,$00,$01,$65,$40,$01,$a5,$00,$05,$54,$00,$00
        !byte $00,$15,$00,$00,$7b,$40,$00,$6a,$40,$00,$6a,$00,$00,$59,$40,$00
        !byte $69,$40,$00,$59,$00,$05,$ab,$40,$1d,$6a,$40,$06,$69,$90,$01,$69
        !byte $90,$01,$a9,$50,$01,$a9,$74,$01,$59,$10,$00,$59,$00,$01,$a5,$00
        !byte $05,$95,$40,$1a,$47,$50,$59,$01,$64,$69,$01,$55,$54,$00,$54,$00
        !byte $00,$00,$00,$00,$15,$00,$00,$5f,$40,$00,$6a,$00,$00,$6a,$40,$00
        !byte $69,$40,$00,$59,$40,$00,$69,$00,$01,$6a,$40,$01,$ab,$40,$01,$69
        !byte $40,$01,$e9,$40,$01,$a9,$00,$01,$a9,$00,$01,$69,$40,$07,$69,$00
        !byte $01,$69,$00,$01,$a9,$00,$01,$55,$40,$01,$a5,$00,$05,$54,$00,$00
        !byte $00,$15,$00,$00,$7b,$40,$00,$6a,$40,$04,$6a,$10,$1d,$59,$74,$07
        !byte $69,$50,$05,$59,$50,$01,$ab,$40,$01,$6a,$40,$01,$a9,$40,$01,$69
        !byte $40,$01,$a9,$40,$01,$a9,$40,$01,$a5,$00,$05,$96,$40,$1e,$5a,$40
        !byte $15,$55,$40,$06,$96,$90,$15,$55,$54,$05,$41,$50,$00,$00,$00,$00
        !byte $00,$15,$00,$00,$7b,$40,$00,$6a,$00,$00,$6a,$40,$00,$59,$40,$00
        !byte $69,$40,$00,$59,$00,$15,$ab,$54,$79,$6a,$9d,$15,$a9,$54,$01,$69
        !byte $40,$01,$a9,$40,$01,$a9,$00,$01,$a9,$00,$01,$59,$40,$06,$96,$90
        !byte $07,$95,$90,$06,$96,$50,$05,$91,$64,$1a,$45,$54,$55,$41,$50,$00
        !byte $00,$05,$40,$00,$1b,$d0,$00,$1a,$80,$00,$1a,$90,$00,$16,$50,$00
        !byte $1a,$50,$00,$16,$40,$01,$7a,$90,$07,$5e,$90,$01,$aa,$50,$01,$69
        !byte $40,$01,$a9,$40,$01,$a9,$00,$01,$a9,$00,$01,$56,$40,$06,$95,$40
        !byte $05,$95,$90,$1e,$46,$50,$16,$41,$64,$69,$01,$a4,$55,$01,$55,$00
        !byte $00,$54,$00,$01,$bd,$00,$01,$a8,$00,$01,$a9,$00,$41,$65,$00,$d5
        !byte $a5,$00,$5d,$64,$00,$17,$a9,$00,$05,$a9,$40,$06,$65,$50,$01,$69
        !byte $40,$01,$a9,$40,$01,$a9,$00,$01,$a9,$00,$01,$56,$40,$06,$95,$40
        !byte $05,$95,$90,$1e,$46,$50,$59,$01,$64,$69,$01,$a4,$54,$01,$55,$00
        !byte $00,$00,$00,$00,$05,$40,$00,$16,$d0,$00,$1a,$80,$00,$1a,$90,$00
        !byte $1a,$50,$00,$16,$50,$01,$1a,$40,$07,$5a,$94,$01,$5a,$dd,$05,$5a
        !byte $54,$1e,$a9,$50,$16,$a9,$40,$1a,$a9,$00,$16,$95,$00,$55,$5a,$40
        !byte $15,$16,$40,$00,$1a,$40,$00,$15,$40,$00,$06,$90,$00,$15,$50,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$01,$50,$00,$07,$b4,$40,$06,$a0,$50
        !byte $06,$b4,$64,$05,$94,$54,$06,$95,$59,$05,$97,$65,$1a,$a5,$15,$56
        !byte $a4,$06,$6a,$64,$01,$6a,$5d,$01,$6a,$44,$00,$59,$40,$00,$16,$90
        !byte $00,$05,$90,$00,$06,$90,$00,$05,$90,$00,$06,$90,$00,$15,$50,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$15,$00,$00,$5f,$40,$01
        !byte $6a,$00,$07,$ea,$40,$06,$a9,$40,$05,$a9,$40,$06,$6d,$00,$01,$6a
        !byte $40,$01,$aa,$40,$01,$69,$40,$01,$a9,$40,$01,$69,$40,$01,$a9,$00
        !byte $01,$59,$00,$06,$56,$50,$1e,$41,$64,$5a,$41,$a4,$55,$01,$55,$00
        !byte $00,$05,$40,$00,$1b,$d0,$00,$1a,$80,$00,$1a,$90,$00,$16,$50,$00
        !byte $1a,$50,$00,$16,$74,$00,$7a,$90,$00,$5a,$90,$01,$ea,$50,$01,$69
        !byte $40,$01,$a9,$40,$01,$a9,$00,$01,$a9,$00,$01,$6a,$40,$01,$a5,$40
        !byte $05,$95,$90,$07,$96,$90,$05,$95,$50,$1a,$41,$a4,$55,$45,$54,$00
        !byte $00,$54,$00,$01,$bd,$00,$01,$a8,$00,$01,$a9,$00,$01,$65,$00,$55
        !byte $a5,$00,$dd,$64,$00,$57,$a9,$00,$05,$a9,$40,$06,$65,$50,$01,$69
        !byte $74,$01,$a9,$50,$01,$a9,$00,$01,$a9,$00,$01,$56,$40,$06,$95,$40
        !byte $05,$95,$90,$1e,$46,$50,$59,$01,$64,$69,$01,$a4,$54,$01,$55,$00
        !byte $00,$00,$00,$00,$01,$50,$00,$45,$f4,$01,$d6,$a4,$00,$56,$a0,$00
        !byte $76,$94,$00,$16,$94,$00,$1a,$90,$00,$16,$94,$00,$6a,$d9,$00,$5a
        !byte $55,$00,$6a,$57,$00,$5a,$51,$01,$a9,$40,$01,$69,$00,$01,$a6,$40
        !byte $05,$96,$40,$07,$55,$40,$16,$45,$90,$5a,$46,$90,$55,$05,$54,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$2a,$80,$00,$3c,$20,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2a,$00,$00,$3c,$80,$00
        !byte $00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$00,$00,$00,$80,$00,$00,$20
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$2a,$00,$00,$3c,$80,$00,$00,$20,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$00,$00,$00,$80,$00,$00,$20,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2a,$80,$00,$3c,$20,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$2a,$00,$00,$3c,$80,$00,$00,$20,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$00,$00,$00,$80,$00,$00,$20,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$2a,$80,$00,$3c,$20,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$2a,$00,$00,$3c,$80,$00,$00,$20,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$00,$00,$00,$80,$00,$00,$20,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$2a,$80,$00,$3c,$20,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$0a,$a0,$00,$0f,$08,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$aa,$00,$00,$f0,$80,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$a0,$00,$0f,$08,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$a8,$00
        !byte $03,$c2,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$2a,$a0,$00,$00,$28,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $2a,$80,$00,$3c,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$aa,$80
        !byte $00,$00,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$0a,$a0,$00,$0f,$08,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$aa,$00,$00,$f0,$80,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$aa,$80,$00,$00,$a0,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$a0,$00,$03,$c8,$00
        !byte $00,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$aa,$00,$00,$00,$80,$00,$00,$20
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$74,$00,$01,$ed,$00,$07,$a9,$50,$05,$55,$74,$01,$a9,$74,$01
        !byte $e9,$74,$01,$65,$74,$05,$e9,$f4,$06,$a9,$74,$05,$a5,$94,$05,$a9
        !byte $50,$05,$a6,$40,$05,$aa,$40,$01,$aa,$40,$01,$95,$40,$01,$56,$90
        !byte $06,$56,$50,$05,$91,$b4,$19,$40,$65,$55,$51,$69,$15,$55,$55,$00
        !byte $00,$10,$00,$00,$74,$00,$01,$a5,$10,$06,$aa,$74,$05,$55,$74,$01
        !byte $e9,$74,$01,$69,$74,$01,$69,$74,$05,$aa,$f4,$07,$a9,$94,$05,$a5
        !byte $50,$05,$aa,$40,$05,$aa,$40,$01,$aa,$40,$01,$69,$40,$00,$19,$90
        !byte $00,$19,$40,$00,$6b,$40,$01,$59,$40,$01,$5a,$40,$15,$55,$54,$00
        !byte $00,$74,$00,$01,$ed,$00,$07,$a9,$50,$05,$55,$74,$01,$a9,$74,$01
        !byte $e9,$74,$01,$65,$74,$05,$e9,$f4,$06,$a9,$74,$05,$a5,$94,$05,$a9
        !byte $50,$05,$a6,$40,$05,$aa,$40,$01,$a5,$40,$01,$65,$00,$00,$5a,$40
        !byte $01,$56,$50,$05,$d1,$a4,$19,$40,$65,$55,$51,$69,$15,$55,$55,$00
        !byte $00,$10,$00,$00,$74,$00,$01,$a5,$10,$06,$aa,$74,$05,$55,$74,$01
        !byte $e9,$74,$01,$69,$74,$01,$69,$74,$05,$aa,$f4,$07,$a9,$94,$05,$a5
        !byte $50,$05,$aa,$40,$05,$aa,$40,$01,$aa,$40,$01,$69,$40,$00,$69,$d0
        !byte $00,$69,$40,$00,$6a,$40,$01,$55,$40,$01,$5a,$40,$15,$55,$54,$00
        !byte $00,$74,$00,$01,$ed,$00,$07,$ab,$40,$05,$55,$50,$01,$a9,$40,$01
        !byte $e9,$40,$01,$65,$40,$05,$e9,$d0,$06,$a9,$40,$05,$a6,$40,$05,$a9
        !byte $40,$05,$a6,$40,$05,$aa,$40,$01,$aa,$40,$01,$a9,$40,$01,$5a,$40
        !byte $06,$56,$50,$06,$96,$d0,$05,$56,$50,$1a,$51,$a4,$15,$55,$55,$00
        !byte $00,$1d,$00,$00,$6a,$40,$01,$aa,$50,$01,$55,$50,$00,$6a,$40,$00
        !byte $5a,$40,$00,$59,$50,$01,$6a,$74,$01,$aa,$55,$01,$69,$9f,$05,$a9
        !byte $55,$05,$a9,$40,$05,$aa,$40,$01,$aa,$40,$01,$95,$40,$01,$56,$90
        !byte $06,$56,$50,$05,$91,$b4,$19,$40,$65,$1a,$51,$69,$55,$55,$55,$00
        !byte $01,$00,$00,$07,$40,$00,$1a,$51,$00,$6a,$a6,$40,$55,$55,$00,$1e
        !byte $9d,$00,$16,$94,$00,$16,$a4,$00,$5a,$ad,$00,$7a,$a9,$00,$66,$65
        !byte $00,$96,$a9,$00,$56,$65,$00,$05,$aa,$40,$01,$a9,$40,$01,$9a,$40
        !byte $01,$96,$50,$01,$55,$d0,$06,$51,$94,$06,$91,$a5,$15,$55,$55,$00
        !byte $00,$1d,$00,$00,$7b,$40,$05,$6a,$d0,$1d,$55,$50,$1d,$6a,$40,$1d
        !byte $6b,$40,$1d,$59,$40,$1f,$6b,$50,$1d,$6a,$90,$16,$5a,$50,$05,$6a
        !byte $50,$01,$9a,$50,$01,$aa,$50,$01,$aa,$40,$01,$56,$40,$06,$95,$40
        !byte $05,$95,$90,$1e,$46,$50,$59,$01,$64,$69,$45,$55,$55,$55,$54,$00
        !byte $00,$04,$00,$00,$1d,$00,$04,$5a,$40,$1d,$aa,$90,$1d,$55,$50,$1d
        !byte $6b,$40,$1d,$69,$40,$1d,$69,$40,$1f,$aa,$50,$16,$6a,$d0,$05,$5a
        !byte $50,$01,$aa,$50,$01,$aa,$50,$01,$aa,$40,$01,$69,$40,$06,$64,$00
        !byte $01,$64,$00,$01,$e9,$00,$01,$65,$40,$01,$a5,$40,$15,$55,$54,$00
        !byte $00,$1d,$00,$00,$7b,$40,$05,$6a,$d0,$1d,$55,$50,$1d,$6a,$40,$1d
        !byte $6b,$40,$1d,$59,$40,$1f,$6b,$50,$1d,$6a,$90,$16,$5a,$50,$05,$6a
        !byte $50,$01,$9a,$50,$01,$aa,$50,$01,$5a,$40,$00,$59,$40,$01,$a5,$00
        !byte $05,$95,$40,$1a,$47,$50,$59,$01,$64,$69,$45,$55,$55,$55,$54,$00
        !byte $00,$04,$00,$00,$1d,$00,$04,$5a,$40,$1d,$aa,$90,$1d,$55,$50,$1d
        !byte $6b,$40,$1d,$69,$40,$1d,$69,$40,$1f,$aa,$50,$16,$6a,$d0,$05,$5a
        !byte $50,$01,$aa,$50,$01,$aa,$50,$01,$aa,$40,$01,$69,$40,$07,$69,$00
        !byte $01,$69,$00,$01,$a9,$00,$01,$55,$40,$01,$a5,$40,$15,$55,$54,$00
        !byte $00,$1d,$00,$00,$7b,$40,$01,$ea,$d0,$05,$55,$50,$01,$6a,$40,$01
        !byte $6b,$40,$01,$59,$40,$07,$6b,$50,$01,$6a,$90,$01,$9a,$50,$01,$6a
        !byte $50,$01,$9a,$50,$01,$aa,$50,$01,$aa,$40,$01,$6a,$40,$01,$a5,$40
        !byte $05,$95,$90,$07,$96,$90,$05,$95,$50,$1a,$45,$a4,$55,$55,$54,$00
        !byte $00,$74,$00,$01,$a9,$00,$05,$aa,$40,$05,$55,$40,$01,$a9,$00,$01
        !byte $a5,$00,$05,$65,$00,$1d,$a9,$40,$55,$aa,$40,$f6,$69,$40,$55,$6a
        !byte $50,$01,$6a,$50,$01,$aa,$50,$01,$aa,$40,$01,$56,$40,$06,$95,$40
        !byte $05,$95,$90,$1e,$46,$50,$59,$01,$64,$69,$45,$a4,$55,$55,$55,$00
        !byte $00,$00,$40,$00,$01,$d0,$00,$45,$a4,$01,$9a,$a9,$00,$55,$55,$00
        !byte $76,$b4,$00,$16,$94,$00,$1a,$94,$00,$7a,$a5,$00,$6a,$ad,$00,$59
        !byte $99,$00,$6a,$96,$00,$59,$95,$01,$aa,$50,$01,$6a,$40,$01,$a6,$40
        !byte $05,$96,$40,$07,$55,$40,$16,$45,$90,$5a,$46,$90,$55,$55,$54,$00
        !byte $00,$00,$00,$00,$18,$00,$00,$18,$00,$00,$18,$00,$00,$18,$00,$00
        !byte $18,$00,$00,$18,$00,$00,$3c,$00,$00,$3c,$00,$07,$e7,$e0,$3f,$e7
        !byte $fc,$07,$e7,$e0,$00,$3c,$00,$00,$3c,$00,$00,$18,$00,$00,$18,$00
        !byte $00,$18,$00,$00,$18,$00,$00,$18,$00,$00,$18,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$00,$60,$03
        !byte $81,$c0,$03,$c3,$c0,$01,$ff,$80,$00,$ff,$00,$00,$66,$00,$00,$66
        !byte $00,$00,$66,$00,$00,$ff,$00,$01,$ff,$80,$03,$c3,$c0,$03,$81,$c0
        !byte $06,$00,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$04,$00,$00
        !byte $04,$00,$00,$08,$00,$00,$68,$00,$10,$2b,$00,$0f,$de,$00,$00,$7e
        !byte $00,$00,$7b,$f0,$00,$d4,$08,$00,$16,$00,$00,$10,$00,$00,$20,$00
        !byte $00,$20,$00,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $10,$00,$00,$18,$00,$00,$08,$00,$00,$6e,$00,$00,$3c,$00,$03,$ff
        !byte $c0,$00,$3c,$00,$00,$6e,$00,$00,$08,$00,$00,$08,$00,$00,$08,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$7e,$00,$03,$ff,$c0,$07,$ff,$e0,$0f,$ff,$f0,$1f,$ff,$f8,$3f
        !byte $ff,$fc,$3f,$ff,$fc,$7f,$ff,$fe,$7f,$ff,$fe,$7f,$ff,$fe,$7f,$ff
        !byte $fe,$7f,$ff,$fe,$7f,$ff,$fe,$7f,$ff,$fe,$3f,$ff,$fc,$3f,$ff,$fc
        !byte $1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$03,$ff,$c0,$00,$7e,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$00,$03,$c3,$c0,$07
        !byte $e1,$c0,$03,$e3,$c0,$07,$e1,$00,$03,$c3,$82,$05,$07,$c0,$0c,$0f
        !byte $e2,$1e,$5f,$e0,$0c,$cf,$ea,$05,$e7,$c4,$03,$fb,$88,$01,$f9,$04
        !byte $00,$fc,$28,$00,$58,$10,$00,$0a,$a0,$00,$00,$40,$00,$2a,$00,$00
        !byte $0f,$ff,$f0,$3f,$ff,$fc,$7f,$ff,$fe,$7f,$ff,$fe,$3f,$ff,$fc,$0f
        !byte $ff,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
patrows:
        !byte $b3,$20,$20,$20,$20,$20,$20,$20,$20,$b3,$20,$20,$20,$20,$20,$20,$99,$20,$20,$a8,$20,$20,$20,$20,$20,$83,$b2,$20,$20,$20,$20,$20
        !byte $20,$20,$62,$20,$f7,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$62,$62,$20,$20,$20,$20,$62,$f8,$20,$20,$20,$20,$20,$20,$20,$82,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$83,$20,$20,$20,$83,$20,$20,$20,$20,$20,$20,$20,$82,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$9a,$20,$20,$20,$20,$20,$d9,$20,$20,$a9,$62,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$20,$c9,$62,$20,$20,$20
        !byte $b3,$20,$20,$20,$20,$20,$20,$20,$20,$b3,$20,$20,$20,$20,$20,$20,$99,$20,$20,$a8,$20,$20,$20,$20,$20,$83,$b2,$20,$20,$20,$20,$20
        !byte $20,$20,$62,$20,$f7,$62,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$b2,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$53,$c8,$20,$20,$20,$20,$c9,$20,$20,$20,$20
        !byte $20,$62,$c9,$20,$20,$20,$20,$c8,$20,$20,$20,$20,$20,$20,$20,$20,$83,$20,$6f,$20,$20,$20,$20,$20,$20,$20,$f9,$20,$20,$20,$20,$20
        !byte $20,$f9,$20,$20,$20,$a8,$20,$62,$20,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$b2,$99,$20,$20,$20,$20,$20,$20,$20,$20,$20,$fa,$20
        !byte $20,$20,$20,$20,$f7,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$82,$c8,$20,$20,$20,$20,$b3,$62,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$b2,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$53,$c8,$20,$20,$20,$20,$c9,$20,$20,$20,$20
        !byte $20,$62,$c9,$20,$20,$20,$20,$c8
        !byte $20,$62,$fa,$83,$fb,$20,$20,$20,$20,$9a,$62,$20,$20,$20,$20,$20,$20,$9a,$62,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$fa,$20,$20,$20,$20,$20,$a9,$20,$67,$20,$82,$20,$20,$f7,$20,$20,$20,$20,$83,$a9,$20,$d9,$20,$20
        !byte $20,$20,$20,$20,$20,$a8,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$d9,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$a9,$20,$9a,$20,$20,$20,$20
        !byte $20,$62,$fa,$83,$fb,$20,$20,$20,$20,$9a,$62,$20,$20,$20,$20,$20,$20,$9a,$62,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$6f,$4f,$4f,$4f,$4f,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$fc,$4f,$56,$56,$56,$4f,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$6f,$6f,$4f
        !byte $56,$56,$56,$4f,$6f,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$6f,$4f,$4f,$4f,$4f,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20
        !byte $4f,$4f,$4f,$4f,$4f,$4f,$4f,$4f,$6f,$6f,$20,$20,$20,$20,$20,$62,$55,$70,$70,$70,$59,$59,$55,$20,$c8,$99,$55,$55,$55,$55,$55,$aa
        !byte $aa,$aa,$aa,$aa,$55,$99,$99,$83,$8c,$59,$59,$59,$8c,$8c,$f8,$20,$20,$6f,$fc,$4f,$4f,$4f,$4f,$4f,$4f,$4f,$4f,$4f,$a4,$a4,$48,$48
        !byte $48,$48,$48,$48,$48,$48,$a5,$a8,$20,$20,$20,$20,$20,$9a,$db,$fd,$db,$20,$20,$20,$20,$20,$20,$20,$20,$fc,$56,$56,$71,$71,$71,$71
        !byte $56,$4f,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$db,$fd,$db,$a8,$20,$20,$20,$20,$20,$20,$20,$20,$6f,$6f,$4f,$4f,$4f
        !byte $4f,$4f,$4f,$4f,$4f,$4f,$4f,$4f,$6f,$6f,$20,$20,$20,$20,$20,$62,$55,$70,$70,$70,$59,$59,$55,$20,$c8,$99,$55,$55,$55,$55,$55,$aa
        !byte $aa,$aa,$aa,$aa,$55,$99,$99,$83
        !byte $5e,$5e,$4b,$4b,$4b,$4b,$4b,$5e,$5e,$82,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$5e,$5e,$5e,$5e,$5e,$5e,$4b,$4b,$4b,$4b,$5e,$5e,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$5e,$4b,$8c,$8c,$8c,$8c,$4b
        !byte $4b,$5e,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$5e,$5e,$5e
        !byte $5e,$5e,$4b,$4b,$4b,$4b,$4b,$5e,$5e,$82,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$44,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$44,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$dc,$6b,$af
        !byte $64,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$53,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$dd,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$67,$dc,$8d,$57,$85,$ab,$ab,$ab,$57,$84,$64,$86,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$67,$68,$ad,$96,$e2,$66,$9b,$fe,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$68,$ad,$96,$7b,$c5,$9b,$62,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$dc,$64,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$67,$44,$86,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$ac,$ff,$57,$72,$43,$7c
        !byte $9f,$c5,$af,$fe,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$53,$ff,$8d,$57,$57,$84,$8d,$57
        !byte $20,$20,$20,$20,$53,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$57,$dd,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20
        !byte $65,$62,$20,$20,$58,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$7d,$8e,$80,$20,$20,$20,$20,$ac,$6b,$85,$de,$7a,$86,$20
        !byte $20,$20,$20,$20,$20,$67,$68,$49,$87,$45,$45,$49,$dd,$86,$20,$20,$20,$20,$20,$20,$20,$20,$20,$68,$9d,$80,$20,$67,$68,$fe,$20,$20
        !byte $20,$20,$20,$20,$20,$67,$68,$87,$96,$ca,$43,$43,$43,$43,$43,$43,$43,$7c,$6e,$df,$4e,$65,$86,$20,$20,$20,$20,$20,$20,$20,$67,$68
        !byte $85,$96,$43,$43,$43,$43,$43,$7d,$61,$a6,$9d,$64,$20,$20,$20,$20,$20,$20,$20,$ac,$6b,$9e,$ca,$43,$43,$43,$43,$e0,$ae,$8e,$dd,$86
        !byte $20,$20,$20,$20,$20,$20,$ac,$ad,$66,$7a,$fe,$20,$20,$20,$20,$20,$20,$ac,$68,$9e,$ca,$7d,$a6,$9d,$80,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$67,$dc,$68,$ff,$85,$e2,$72,$61,$52,$4e,$84,$64,$67,$20,$20,$20,$20,$20,$20,$20,$20,$20,$ac,$6b,$85,$cb,$43,$43,$43,$43,$43
        !byte $43,$9c,$e0,$9f,$4e,$65,$86,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$6b,$ab,$8e,$86,$20,$ac,$8d,$65,$86,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$6b,$4d,$4e,$dd,$20,$67,$ff,$84,$64,$20,$20,$20,$20,$20,$20,$20,$20,$44,$dc,$58,$43,$43,$43,$43,$43,$43,$9c
        !byte $65,$62,$20,$20,$58,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$7d,$8e,$80,$20,$20,$20,$20,$ac,$6b,$85,$de,$7a,$86,$20
        !byte $20,$20,$20,$20,$20,$67,$68,$49
        !byte $e0,$ae,$7a,$80,$58,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$7c,$ae,$7a,$44,$68,$85,$cb,$43,$43,$43,$e0,$7b,$4e
        !byte $65,$86,$44,$68,$87,$96,$43,$43,$43,$43,$43,$43,$43,$7b,$4e,$65,$44,$dc,$6b,$85,$de,$7a,$ad,$ca,$7c,$9f,$9b,$9e,$6e,$9f,$8e,$68
        !byte $af,$80,$ac,$68,$87,$96,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$7d,$7b,$4e,$65,$fe,$20,$68,$ff,$9e,$e2,$43
        !byte $43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$7c,$7d,$ae,$4e,$dd,$44,$dc,$8d,$85,$cb,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$7d,$df
        !byte $9d,$dd,$86,$dc,$6b,$9e,$cb,$43,$43,$e0,$b0,$4e,$af,$44,$ac,$6b,$85,$cb,$43,$43,$43,$43,$43,$7c,$61,$66,$9b,$44,$44,$dc,$68,$ad
        !byte $85,$96,$7d,$43,$43,$43,$43,$43,$43,$43,$43,$7c,$7d,$7b,$df,$c5,$57,$65,$64,$62,$ac,$6b,$85,$cb,$43,$43,$43,$43,$43,$43,$43,$43
        !byte $43,$43,$43,$43,$9c,$6e,$7b,$e1,$9b,$fe,$dc,$6b,$4d,$e2,$66,$9b,$9e,$43,$43,$7c,$66,$6b,$96,$43,$6e,$ae,$7a,$68,$84,$64,$68,$49
        !byte $4d,$e2,$66,$9b,$87,$ca,$43,$9c,$9f,$9b,$9e,$43,$7c,$7d,$e1,$dd,$8d,$af,$80,$dc,$ad,$96,$72,$43,$43,$43,$43,$43,$43,$43,$43,$43
        !byte $e0,$ae,$7a,$80,$58,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$7c,$ae,$7a,$44,$68,$85,$cb,$43,$43,$43,$e0,$7b,$4e
        !byte $65,$86,$44,$68,$87,$96,$43,$43
        !byte $43,$43,$6e,$7d,$ca,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$e0,$72,$43,$43,$43,$43,$43,$43,$43,$43,$9c
        !byte $6e,$7b,$72,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$6e,$b1,$ca,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$7c,$43
        !byte $43,$61,$cb,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$6e,$b0,$e2,$ca,$43,$43,$43,$43
        !byte $43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$cc,$b1,$ca,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43
        !byte $9c,$7d,$e2,$ca,$43,$43,$43,$43,$43,$43,$43,$9c,$e0,$b1,$cb,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$6e,$b1,$72,$43,$43,$43
        !byte $43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$7d,$e2,$cb,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43
        !byte $43,$43,$43,$43,$43,$43,$43,$43,$6e,$b0,$43,$43,$43,$43,$43,$cc,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$e0,$43,$7c,$43,$43,$43
        !byte $43,$43,$43,$cc,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$9c,$cc,$43,$43,$61,$ca,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43
        !byte $43,$43,$6e,$7d,$ca,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$e0,$72,$43,$43,$43,$43,$43,$43,$43,$43,$9c
        !byte $6e,$7b,$72,$43,$43,$43,$43,$43
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$53,$54,$54,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$8f,$20,$20,$20,$20,$20,$20,$20,$20,$5a,$20,$20,$20,$20,$20,$b2,$20,$5a,$20
        !byte $20,$20,$5a,$20,$8f,$20,$20,$20,$20,$20,$20,$b3,$20,$20,$62,$20,$20,$20,$20,$53,$20,$20,$20,$20,$20,$20,$20,$b2,$20,$20,$20,$cd
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$b3,$20,$20,$53,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$b2,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$b3,$20,$5a,$20,$20,$20,$b3,$20,$20,$8f,$20,$20,$20,$20,$20,$62,$44,$44,$44,$44,$62,$20,$53,$44
        !byte $44,$44,$44,$44,$62,$44,$44,$44,$44,$44,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$b3,$20,$20,$20,$88,$20,$20
        !byte $20,$62,$44,$44,$44,$44,$62,$53,$44,$44,$44,$44,$44,$62,$20,$20,$20,$20,$b2,$20,$20,$20,$cd,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$8f,$20,$20,$20,$20,$20,$20,$20,$20,$20,$53,$20,$81,$d0,$81,$62,$20,$20,$20,$20,$20,$20,$20,$20,$5a,$20,$20,$20,$53,$20,$20
        !byte $20,$b3,$62,$44,$44,$44,$44,$44,$62,$20,$20,$c9,$81,$45,$81,$62,$20,$20,$20,$20,$a9,$81,$75,$62,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$8f,$20,$20,$20,$20,$20,$20,$20,$20,$5a,$20,$20,$20,$20,$20,$b2,$20,$5a,$20
        !byte $20,$20,$5a,$20,$8f,$20,$20,$20
        !byte $44,$44,$44,$a0,$44,$44,$6d,$6d,$b3,$20,$20,$20,$73,$69,$74,$a8,$20,$20,$20,$20,$20,$53,$7e,$88,$20,$b4,$d2,$53,$7e,$88,$90,$62
        !byte $20,$53,$7e,$73,$69,$74,$a8,$20,$20,$20,$b4,$75,$20,$53,$b5,$20,$20,$a0,$62,$ce,$5f,$e3,$20,$20,$20,$20,$53,$7e,$88,$9a,$cf,$52
        !byte $74,$20,$20,$20,$20,$20,$53,$6d,$6d,$86,$20,$20,$20,$20,$20,$98,$b5,$20,$20,$b4,$75,$20,$ac,$6d,$6d,$b3,$20,$20,$20,$20,$90,$62
        !byte $53,$6d,$6d,$6d,$67,$44,$44,$98,$b5,$44,$90,$62,$20,$b4,$75,$20,$73,$69,$74,$a8,$20,$20,$20,$83,$91,$46,$46,$51,$20,$20,$20,$63
        !byte $46,$46,$46,$92,$82,$5e,$46,$46,$46,$91,$5e,$20,$20,$53,$ef,$62,$cd,$53,$6d,$6d,$b3,$20,$20,$20,$b4,$75,$20,$20,$b4,$d7,$62,$20
        !byte $53,$a0,$91,$46,$46,$91,$5e,$20,$63,$46,$46,$46,$92,$82,$20,$20,$20,$44,$7e,$8a,$8a,$cf,$52,$e4,$ea,$44,$20,$20,$20,$20,$b6,$88
        !byte $73,$69,$74,$a8,$20,$20,$20,$b6,$88,$20,$20,$58,$88,$cf,$69,$5f,$e3,$20,$20,$20,$20,$20,$20,$20,$53,$7e,$88,$20,$20,$58,$88,$20
        !byte $b4,$75,$83,$91,$46,$46,$46,$51,$20,$20,$20,$67,$ce,$69,$5f,$e3,$20,$20,$20,$20,$d9,$ce,$5f,$62,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $44,$44,$44,$a0,$44,$44,$6d,$6d,$b3,$20,$20,$20,$73,$69,$74,$a8,$20,$20,$20,$20,$20,$53,$7e,$88,$20,$b4,$d2,$53,$7e,$88,$90,$62
        !byte $20,$53,$7e,$73,$69,$74,$a8,$20
        !byte $ca,$43,$43,$43,$43,$43,$43,$43,$52,$4d,$45,$45,$a1,$43,$89,$49,$49,$45,$45,$45,$45,$e5,$43,$ba,$52,$b7,$43,$52,$43,$43,$43,$45
        !byte $45,$e5,$e6,$e6,$43,$a1,$45,$45,$45,$45,$d0,$ba,$49,$49,$e8,$54,$8a,$e7,$97,$be,$c2,$5e,$20,$20,$67,$44,$8a,$e8,$49,$45,$a1,$43
        !byte $43,$4d,$4d,$4d,$4d,$4d,$4d,$43,$43,$ba,$45,$45,$45,$4d,$4d,$b7,$43,$52,$52,$b7,$d7,$4d,$b7,$43,$43,$45,$45,$45,$45,$45,$e6,$45
        !byte $b8,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$72,$52,$b7,$d7,$45,$a1,$43,$a1,$45,$49,$49,$49,$49,$49,$49,$49,$49,$54,$54,$8a,$8a
        !byte $44,$44,$44,$44,$44,$44,$51,$8a,$54,$a0,$45,$45,$45,$9e,$43,$4d,$4d,$4d,$43,$43,$45,$45,$49,$49,$54,$b9,$54,$54,$49,$43,$45,$45
        !byte $e5,$e6,$ba,$45,$45,$45,$45,$45,$45,$45,$45,$45,$4d,$4d,$52,$52,$72,$43,$43,$43,$43,$43,$43,$43,$43,$43,$72,$52,$4d,$45,$d0,$e6
        !byte $89,$43,$89,$49,$49,$49,$49,$d0,$ba,$45,$45,$d0,$ba,$89,$43,$89,$49,$54,$54,$54,$54,$49,$49,$45,$e5,$e6,$ba,$45,$45,$d0,$ba,$45
        !byte $7e,$89,$54,$8a,$8a,$44,$44,$51,$44,$44,$44,$8a,$e9,$43,$89,$45,$45,$45,$45,$b8,$4d,$43,$43,$43,$4d,$4d,$4d,$4d,$52,$52,$72,$72
        !byte $ca,$43,$43,$43,$43,$43,$43,$43,$52,$4d,$45,$45,$a1,$43,$89,$49,$49,$45,$45,$45,$45,$e5,$43,$ba,$52,$b7,$43,$52,$43,$43,$43,$45
        !byte $45,$e5,$e6,$e6,$43,$a1,$45,$45
        !byte $20,$20,$53,$ea,$ac,$8a,$8a,$ea,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$5a,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$8a,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$6b,$45,$45,$45,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$68,$45,$45,$45,$54,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$67,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$4c,$b3,$20,$20,$53,$5c,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$44,$44,$44,$20,$20,$20,$20,$20,$67,$67,$62,$20,$67
        !byte $68,$49,$49,$49,$86,$20,$20,$20,$20,$20,$20,$5a,$20,$a9,$76,$51,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$dc,$49,$49,$49,$ea,$20,$20,$20,$20,$20,$dc,$8a
        !byte $8a,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$80,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$76,$51,$20,$20,$20,$20,$20
        !byte $20,$20,$53,$ea,$ac,$8a,$8a,$ea,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$5a,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$8a,$20,$20,$20,$20,$20
        !byte $20,$20,$4c,$eb,$cb,$43,$43,$43,$b5,$20,$20,$20,$dc,$49,$49,$49,$ea,$20,$cd,$53,$62,$20,$53,$5c,$20,$20,$20,$20,$b2,$20,$20,$4c
        !byte $d1,$20,$5b,$53,$20,$20,$20,$60,$c6,$e3,$20,$20,$20,$20,$60,$43,$43,$43,$43,$ec,$20,$20,$20,$20,$20,$53,$67,$87,$4d,$4d,$4d,$d2
        !byte $20,$20,$20,$5a,$20,$20,$20,$83,$53,$4a,$53,$20,$53,$88,$62,$bb,$43,$43,$43,$43,$62,$20,$20,$20,$a9,$4c,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$53,$62,$20,$6b,$4d,$4d,$4d,$49,$20,$60,$51,$20,$20,$20,$20,$b2,$20,$20,$20,$53,$20,$20,$4c,$60,$d2,$20,$20,$5c,$5b,$20
        !byte $a9,$76,$51,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$60,$d2,$d3,$cb,$43,$43,$52,$62,$20,$20,$20,$83,$60,$51,$5b,$60
        !byte $43,$43,$43,$43,$47,$20,$20,$20,$20,$20,$67,$5c,$20,$20,$60,$51,$44,$a9,$b4,$51,$62,$20,$53,$8f,$20,$20,$20,$20,$5a,$60,$51,$20
        !byte $20,$20,$20,$53,$62,$20,$20,$20,$ac,$8d,$49,$49,$64,$20,$20,$20,$20,$20,$20,$88,$bb,$43,$43,$43,$a2,$b3,$20,$20,$20,$ed,$ca,$43
        !byte $43,$72,$ea,$5a,$5c,$20,$20,$20,$20,$20,$60,$51,$bc,$82,$ac,$6b,$49,$49,$8a,$62,$20,$20,$62,$20,$20,$60,$51,$20,$20,$20,$20,$20
        !byte $20,$20,$4c,$eb,$cb,$43,$43,$43,$b5,$20,$20,$20,$dc,$49,$49,$49,$ea,$20,$cd,$53,$62,$20,$53,$5c,$20,$20,$20,$20,$b2,$20,$20,$4c
        !byte $d1,$20,$5b,$53,$20,$20,$20,$60
        !byte $a9,$4c,$4c,$83,$f2,$f2,$79,$c2,$5d,$20,$20,$53,$bb,$43,$43,$43,$a2,$b3,$62,$63,$51,$fa,$20,$5c,$20,$20,$20,$53,$7e,$88,$20,$4c
        !byte $5c,$20,$5b,$4c,$5c,$20,$20,$93,$c6,$20,$20,$20,$20,$a0,$62,$5e,$5e,$47,$5e,$c3,$5c,$20,$20,$20,$20,$58,$bd,$43,$43,$43,$43,$ee
        !byte $20,$20,$53,$7e,$88,$20,$8f,$20,$20,$4a,$99,$20,$58,$d7,$62,$83,$5e,$4a,$5e,$82,$5c,$20,$20,$20,$5c,$4c,$20,$20,$20,$53,$ef,$20
        !byte $20,$20,$b4,$75,$83,$bb,$43,$43,$43,$7c,$62,$60,$51,$51,$5c,$20,$20,$4a,$20,$20,$20,$58,$62,$20,$4c,$60,$51,$20,$20,$5c,$5b,$20
        !byte $20,$60,$51,$20,$20,$20,$53,$a0,$88,$20,$20,$20,$20,$20,$20,$20,$60,$51,$f2,$8b,$be,$be,$c2,$a8,$20,$20,$20,$20,$60,$51,$5b,$83
        !byte $5e,$97,$47,$97,$82,$20,$20,$20,$20,$20,$5e,$5c,$20,$20,$60,$51,$5b,$20,$63,$51,$20,$20,$20,$58,$fa,$82,$20,$53,$43,$bd,$a7,$20
        !byte $20,$20,$53,$7e,$b5,$62,$d2,$62,$d4,$43,$43,$43,$43,$62,$20,$b6,$88,$20,$20,$47,$5e,$97,$d5,$f0,$5e,$9a,$53,$47,$62,$c4,$f2,$50
        !byte $f2,$a3,$5c,$5c,$5c,$20,$20,$20,$20,$cd,$60,$51,$bc,$20,$4c,$43,$43,$43,$43,$51,$20,$20,$47,$20,$d9,$d6,$51,$20,$20,$20,$20,$20
        !byte $a9,$4c,$4c,$83,$f2,$f2,$79,$c2,$5d,$20,$20,$53,$bb,$43,$43,$43,$a2,$b3,$62,$63,$51,$fa,$20,$5c,$20,$20,$20,$53,$7e,$88,$20,$4c
        !byte $5c,$20,$5b,$4c,$5c,$20,$20,$93
        !byte $20,$4c,$4c,$20,$20,$20,$47,$20,$20,$20,$20,$20,$5e,$97,$d5,$f0,$5e,$20,$20,$63,$51,$20,$20,$5c,$20,$20,$20,$7f,$43,$bf,$20,$4c
        !byte $5c,$20,$5b,$f1,$5c,$20,$20,$d6,$c6,$20,$20,$20,$98,$43,$47,$20,$20,$47,$20,$20,$5c,$20,$20,$20,$98,$43,$d7,$62,$82,$47,$f8,$20
        !byte $20,$20,$7f,$43,$bf,$94,$43,$bf,$62,$4a,$20,$98,$43,$43,$88,$20,$20,$4a,$20,$8f,$5c,$20,$20,$9a,$5c,$4c,$20,$20,$20,$7f,$43,$62
        !byte $20,$20,$94,$d7,$62,$20,$f8,$4a,$62,$20,$20,$60,$60,$51,$5c,$99,$53,$43,$88,$20,$20,$7e,$75,$20,$4c,$60,$51,$20,$20,$5c,$5b,$20
        !byte $20,$60,$51,$20,$20,$20,$7f,$43,$bf,$20,$20,$20,$20,$20,$20,$20,$60,$51,$20,$20,$58,$20,$20,$20,$20,$20,$20,$20,$60,$51,$5b,$20
        !byte $20,$20,$47,$20,$20,$20,$20,$20,$20,$20,$20,$5c,$20,$20,$60,$51,$5b,$20,$63,$51,$20,$20,$20,$58,$20,$20,$20,$94,$43,$d8,$c6,$20
        !byte $20,$20,$7f,$43,$d7,$62,$47,$99,$5e,$f0,$58,$97,$97,$82,$53,$43,$bf,$20,$98,$d7,$62,$20,$4a,$20,$20,$20,$20,$47,$20,$20,$20,$58
        !byte $20,$20,$5c,$5c,$5c,$20,$20,$20,$98,$d7,$60,$51,$bc,$20,$83,$97,$63,$51,$97,$82,$20,$98,$d7,$62,$20,$d6,$51,$20,$20,$20,$20,$20
        !byte $20,$4c,$4c,$20,$20,$20,$47,$20,$20,$20,$20,$20,$5e,$97,$d5,$f0,$5e,$20,$20,$63,$51,$20,$20,$5c,$20,$20,$20,$7f,$43,$bf,$20,$4c
        !byte $5c,$20,$5b,$f1,$5c,$20,$20,$d6
        !byte $20,$4c,$4c,$20,$20,$20,$47,$20,$20,$98,$4d,$4d,$d2,$20,$4a,$20,$20,$20,$20,$63,$51,$20,$20,$5c,$20,$20,$d9,$77,$50,$c1,$6c,$4c
        !byte $5c,$20,$5b,$4c,$c0,$20,$20,$d6,$c6,$20,$20,$20,$f3,$50,$c1,$e3,$20,$47,$20,$20,$5c,$20,$20,$20,$f3,$78,$f2,$6c,$20,$47,$20,$20
        !byte $20,$d9,$77,$50,$c1,$77,$50,$f2,$6c,$4a,$20,$f3,$f2,$f2,$c1,$e3,$20,$4a,$20,$20,$5c,$20,$20,$20,$c0,$4c,$20,$20,$d9,$77,$79,$c1
        !byte $20,$c3,$f2,$f2,$6c,$20,$20,$4a,$20,$20,$20,$60,$51,$51,$c0,$20,$f3,$50,$c1,$20,$c3,$78,$c1,$e3,$4c,$60,$51,$20,$20,$5c,$5b,$20
        !byte $20,$60,$51,$20,$20,$d9,$77,$50,$c1,$b8,$52,$52,$4d,$6b,$45,$45,$da,$51,$20,$20,$58,$20,$20,$20,$62,$45,$45,$81,$60,$51,$5b,$20
        !byte $20,$20,$47,$20,$20,$53,$b8,$4d,$4d,$45,$62,$5c,$20,$20,$60,$51,$5b,$20,$63,$51,$20,$20,$20,$58,$20,$20,$c3,$77,$50,$78,$c6,$20
        !byte $20,$d9,$77,$78,$f2,$6c,$47,$20,$20,$20,$58,$20,$20,$20,$c3,$78,$f2,$6c,$f3,$79,$6c,$20,$4a,$20,$20,$20,$20,$47,$20,$20,$20,$58
        !byte $20,$20,$5c,$5c,$5c,$20,$20,$20,$f3,$79,$60,$51,$bc,$20,$20,$20,$63,$51,$20,$20,$20,$f3,$79,$6c,$20,$d6,$51,$20,$20,$20,$20,$20
        !byte $20,$4c,$4c,$20,$20,$20,$47,$20,$20,$98,$4d,$4d,$d2,$20,$4a,$20,$20,$20,$20,$63,$51,$20,$20,$5c,$20,$20,$d9,$77,$50,$c1,$6c,$4c
        !byte $5c,$20,$5b,$4c,$c0,$20,$20,$d6
        !byte $a3,$a3,$5d,$f4,$c4,$5d,$5d,$f4,$8b,$8b,$be,$6a,$be,$8b,$f5,$f5,$6a,$6a,$f5,$6a,$f5,$c2,$c4,$5d,$a3,$5d,$f2,$be,$6a,$78,$c2,$a3
        !byte $8b,$8b,$6a,$c2,$be,$8b,$8b,$5d,$5d,$f4,$5d,$c4,$a3,$8b,$6a,$c2,$5d,$5d,$a3,$8b,$f5,$c2,$8b,$8b,$c2,$c4,$c4,$f2,$a3,$f2,$f4,$f2
        !byte $5d,$c4,$a3,$c4,$a3,$8b,$8b,$8b,$f5,$6a,$be,$c2,$c4,$a3,$f2,$8b,$c2,$a3,$c4,$c4,$c2,$c2,$a3,$8b,$6a,$6a,$6a,$6a,$6a,$6a,$8b,$be
        !byte $c2,$a3,$5d,$78,$6a,$6a,$c2,$5d,$c4,$a3,$5d,$5d,$f5,$6a,$c2,$8b,$6a,$6a,$a3,$c4,$78,$6a,$6a,$c2,$a3,$5d,$5d,$5d,$8b,$be,$c2,$a3
        !byte $5d,$5d,$c4,$a3,$5d,$a3,$5d,$f4,$f2,$6a,$8b,$a3,$79,$a3,$f2,$be,$8b,$a3,$a3,$5d,$f4,$8b,$8b,$6a,$6a,$8b,$6a,$f5,$a3,$5d,$c4,$a3
        !byte $a3,$be,$f5,$8b,$be,$6a,$6a,$8b,$8b,$a3,$f4,$5d,$8b,$6a,$a3,$f2,$f2,$8b,$6a,$8b,$f5,$6a,$6a,$f5,$8b,$f5,$f5,$6a,$8b,$8b,$a3,$5d
        !byte $f2,$8b,$8b,$f5,$6a,$8b,$5d,$5d,$f4,$5d,$f2,$8b,$6a,$f5,$be,$6a,$8b,$8b,$c2,$5d,$f2,$f5,$c2,$f4,$a3,$5d,$f2,$f2,$c2,$f2,$f2,$a3
        !byte $a3,$a3,$5d,$f4,$be,$6a,$6a,$c2,$f2,$f5,$6a,$6a,$be,$6a,$6a,$c2,$a3,$8b,$8b,$c2,$5d,$c4,$5d,$f2,$5d,$f4,$5d,$5d,$c4,$a3,$5d,$5d
        !byte $a3,$a3,$5d,$f4,$c4,$5d,$5d,$f4,$8b,$8b,$be,$6a,$be,$8b,$f5,$f5,$6a,$6a,$f5,$6a,$f5,$c2,$c4,$5d,$a3,$5d,$f2,$be,$6a,$78,$c2,$a3
        !byte $8b,$8b,$6a,$c2,$be,$8b,$8b,$5d
        !byte $20,$20,$20,$a9,$62,$20,$20,$a9,$62,$20,$20,$20,$20,$62,$a8,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $99,$c9,$82,$20,$20,$20,$20,$20,$a9,$62,$20,$95,$20,$20,$20,$20,$20,$20,$ac,$56,$80,$20,$b2,$20,$20,$20,$20,$20,$20,$62,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$f8,$20,$b3,$20,$62,$20,$20,$20,$20,$67,$44,$62,$20,$20,$83,$82,$20,$20,$20,$20,$20,$20,$20,$9a,$a8,$20
        !byte $a9,$20,$20,$20,$20,$62,$6f,$20,$9a,$53,$20,$20,$20,$ac,$56,$80,$20,$20,$20,$20,$20,$20,$20,$20,$53,$b3,$20,$20,$20,$20,$9a,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$62,$71,$65,$20,$20,$20,$95,$20,$20,$f7,$67,$56,$64,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$83,$20,$20,$20,$20,$20,$20,$20,$20,$20,$9a,$fb,$99,$20,$20,$20,$95,$95,$62,$20,$20,$20,$83,$20,$67,$44,$86
        !byte $20,$b2,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$99,$20,$20,$20,$20,$20,$20,$20,$b2,$20,$20,$20,$fb,$b3,$20,$83,$20,$c8,$9a
        !byte $f6,$c7,$fb,$67,$20,$20,$20,$20,$20,$20,$20,$9a,$a8,$20,$20,$fa,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$95,$95,$4f,$fe,$20
        !byte $20,$20,$20,$a9,$62,$20,$20,$a9,$62,$20,$20,$20,$20,$62,$a8,$20,$20,$20,$20,$62,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $99,$c9,$82,$20,$20,$20,$20,$20
        !byte $c9,$20,$20,$20,$20,$20,$20,$20,$20,$20,$9a,$a8,$20,$20,$20,$20,$20,$20,$fa,$20,$f8,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20
        !byte $62,$20,$20,$20,$20,$c9,$20,$62,$62,$20,$20,$c9,$20,$9a,$a8,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20,$62,$a8
        !byte $20,$20,$20,$20,$20,$62,$20,$20,$62,$20,$c8,$20,$20,$20,$20,$4b,$4b,$c9,$20,$20,$20,$a8,$20,$9a,$99,$20,$20,$f7,$20,$20,$20,$82
        !byte $20,$62,$20,$20,$20,$20,$83,$82,$20,$20,$62,$20,$fb,$20,$20,$20,$20,$20,$20,$99,$20,$20,$83,$20,$20,$20,$20,$20,$f8,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$fb,$20,$f7,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$83,$4b,$4b
        !byte $20,$20,$82,$20,$20,$20,$20,$20,$83,$82,$9a,$99,$20,$20,$20,$20,$a9,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
        !byte $20,$d9,$20,$20,$20,$20,$20,$20,$c8,$20,$9a,$20,$20,$9a,$20,$20,$20,$f8,$99,$20,$20,$83,$82,$20,$20,$20,$20,$20,$83,$4b,$82,$20
        !byte $c9,$20,$20,$20,$20,$20,$20,$20,$20,$20,$9a,$a8,$20,$20,$20,$20,$20,$20,$fa,$20,$f8,$20,$20,$20,$20,$20,$20,$20,$62,$20,$20,$20
        !byte $62,$20,$20,$20,$20,$c9,$20,$62
prow_lo:
        !byte 0,0,<(patrows+0),<(patrows+168),<(patrows+336),<(patrows+504),<(patrows+672),<(patrows+840),<(patrows+1008),<(patrows+1304),<(patrows+1600),<(patrows+1896),<(patrows+2192),<(patrows+2488),<(patrows+2784),<(patrows+3080),<(patrows+3376),<(patrows+3672),<(patrows+3968),<(patrows+4264),<(patrows+4560),<(patrows+4856),<(patrows+5152),<(patrows+5448),<(patrows+5744)
prow_hi:
        !byte 0,0,>(patrows+0),>(patrows+168),>(patrows+336),>(patrows+504),>(patrows+672),>(patrows+840),>(patrows+1008),>(patrows+1304),>(patrows+1600),>(patrows+1896),>(patrows+2192),>(patrows+2488),>(patrows+2784),>(patrows+3080),>(patrows+3376),>(patrows+3672),>(patrows+3968),>(patrows+4264),>(patrows+4560),>(patrows+4856),>(patrows+5152),>(patrows+5448),>(patrows+5744)
srow_lo:
        !byte <($8400+0),<($8400+40),<($8400+80),<($8400+120),<($8400+160),<($8400+200),<($8400+240),<($8400+280),<($8400+320),<($8400+360),<($8400+400),<($8400+440),<($8400+480),<($8400+520),<($8400+560),<($8400+600),<($8400+640),<($8400+680),<($8400+720),<($8400+760),<($8400+800),<($8400+840),<($8400+880),<($8400+920),<($8400+960)
srow_hi:
        !byte >($8400+0),>($8400+40),>($8400+80),>($8400+120),>($8400+160),>($8400+200),>($8400+240),>($8400+280),>($8400+320),>($8400+360),>($8400+400),>($8400+440),>($8400+480),>($8400+520),>($8400+560),>($8400+600),>($8400+640),>($8400+680),>($8400+720),>($8400+760),>($8400+800),>($8400+840),>($8400+880),>($8400+920),>($8400+960)
aa_slo: !byte <($8000+8192),<($8000+10240),<($8000+12288),<($8000+12736)
aa_shi: !byte >($8000+8192),>($8000+10240),>($8000+12288),>($8000+12736)
aa_dlo: !byte <($8000+0),<($8000+13632),<($8000+14656),<($8000+15104)
aa_dhi: !byte >($8000+0),>($8000+13632),>($8000+14656),>($8000+15104)
aa_cnt: !byte 16,16,7,7
bmask:  !byte 0,127,127,255,255,255,255
; map bytes: 6040
