; NES Smash Proyect 
; Prof. Juan Patarroyo / CIIC 4082
; Carolina Morales Sánchez y Guillermo Carrion
; Grupo L


.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

.segment "ZEROPAGE" 
; Variables
  jumpCTR: .res 1 ; Jump Counter
  chy: .res 1 ; Y location
  chx: .res 1 ; 
  frameCTR: .res 1
  switch: .res 1

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:
load_variables: ; intiates declared variables
  LDA #$D0
  STA chy
  LDA #$40
  STA chx

load_palettes: 
  lda $2002
  lda #$3f
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
@loop:
  lda palettes, x
  sta $2007
  inx
  cpx #$20
  bne @loop

LoadSprite:
  jsr LoadIdleR ; Initial sprite that loads in screen


;;;;;;
; Loads Background
Loabyteackground: ; Inspiration using forum videos
  lda $2002
  lda #$20
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
LoabyteackgroundLoop1:
  lda background, x
  sta $2007
  inx 
  bne LoabyteackgroundLoop1

  ldx #$00
LoabyteackgroundLoop2:
  lda background + 256, x
  sta $2007
  inx 
  bne LoabyteackgroundLoop2

  ldx #$00
LoabyteackgroundLoop3:
  lda background + 512, x
  sta $2007
  inx 
  bne LoabyteackgroundLoop3

  ldx #$00
LoabyteackgroundLoop4:
  lda background + 768, x
  sta $2007
  inx 
  bne LoabyteackgroundLoop4

;;;;;;
enable_rendering:
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00010000	; Enable Sprites
  sta $2001

forever:
  jmp forever
;;;;;;;

; Constant Calls
nmi:
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014
  ;LDA #$00     ; for scrolling
  ;STA $2005
  ;STA $2005
  ; Pallete chooser (for either sprites or backgrounds)
  LDA #%10010000  
  STA $2000
  LDA #%00011110
  STA $2001
  INC frameCTR

;;;;;
LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ; tell both the controllers to latch buttons
;;;;;

; Readers for controllers

ReadA: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ NoJump   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

Jump:
  lda jumpCTR ; Stops it from ascending
  cmp #30 ;max height
  bcs NoJump 
  inc jumpCTR
  lda chy
  ;vvvv ascends character vvvv
  sta $0200 ; first tile y
  sta $0204 ; second tile y
  tay
  clc
  adc #$08
  sta $0208 ; Third tile y
  sta $020c ; fourth tile y
  dey
  dey 
  sty chy 
  jmp ReadADone
 
;if either jump button is released/max height
NoJump:  
  lda #$FF
  sta jumpCTR
  lda chy
  clc
  cmp #$D0  ; check if colliding with floor 
  bpl FloorLevel ; stop falling
  sta $0200 ; same but descresing y values of tiles
  sta $0204
  tay
  clc
  adc #$08
  sta $0208
  sta $020c
  iny  
  iny 
  sty chy 
  clc
  jmp ReadADone

FloorLevel: 
  lda #0
  sta jumpCTR
ReadADone:        ; handling this button is done

  
Reabyte: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReabyteDone   ; branch to ReabyteDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
ReabyteDone:        ; handling this button is done

; Loads hurt sprite
ReadSelect: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadSelectDone   ; branch to ReadADone if button is NOT pressed (0)

  JSR LoadHurtR
  LDA #$00
  CMP switch
  BEQ TurnedRight ; loads sprite depending on direction
  JSR LoadHurtL
  TurnedRight:
  LDA chy
  STA $0200 ; so it doesnt teleport to initial sprite loads
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020c
  LDA chx
  STA $0203
  STA $020B
  CLC
  ADC #$08
  STA $0207
  STA $020F

ReadSelectDone:

; when w pressed, ded sprite
ReadStart: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadStartDone   ; branch to ReadADone if button is NOT pressed (0)
  JSR LoadDed
  LDA chy ; death is symmetrical, no direction needed
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020c
  LDA chx
  STA $0203
  STA $020B
  CLC
  ADC #$08
  STA $0207
  STA $020F

ReadStartDone:

;not used
ReadUp: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadUpDone   ; branch to ReadADone if button is NOT pressed (0)

