********************************************************************
* CoVDG - VDG Console Output Subroutine for VTIO
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      ????/??/??
* From Tandy OS-9 Level One VR 02.00.00
*
*          2003/09/22  Rodney Hamilton
* recoded dispatch table fcbs, fixed cursor color bug

         nam   CoVDG
         ttl   VDG Console Output Subroutine for VTIO

* Disassembled 98/08/23 17:47:40 by Disasm v1.6 (C) 1988 by RML

         ifp1
         use   defsfile
         use   vtiodefs
         endc

tylg     set   Systm+Objct   
atrv     set   ReEnt+rev
rev      set   $00
edition  set   1

         mod   eom,name,tylg,atrv,start,size

u0000    rmb   0
size     equ   .
         fcb   $07 

name     fcs   /CoVDG/
         fcb   edition

start    equ   *
         lbra  Init
         lbra  Write
         lbra  GetStat
         lbra  SetStat
Term     pshs  y,x
         pshs  u		save U
         ldd   #512		32x16 VDG memory size
         ldu   <V.ScrnA,u 	get pointer to memory
         os9   F$SRtMem 	return to system
         puls  u		restore U
         ldb   <V.COLoad,u
         andb  #~ModCoVDG
         bra   L0086
* Init
Init     pshs  y,x		save regs
         lda   #$AF
         sta   <V.CColr,u	save default color cursor
         pshs  u		save static ptr
         ldd   #768		allocate 768 bytes for now
         os9   F$SRqMem 	get it
         tfr   u,d		put ptr in D
         tfr   u,x		and X
         bita  #$01		odd page?
         beq   L0052		branch if not
         leax  >256,x		else move X up 256 bytes
         bra   L0056		and return first 256 bytes
L0052    leau  >512,u		else move X up 512 bytes
L0056    ldd   #256		and return last 256 bytes
         os9   F$SRtMem 	free it!
         puls  u		restore static ptr
         stx   <V.ScrnA,u 	save VDG screen memory
         pshs  y
         leay  -$0E,y
         clra  
         clrb  
         jsr   [<V.DspVct,u]	display screen (routine in VTIO)
         puls  y
         stx   <V.CrsrA,u 	save start cursor position
         leax  >512,x		point to end of screen
         stx   <V.ScrnE,u 	save it
         lda   #$60		get default character
         sta   <V.CChar,u 	put character under the cursor
         sta   <V.Chr1,u	only referenced here ??
         lbsr  ClrScrn		clear the screen
         ldb   <V.COLoad,u
         orb   #ModCoVDG	set to CoVDG found (?)
L0086    stb   <V.COLoad,u
         clrb  
         puls  pc,y,x

* Write
* Entry: A = char to write
*        Y = path desc ptr
Write    tsta  
         bmi   L00D0
         cmpa  #$1F		byte $1F?
         bls   Dispatch		branch if lower or same
         ldb   <V.CFlag,u
         beq   L00B0
         cmpa  #$5E
         bne   L00A0
         lda   #$00
         bra   L00D0
L00A0    cmpa  #$5F
         bne   L00A8
         lda   #$1F
         bra   L00D0
L00A8    cmpa  #$60
         bne   L00C0
         lda   #$67
         bra   L00D0
L00B0    cmpa  #$7C
         bne   L00B8
         lda   #$21
         bra   L00D0
L00B8    cmpa  #$7E
         bne   L00C0
         lda   #$2D
         bra   L00D0
L00C0    cmpa  #$60
         bcs   L00C8
         suba  #$60
         bra   L00D0
L00C8    cmpa  #$40
         bcs   L00CE
         suba  #$40
L00CE    eora  #$40
L00D0    ldx   <V.CrsrA,u	get cursor address in X
         sta   ,x+		store character at address
         stx   <V.CrsrA,u 	update cursor address
         cmpx  <V.ScrnE,u 	end of screen?
         bcs   L00DF		branch if not
         bsr   SScrl		else if at end of screen, scroll it
L00DF    bsr   ShowCrsr		ends with a CLRB/RTS anyhow

* no operation entry point
NoOp     clrb  
         rts   

* Screen Scroll Routine
SScrl    ldx   <V.ScrnA,u	get address of screen
         leax  <32,x		move to 2nd line
L00E9    ldd   ,x++		copy from this line
         std   <-34,x		to prevous
         cmpx  <V.ScrnE,u	at end of screen yet?
         bcs   L00E9		branch if not
         leax  <-32,x		else back up one line
         stx   <V.CrsrA,u	save address of cursor (first col of last row)
         lda   #32		clear out row...
         ldb   #$60		...width spaces
L00FD    stb   ,x+		do it...
         deca  			end of rope?
         bne   L00FD		branch if not
L0102    rts   

Dispatch cmpa  #$1B		escape code?
         bcc   bad@		branch if same or greater
         cmpa  #$0E		$0E?
         bhi   L0102		branch if higher than
         leax  <DCodeTbl,pcr	deal with screen codes
         lsla  			adjust for table entry size
         ldd   a,x		get address in D
         jmp   d,x		and jump to routine
