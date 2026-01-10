# M4_8.1 - A simple 8 bit CPU

This is a definition for a simple 8 bit CPU build in Logisim Evolution. You can write programs for it in assembler and run them in the simulater.

## Quick start

* Select an assembler file you want to run and compile it with ./asm.pl.
* Load the .circ file in Logisim evolution.
* Find the boot rom in the circuit and load the file image.img.
* Start the simulation and start the clock
* Select the hand icon and press the 'Run' button in the circuit (under the hex displays).

## Philosopy

I wanted to do something fun with old 8 bit logic. I decided to build my own 8 bit CPU. At first in a siimulator, and who knows, maybe later in real TTL hardware?

I decided the following would apply:

### Era appropriate

Use only 70s technoligy. Do note I don't have to abide by the same constraints as from that area, in particular I make use of large ROMs to implement functionality.

### As simple as needed, but not simpler.

* No fancy instructions that can also be done with a few already existing instructions.
* Should be a full fledged processor capable of doing the same as other 8 bit processors from the ERA.

## Simulator limitations/differences

Using a simulator depends on how good the simulator is. Logisim evolution is quite good, but it does suffer some limitations:

### Idealized generic components

I make heavy use of the generic components of Logisim evolution. These should be replaced by "real" TTL components at some point in the future.

### Race conditions

Logisim is not good at recognizing race conditions, so there may be race conditions in the design.

### Undefined states

Logisim applies an undefined state when it detects it cannot initialize a circular dependency. In reality, this would result in a random result, whcih sometimes is not inapproriate, sometimes you do not care about the initial value.

However, sometimes you do, so it's good Logisim flags this. It means we have to work with this even if we don't care about the initial state. In the end, that means I use predefined flip-flops (which do not suffer from this) instead of simpler hand build circuits in some places, especially the clock logic.