ReadUpDone:

; idle (same process as ReadSelect)
ReadDown: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadDownDone   ; branch to ReadADone if button is NOT pressed (0)
  JSR LoadIdleR
  LDA #$00
  CMP switch
  BEQ NotTurnedLeft
  JSR LoadIdleL
  NotTurnedLeft:
  LDA chy
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020c
  LDA chx
  STA $0203
  STA $020B
  CLC
  ADC #$08
  STA $0207
  STA $020F

ReadDownDone:


ReadLeft: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadLeftDone   ; branch to ReadADone if button is NOT pressed (0)
  JSR LoadWalkL1 ; loads walking sprite left
  LDA #$01
  STA switch ; updates direction cuz looking left
  LDA chx     ; load sprite X position
  SEC             ; make sure carry flag is set
  SBC #$03        ; A = A - 3
  STA $0203       ; save sprite X position
  ClC
  ADC #$08
  STA $0207       ; save sprite X position
  LDA chx
  SEC             ; make sure carry flag is set
  SBC #$03        ; A = A - 3
  STA $020B       ; save sprite X position
  ClC
  ADC #$08
  STA $020F       ; save sprite X position
  LDA chx
  SEC             ; make sure carry flag is set
  SBC #$03        ; A = A - 3
  STA chx

  LDA chy  ; we also update y so it doesnt default load on top
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020c
ReadLeftDone:

; same as left, but right
ReadRight: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadRightDone ; branch to ReadADone if button is NOT pressed (0)
  JSR LoadWalkR1
  LDA #$00
  STA switch
  LDA chx      ; load sprite X position
  CLC           ; make sure carry flag is set
  ADC #$03        ; A = A + 3
  STA $0203       ; save sprite X position
  CLC
  ADC #$08
  STA $0207       ; save sprite X position
  LDA chx
  CLC            ; make sure carry flag is set
  ADC #$03        ; A = A - 3
  STA $020B       ; save sprite X position
  CLC
  ADC #$08
  STA $020F       ; save sprite X position
  LDA chx
  CLC           ; make sure carry flag is set
  ADC #$03        ; A = A - 3
  STA chx

  LDA chy
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020c

ReadRightDone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;
; player 2 not uses
ReadA2: 
  LDA $4017       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadADone2   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
ReadADone2:        ; handling this button is done
  

Reabyte2: 
  LDA $4017       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReabyteDone2   ; branch to ReabyteDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
ReabyteDone2:        ; handling this button is done

ReadSelect2: 
  LDA $4017       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadSelectDone2   ; branch to ReadADone if button is NOT pressed (0)

ReadSelectDone2:

ReadStart2: 
  LDA $4017       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadStartDone2   ; branch to ReadADone if button is NOT pressed (0)

ReadStartDone2:

ReadUp2: 
  LDA $4017       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadUpDone2   ; branch to ReadADone if button is NOT pressed (0)

ReadUpDone2:

ReadDown2: 
  LDA $4017       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadDownDone2   ; branch to ReadADone if button is NOT pressed (0)

ReadDownDone2:

ReadLeft2: 
  LDA $4017       ; player 2 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadLeftDone2 ; branch to ReadADone if button is NOT pressed (0)
  LDA $0213       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  SBC #$03        ; A = A + 3
  STA $0213       ; save sprite X position
  LDA $0217       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  SBC #$03        ; A = A + 3
  STA $0217       ; save sprite X position
  LDA $021B       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  SBC #$03        ; A = A + 3
  STA $021B       ; save sprite X position
  LDA $021F       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  SBC #$03        ; A = A + 3
  STA $021F       ; save sprite X position
ReadLeftDone2:

ReadRight2: 
  LDA $4017       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadRightDone2 ; branch to ReadADone if button is NOT pressed (0)
  LDA $0213       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$03        ; A = A + 3
  STA $0213       ; save sprite X position
  LDA $0217       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$03        ; A = A + 3
  STA $0217       ; save sprite X position
  LDA $021B       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$03        ; A = A + 3
  STA $021B       ; save sprite X position
  LDA $021F       ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$03        ; A = A + 3
  STA $021F       ; save sprite X position
ReadRightDone2:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  RTI


