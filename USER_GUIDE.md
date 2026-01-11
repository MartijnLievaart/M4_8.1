# M4_8.1 a 8 bit CPU: User guide.

The CPU has an 8 bit databus, a 16 bit addressbus and a mix of 8 and 16 bit registers.

## User visible registers

The following registers are available for the user:

### A (8 bit)

The general purpose do it all register. All ALU operations use this register as input and store their result here.

### B (8 bit)

The helper. Can be used as second argument for the ALU or as an extra general purpose register.

### HL (16 bit), H+L (2x8 bit)

The primary purpose of this register is to do indirect addressing. It can also be used as two general 8 bit registers.

### PC (16 bit)

The program counter. Starts at 0 at a reset.

### SP (16 bit)

The stack pointer. The stack grows down. Needs to be initialised by the user. Customary set to 0xFFFF

### S (8 bit, 2 bits used)

The status register. Houses the Carry (C) and Zero (Z) bits

## ALU

The 8 bit ALU uses register A as its first input, the second input (if needed) can be the B register or a constant. It implements the following instructions:

### Two operand

* ADD
* SUB
* AND
* OR
* XOR

### One operand

* INV
* SHL
* SHR

## Reset

On reset the program counter is set to 0x0000 and starts executing from there. All other registers are not reset and must be initialised by the user. (Logisim sets the registers to 0, but you should not rely on that).

If we ever implement interupts, we probably will implement a reset vector instead of starting from 0x0000, which will mean you will need to reassemble your program at that point.