bad@     comb  
         ldb   #E$Write
         rts   

* display functions dispatch table
DCodeTbl fdb   NoOp-DCodeTbl		$00:no-op (null)
         fdb   CurHome-DCodeTbl		$01:HOME cursor
         fdb   CurXY-DCodeTbl		$02:CURSOR XY
         fdb   DelLine-DCodeTbl		$03:ERASE LINE
         fdb   ErEOLine-DCodeTbl	$04:CLEAR TO EOL
         fdb   Do05-DCodeTbl		$05:CURSOR ON/OFF
         fdb   CurRght-DCodeTbl		$005e  $06:CURSOR RIGHT
         fdb   NoOp-DCodeTbl		$07:no-op (bel:handled in VTIO)
         fdb   CurLeft-DCodeTbl		$0050  $08:CURSOR LEFT
         fdb   CurUp-DCodeTbl		$0119  $09:CURSOR UP
         fdb   CurDown-DCodeTbl		$0038  $0A:CURSOR DOWN
         fdb   ErEOScrn-DCodeTbl	$006c  $0B:ERASE TO EOS
         fdb   ClrScrn-DCodeTbl		$0070  $0C:CLEAR SCREEN
         fdb   Retrn-DCodeTbl		$001e  $0D:RETURN
         fdb   DoAlpha-DCodeTbl		$012a  $0E:DISPLAY ALPHA

* $0D - move cursor to start of line (carriage return)
Retrn    bsr   HideCrsr		hide cursor
         tfr   x,d		put cursor address in D
         andb  #$E0		place at start of line
         stb   <V.CrsAL,u	and save low cursor address
ShowCrsr ldx   <V.CrsrA,u 	get cursor address
         lda   ,x		get char at cursor position
         sta   <V.CChar,u 	save it
         lda   <V.CColr,u 	get cursor character
         beq   L014D		branch if none
L014B    sta   ,x		else turn on cursor
L014D    clrb  
         rts   

* $0A - cursor down (line feed)
CurDown  bsr   HideCrsr		hide cursor
         leax  <32,x		move X down one line
         cmpx  <V.ScrnE,u 	at end of screen?
         bcs   L0162		branch if not
         leax  <-32,x		else go back up one line
         pshs  x		save X
         bsr   SScrl		and scroll the screen
         puls  x		restore pointer
L0162    stx   <V.CrsrA,u 	save cursor pointer
         bra   ShowCrsr		show cursor

* $08 - cursor left
CurLeft  bsr   HideCrsr		hide cursor
         cmpx  <V.ScrnA,u 	compare against start of screen
         bls   L0173		ignore it if at the screen start
         leax  -$01,x		else back up one
         stx   <V.CrsrA,u 	save updated pointer
L0173    bra   ShowCrsr		and show cursor

* $06 - cursor right
CurRght  bsr   HideCrsr		hide cursor
         leax  $01,x		move to the right
         cmpx  <V.ScrnE,u 	compare against end of screen
         bcc   L0181		if past end, ignore it
         stx   <V.CrsrA,u 	else save updated pointer
L0181    bra   ShowCrsr		and show cursor

* $0B - erase to end of screen
ErEOScrn bsr   HideCrsr		kill the cusror
         bra   L0189		and clear rest of the screen

* $0C - clear screen
ClrScrn  bsr   CurHome		home cursor
L0189    lda   #$60		get default char
L018B    sta   ,x+		save at location
         cmpx  <V.ScrnE,u 	end of screen?
         bcs   L018B		branch if not
         bra   ShowCrsr		now show cursor

* $01 - home cursor
CurHome  bsr   HideCrsr		hide cursor
         ldx   <V.ScrnA,u $1D	get pointer to screen
         stx   <V.CrsrA,u $21	save as new cursor position
         bra   ShowCrsr		and show it

* Hides the cursor from the screen
* Exit: X = address of cursor
HideCrsr ldx   <V.CrsrA,u $21	get address of cursor in X
         lda   <V.CChar,u $23	get value of char under cursor
         sta   ,x		put char in place of cursor
         clrb  			must be here, in general, for [...] BRA HideCrsr
         rts   

* $05 XX - set cursor off/on/color per XX-32
Do05     ldb   #$01		need additional byte
         leax  <CrsrSw,pcr	
         bra   L01E5

CrsrSw   lda   <V.NChr2,u 	get next char
         suba  #C$SPAC		take out ASCII space
         bne   L01BB		branch if not zero
         sta   <V.CColr,u 	else save cursor color zero (no cursor)
         bra   HideCrsr		and hide cursor
L01BB    cmpa  #$0B		greater than $0B?
         bge   L014D		yep, just ignore byte
         cmpa  #$01		is it one?
         bgt   L01C7		branch if greater
         lda   #$AF		else get default blue cursor color
         bra   L01D7		and save cursor color