; Right Side Sprites
LoadIdleR:
  LDX #$00     ; iterator       
LoadIdleRLoop:
  LDA P1_IDLE_R, x   ; we get the value of the sprite in position x,
  STA $0200, x  ; uploads value to address in memory for tile to be displayed        
  INX    ;  then sprite, then flag, then y     
  CPX #$10    ; up to 16 bytes (4 tiles)
  BNE LoadIdleRLoop ; if it hasnt reach 16, loop again
  RTS ; return to original call

; repeats all over for all sprites
LoadWalkR1:
  LDX #$00              
LoadWalkR1Loop:
  LDA P1_WALKR1, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadWalkR1Loop
  rts

LoadWalkR2:
  LDX #$00              
LoadWalkR2Loop:
  LDA P1_WALKR2, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadWalkR2Loop
  rts

LoadWalkR3:
  LDX #$00              
LoadWalkR3Loop:
  LDA P1_WALKR3, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadWalkR3Loop
  rts

LoadJumpR:
  LDX #$00              
LoadJumpRLoop:
  LDA P1_JMPR, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadJumpRLoop
  RTS

LoadHurtR:
  LDX #$00              
LoadHurtRLoop:
  LDA P1_HRTR, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadHurtRLoop
  RTS

LoadDed:
  LDX #$00              
LoadDedLoop:
  LDA P1_DED, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadDedLoop
  RTS
LoadPunchR:
  LDX #$00              
LoadPunchRLoop:
  LDA P1_PUNCHR, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadPunchRLoop
  RTS

; Left
LoadIdleL:
  LDX #$00              
LoadIdleLLoop:
  LDA P1_IDLE_L, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadIdleLLoop
  RTS

LoadWalkL1:
  LDX #$00              
LoadWalkL1Loop:
  LDA P1_WALKL1, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadWalkL1Loop
  RTS

LoadWalkL2:
  LDX #$00              
LoadWalkL2Loop:
  LDA P1_WALKL2, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadWalkL2Loop
  RTS

LoadWalkL3:
  LDX #$00              
LoadWalkL3Loop:
  LDA P1_WALKL3, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadWalkL3Loop
  RTS

LoadJumpL:
  LDX #$00              
LoadJumpLLoop:
  LDA P1_JMPL, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadJumpLLoop
  RTS

LoadHurtL:
  LDX #$00              
LoadHurtLLoop:
  LDA P1_HRTL, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadHurtLLoop
  RTS

LoadPunchL:
  LDX #$00              
LoadPunchLLoop:
  LDA P1_PUNCHL, x        
  STA $0200, x          
  INX                   
  CPX #$10            
  BNE LoadPunchLLoop
  RTS

palettes:
  ; Background Palette
  .byte $0f, $22, $10, $39
  .byte $0f, $01, $21, $31 ; Different color flower
  .byte $0f, $22, $10, $39 ; Main color backrgound
  .byte $0f, $25, $15, $05

  ; Sprite Palette
  .byte $0f, $25, $15, $05 ; Pink Kirby
  .byte $0f, $21, $11, $01 ; Blue Kirby
  .byte $0f, $2A, $19, $09 ; Poisioned Kirby
  .byte $0f, $2B, $2B, $2B


sprites:
     ; Y  tile  attr  X
  ;Right Side facing
     ; Y  tile  attr  X
P1_IDLE_R:
  .byte $CE, $01, $00, $40   ;idle?
  .byte $CE, $02, $00, $48   ;D8 y E0, posicion inicial
  .byte $D6, $11, $00, $40   
  .byte $D6, $12, $00, $48   

;  P2_IDLE_L:
;   .byte $D8, $01, $41, $B8   ;idle
;   .byte $D8, $02, $41, $B0   
;   .byte $E0, $11, $41, $B8   
;   .byte $E0, $12, $41, $B0 
 

P1_WALKR1:
  .byte $40, $03, $00, $50   ;walk 1
  .byte $40, $04, $00, $58   
  .byte $48, $13, $00, $50   
  .byte $48, $14, $00, $58   

P1_WALKR2:
  .byte $56, $0B, $00, $50   ;step middle/2
  .byte $56, $0C, $00, $58   
  .byte $5e, $1B, $00, $50   
  .byte $5e, $1C, $00, $58   

