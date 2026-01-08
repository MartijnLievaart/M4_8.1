;
; Note, a lot already has to work for the selftest to work.
; However, if that base works, this can test the rest.
;

START:
	LD SP,0xffff

        LD A,'S'
        LD 0x0400,A
        LD A,'e'
        LD 0x0400,A
        LD A,'l'
        LD 0x0400,A
        LD A,'f'
        LD 0x0400,A
        LD A,'t'
        LD 0x0400,A
        LD A,'e'
        LD 0x0400,A
        LD A,'s'
        LD 0x0400,A
        LD A,'t'
        LD 0x0400,A
        LD A,10
        LD 0x0400,A


        LD A,'J'
        LD 0x0400,A
        LD A,'M'
        LD 0x0400,A
        LD A,'P'
        LD 0x0400,A
        LD A,' '
        LD 0x0400,A
	JMP TSTJMP
        LD A,'N'
        LD 0x0400,A
        LD A,'O'
        LD 0x0400,A
        LD A,'K'
        LD 0x0400,A
	HLT

TSTJMP:
        LD A,'O'
        LD 0x0400,A
        LD A,'K'
        LD 0x0400,A
        LD A,10
        LD 0x0400,A


        LD A,'J'
        LD 0x0400,A
        LD A,'S'
        LD 0x0400,A
        LD A,'R'
        LD 0x0400,A
        LD A,' '
        LD 0x0400,A
	JSR TSTJSR
        LD A,'O'
        LD 0x0400,A
        LD A,'K'
        LD 0x0400,A
        LD A,10
        LD 0x0400,A
	JMP OK

TSTJSR:
        LD A,'O'
        LD 0x0400,A
        LD A,'K'
        LD 0x0400,A
        LD A,10
        LD 0x0400,A
        LD A,'R'
        LD 0x0400,A
        LD A,'E'
        LD 0x0400,A
        LD A,'T'
        LD 0x0400,A
        LD A,' '
        LD 0x0400,A
	RET

; If this text prints OK, JSR works
;	LD	HL,TXTSUB
;	JSR	PRINT
; If we arive here, the RET worked.
;	LD	HL,TXTRET
;	JSR	PRINT

OK:

	LD	HL,TXTALLOK
	JSR	PRINT
	HLT
	JMP	START
;
; HL points to string to print
PRINT:
;HLT
	LD	A,(HL)
	TST	A,0
	JZ	PRINT_RET
	LD	0x0400,A
	CCLR
	LD	A,L
	ADD     A,1
	LD	L,A
	JNC	PRINT
	LD	A,H
	ADD	A,0
	LD	H,A
	JMP	PRINT
PRINT_RET:
	RET
;FILLER:
;	DATA "XXXXXXX"
;
TXTALLOK:
	DATA "All tests passed" 10 0