L01C7    cmpa  #$02		is it two?
         bgt   L01CF		branch if larger
         lda   #$A0		else get black cursor color
         bra   L01D7		and save it
** BUG ** BUG ** BUG ** BUG
L01CF    suba  #$03		** BUG FIXED! ** !!! Was SUBB
         lsla  			shift into upper nibble
         lsla  
         lsla  
         lsla  
         ora   #$8F
L01D7    sta   <V.CColr,u 	save new cursor
         ldx   <V.CrsrA,u 	get cursor address
         lbra  L014B		branch to save cursor in X

* $02 XX YY - move cursor to col XX-32, row YY-32
CurXY    ldb   #$02		we want to claim next two chars
         leax  <DoCurXY,pcr	point to processing routine
L01E5    stx   <V.RTAdd,u	store routine to return to
         stb   <V.NGChr,u	get two more chars
         clrb  
         rts   

DoCurXY  bsr   HideCrsr		hide cursor
         ldb   <V.NChr2,u 	get ASCII Y-pos
         subb  #C$SPAC		take out ASCII space
         lda   #32		go down
         mul   			multiply it
         addb  <V.NChar,u 	add in X-pos
         adca  #$00
         subd  #C$SPAC		take out another ASCII space
         addd  <V.ScrnA,u 	add top of screen address
         cmpd  <V.ScrnE,u 	at end of the screen?
         lbcc  L014D		exit if off the screen
         std   <V.CrsrA,u 	otherwise save new cursor address
         lbra  ShowCrsr		and show cursor

* $04 - erase to end of line
ErEOLine bsr   HideCrsr		hide cursor
         tfr   x,d		move current cursor position in D
         andb  #$1F		number of characters put on this line
         pshs  b
         ldb   #32
         subb  ,s+
         bra   L0223		and clear one line

* $03 - erase line
DelLine  lbsr  Retrn		do a CR
         ldb   #32		line length
L0223    lda   #$60		get default character
         ldx   <V.CrsrA,u 	get cursor address
L0228    sta   ,x+		fill screen line with 'space'
         decb  			decrement
         bne   L0228		and branch if not end
         lbra  ShowCrsr		else show cursor

* $09 - cursor up
CurUp    lbsr  HideCrsr		hide cursor
         leax  <-32,x		move X up one line
         cmpx  <V.ScrnA,u 	compare against start of screen
         bcs   L023E		branch if we went beyond
         stx   <V.CrsrA,u 	else store updated X
L023E    lbra  ShowCrsr		and show cursor

* $0E - switch screen to alphanumeric mode
DoAlpha  clra  
         clrb  
         jmp   [<V.DspVct,u]	display screen (routine in VTIO)

* GetStat
GetStat  ldx   PD.RGS,y		get caller's regs
         cmpa  #SS.AlfaS	AlfaS?
         beq   Rt.AlfaS		branch if so
         cmpa  #SS.Cursr	Cursr?
         beq   Rt.Cursr		branch if so

* SetStat
SetStat  comb  
         ldb   #E$UnkSvc
         rts   

* SS.AlfaS getstat
Rt.AlfaS ldd   <V.ScrnA,u 	memory address of buffer
         std   R$X,x		save in caller's X
         ldd   <V.CrsrA,u 	get cursor address
         std   R$Y,x		save in caller's Y
         lda   <V.Caps,u 	save caps lock status in A and exit
         bra   SaveA

* SS.Cursr getstat
Rt.Cursr ldd   <V.CrsrA,u	get address of cursor
         subd  <V.ScrnA,u	subtract screen address
         pshs  b,a		D now holds cursor position relative to screen
         clra  
         andb  #$1F
         addb  #$20		compute column position
         std   R$X,x		save column position to caller's X
         puls  b,a		then divide by 32
         lsra  
         rolb  
         rolb  
         rolb  
         rolb  
         clra  
         andb  #$0F		only 16 line to a screen
         addb  #$20
         std   R$Y,x		and save column to caller's Y
         ldb   <V.CFlag,u
         lda   <V.CChar,u	get character under cursor
         bmi   SaveA		if hi bit set, go on
         cmpa  #$60		VDG space?
         bcc   L02A5		branch if greater than
         cmpa  #$20		
         bcc   L02A9
         tstb 
         beq   L02A3
         cmpa  #$00
         bne   L029B
         lda   #$5E
         bra   SaveA		save it and exit

L029B    cmpa  #$1F
         bne   L02A3
         lda   #$5F
         bra   SaveA
L02A3    ora   #$20		turn it into ASCII from VDG codes
L02A5    eora  #$40
         bra   SaveA
L02A9    tstb  
         bne   SaveA
         cmpa  #$21		remap specific codes
         bne   L02B4
         lda   #$7C
         bra   SaveA
L02B4    cmpa  #$2D
         bne   SaveA
         lda   #$7E
SaveA    sta   R$A,x
         clrb  
         rts   

         emod
eom      equ   *
         end
