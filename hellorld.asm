	NOP
START:
	LD A,'H'
	LD (0x0400),A
	LD A,'e'
	LD (0x0400),A
	LD A,'l'
	LD (0x0400),A
	LD A,'l'
	LD (0x0400),A
	LD A,'o'
	LD (0x0400),A
	LD A,'r'
	LD (0x0400),A
	LD A,'l'
	LD (0x0400),A
	LD A,'d'
	LD (0x0400),A
	JMP START
