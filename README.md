# Disclaimer

I am no expert, still a student, learning about VHDL and working with FPGAs.
This I2C implementation may
lack some things, and there are no guarantees whatsoever.
The I2C has been tested in both simulation and on FPGA,
but it still might contain many bugs.

# Synthesizable I2C implementation in VHDL

This repository contains synthesizable implementation of i2c
communication protocol in vhdl.
It supports both master and slave.

## Testing

There are simulation files with various scenarios and
testing.

Tests have also been conducted on an FPGA after simulation
tests have been passing. There were two scenarios tested
for slave, and one for master so far.

### Simulation tooling
For simulation, VUnit has been used both as a script
to run the testbenches, and as a library that contains
utility, log functions for easier testing.

### Slave scenarios
There have been to scenarios for testing the slave.
It has been tested with a help of a microcontroller,
specifically Tiva-C, but the tests should be portable
to any ARM microcontroller quite easily. Rust has been
used to write the programs. The programs are located in
`mcu_tests` subfolder.

#### Counter
The top level design inside of `mcu_slave` library
called `counter` is a simple test scenario for
testing the slave.
It will react only to read commands, and
send back inrementing sequence of numbers,
resetting at 100.

There is a code for Tiva-C ARM microcontroller
located at `mcu_tests/slave_counter`
that will start reading by five bytes and
report the values to user via semihosting.

#### "EEPROM" behavior
There is a top level design called `regs` inside
of the `mcu_slave` library. This design tries
to behave as an EEPROM would. It contains only
twenty registers to write into.

The master should at first trigger a write,
that should include the address to start
writing to or reading from. Then sequence
of writes or reads should follow.

If there is a sequence of writes, the
values will be written to the memory.
Starting with the address received as first
byte, and incrementing the address by one byte
for every byte written.

For sequence of reads, values are read
starting from the address received first,
and incremented by one byte for every
byte read.

There is a code for Tiva-C ARM microcontroller
located at `mcu_tests/slave_regs`
that will send data to the memory, and
report the values to user via semihosting.

### Master scenarios

Only one scenario has been tested with
the master implementation. That is with SSD1306
128x64 display. In the `ssd1306` library there
is `counter` design entity. This entity will
count to 1000, and display the current value on SSD1306
display.

The display is initialized at first, and then every
half a second the numbers are sent to the display
to render. The numbers were obtained from
this font [https://github.com/dhepper/font8x8].