P1_WALKR3:
  .byte $56, $0D, $00, $60   ;step 3
  .byte $56, $0E, $00, $68   
  .byte $5e, $1D, $00, $60   
  .byte $5e, $1E, $00, $68  

P1_JMPR:
  .byte $40, $05, $00, $60   ;jump
  .byte $40, $06, $00, $68   
  .byte $48, $15, $00, $60   
  .byte $48, $16, $00, $68   

P1_HRTR:
  .byte $40, $07, $02, $70   ;dmg/hurt
  .byte $40, $08, $02, $78   
  .byte $48, $17, $02, $70   
  .byte $48, $18, $02, $78   

P1_DED:
  .byte $56, $09, $02, $40   ;ded
  .byte $56, $0A, $02, $48   
  .byte $5e, $19, $02, $40   
  .byte $5e, $1A, $02, $48  

P1_PUNCHR:
  .byte $60, $21, $03, $50  ; punch
  .byte $60, $22, $03, $58
  .byte $68, $31, $03, $50
  .byte $68, $32, $03, $58

    
  ;Left Side facing
     ; Y  tile  attr  X
P1_IDLE_L:
  .byte $6c, $02, $40, $40   ;idle
  .byte $6c, $01, $40, $48   
  .byte $74, $12, $40, $40   
  .byte $74, $11, $40, $48   

P1_WALKL1:
  .byte $6c, $04, $40, $58   ;walk 1/ n maybe hit as well
  .byte $6c, $03, $40, $50   
  .byte $74, $14, $40, $58   
  .byte $74, $13, $40, $50   

P1_WALKL2:
  .byte $82, $0B, $40, $58   ;step middle/2
  .byte $82, $0C, $40, $50   
  .byte $8A, $1B, $40, $58   
  .byte $8A, $1C, $40, $50   

P1_WALKL3:
  .byte $82, $0D, $40, $68   ;step 3
  .byte $82, $0E, $40, $60   
  .byte $8A, $1D, $40, $68   
  .byte $8A, $1E, $40, $60   

P1_JMPL:
  .byte $6c, $05, $40, $68   ;jump
  .byte $6c, $06, $40, $60   
  .byte $74, $15, $40, $68   
  .byte $74, $16, $40, $60   

P1_HRTL:
  .byte $6c, $08, $42, $78   ;dmg/hurt
  .byte $6c, $07, $42, $70   
  .byte $74, $18, $42, $78   
  .byte $74, $17, $42, $70 

P1_PUNCHL:
  .byte $60, $22, $43, $50 ;left punch
  .byte $60, $21, $43, $58
  .byte $68, $32, $43, $50
  .byte $68, $31, $43, $58



