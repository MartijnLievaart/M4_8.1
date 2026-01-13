;
START:
	LD HL,STRINGDATA
	LD SP,0xffff
	JSR PRINT
	HLT
;
; HL points to string to print
PRINT:
	LD	A,(HL)
	TST	A,0
	JZ	RET
	LD	(0x0400),A
	CCLR
	LD	A,L
	ADD     A,1
	LD	L,A
	JNC	PRINT
	LD	A,H
	ADD	A,0
	LD	H,A
	JMP	PRINT
RET:
	RET

;
STRINGDATA:
DATA "Hellorld" 10 0