background:
	.byte $f1,$fd,$ef,$ef,$ec,$ed,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$df,$ef,$ef,$ef
	.byte $fe,$fc,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ea,$ee,$ed,$ec,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$cf,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ea,$ed,$ec,$ee,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$cf
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ea,$ee,$ed,$ec,$ed,$ef,$cf,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$cf,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$e7,$fa,$ef,$ef,$ef,$ef,$ef,$ea,$ed,$ec,$ed,$ec,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ea,$eb,$ed,$ee,$eb
	.byte $ef,$ef,$e7,$f2,$f2,$f9,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$df,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$e7,$f2,$f2,$e5,$f1,$f9,$e7,$fa,$ef,$ef,$ef,$ef,$df,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$df,$ef,$ef,$ef,$ef,$ef,$ef,$ef
	.byte $e8,$f2,$f2,$e5,$f1,$f1,$f1,$e3,$f1,$fb,$ef,$ef,$cf,$ef,$ef,$df
	.byte $ef,$ef,$ef,$ef,$ea,$ec,$ed,$ed,$ee,$ef,$ef,$ef,$ef,$ef,$ef,$e6
	.byte $f2,$f2,$e5,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f9,$ef,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$e7,$f2
	.byte $e5,$f1,$f1,$f2,$e5,$f1,$f1,$f1,$f1,$f1,$f1,$f9,$ef,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$e8,$f2,$e4
	.byte $f1,$f1,$f2,$e3,$f1,$f1,$f1,$f2,$e5,$f1,$f1,$f1,$fa,$ef,$ef,$ef
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$e7,$e4,$f1,$f1
	.byte $f1,$f2,$e3,$f1,$f1,$f1,$f2,$e3,$f1,$f1,$f1,$f1,$f1,$fb,$ef,$ef
	.byte $ef,$ef,$ef,$df,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$e6,$e4,$f1,$f1,$f1
	.byte $f1,$e4,$f1,$f1,$f1,$f2,$e4,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$fb,$ef
	.byte $ea,$eb,$eb,$ee,$ef,$ef,$ef,$ef,$ef,$ef,$e8,$e5,$f1,$f1,$f1,$f1
	.byte $f1,$f1,$f1,$f1,$f1,$e5,$f1,$f1,$f1,$f1,$e2,$f3,$f1,$f1,$f1,$fb
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$e7,$e4,$f1,$f1,$f1,$f1,$f1
	.byte $f1,$f1,$f1,$f1,$f1,$f1,$f1,$e1,$f6,$f8,$f0,$f0,$f3,$f1,$f1,$f1
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$ef,$e7,$e3,$f1,$f1,$f1,$f1,$f1,$f1
	.byte $f1,$f1,$e2,$f3,$f1,$f1,$e0,$f0,$f0,$f0,$f0,$f0,$f0,$f6,$f7,$f8
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$e8,$e5,$f1,$f1,$f1,$e1,$f6,$f7,$f7
	.byte $f7,$f8,$f0,$f0,$f3,$e0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
	.byte $ef,$ef,$ef,$ef,$ef,$ef,$e8,$e3,$f1,$f1,$f1,$e0,$f0,$f0,$f0,$f0
	.byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f4,$f5,$f0,$f0,$f0,$f0,$f0,$f0
	.byte $ef,$ef,$ef,$ef,$ef,$e6,$e4,$f1,$f1,$f1,$e2,$f0,$f0,$f0,$f0,$f0
	.byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f4,$f1,$f1,$f5,$d6,$f0,$f0,$f0,$f0
	.byte $ef,$ef,$ef,$ef,$e6,$e4,$f1,$f1,$f1,$e2,$f0,$f0,$f0,$f0,$f0,$f0
	.byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f3,$f1,$f1,$f1,$f5,$f0,$f0,$f0,$f0
	.byte $ef,$ef,$ef,$e7,$e5,$f1,$f1,$f1,$e1,$f0,$cc,$cd,$cd,$cd,$cd,$cd
	.byte $cd,$cd,$cd,$cd,$cd,$ce,$f0,$f0,$f3,$f1,$f1,$f8,$f0,$d6,$f0,$f0
	.byte $ef,$ef,$e8,$e5,$f1,$f1,$f1,$e2,$f0,$f0,$dc,$dd,$dd,$dd,$dd,$dd
	.byte $dd,$dd,$dd,$dd,$dd,$de,$f0,$f0,$f0,$f3,$e2,$f0,$f0,$f0,$f0,$f0
	.byte $ef,$e7,$e4,$f1,$f1,$f1,$e1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
	.byte $f0,$f0,$d6,$d6,$d6,$f0,$f0,$f0,$f0,$d6,$d6,$f0,$f0,$f0,$d6,$f0
	.byte $e8,$e3,$f1,$f1,$f1,$e2,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
	.byte $d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$f0,$f0,$f0,$f0,$d6
	.byte $e4,$f1,$f1,$f1,$e2,$f0,$f0,$f0,$f0,$d6,$d6,$d6,$f0,$f0,$f0,$f0
	.byte $f0,$f0,$f0,$f0,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$f0,$f0
	.byte $f1,$f1,$f1,$e2,$f0,$f0,$f0,$f0,$f0,$d6,$d6,$d6,$d6,$d6,$d6,$d6
	.byte $d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$d6,$f0,$f0
	.byte $cc,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd
	.byte $cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$cd,$ce
	.byte $dc,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd
	.byte $dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$dd,$de
	.byte $03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$50,$50,$10,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$05,$05,$05,$05,$05,$05,$05,$05


; Character memory
.segment "CHARS"
.incbin "initial_try.chr"
