# FFT for Xilinx Spartan 6 FPGA

This repo contains an FFT implementation for the Xilinx Spartan 6 FPGA. This is
a project for the *Advanced Embedded Systems Lab* in SS 17 of the
Albert-Ludwigs Universität Freiburg.

Compilation and synthezing of VHDL code is done with *Xilinx ISE 14.7*.

## Project install

To add the ISE project for the FPGA execute the following steps in ISE:

* click on *File > New Project*
* select location as ```<path-to-repo>```
* enter the name of the project as ```fft```
* select the following parameters

| Key                | Value    |
|--------------------|----------|
| Family             | Spartan6 |
| Device             | XC6SLX45 |
| Package            | FGG676   |
| Speed              | -3       |
| Synthesis Tool     | XST      |
| Simulator          | ISim     |
| Preferred Language | VHDL     |

* click *finish*

## Project structure

```fft/```

* contains VHDL files for implementing a 16-Point FFT and I2C slave
* contains testbenches for the different components

---

```c-src/```

* contains C code for I2C master application
* sends a sinus signal over I2C and waits to receive the result in frequency domain

---

```scripts/```

* some Python helper scripts
* ```twiddle.py``` generates twiddle factors for different FFTs
* ```sin_gen.py``` generates sinus signals that can be used to test FFT

### VHDL components

**fft_helpers**

* package that implements complex arithmetic (add, sub, mult)
* uses fixed point numbers for imaginary and real part
* defines fractional and decimal length of numbers

---

**tf16**

* twiddle factor ROM for 16-Point FFT

---

**membank**

* implements 2 port memory bank
* can either read or write 2 values at the same time clock synchronous

---

**butterfly**

* implements butterfly operation

---

**address generator**

* generates read and write addresses for memory banks during FFT
* generate write enables for memory banks during FFT
* generates address / index of twiddle factor during FFT
* calculation depend on butterfly number (bfno) within current stage of FFT and the current stage itself (lvl)

---

**fft16**

* integrates all components to realize 16-point FFT
* 2 membanks, 1 tf16, 1 addr_gen, 1 butterfly are used
* implements pipeline timing
* implements bit reversed read from input values

### VHDL testbenches

**fft16_tb**

* testbench to test timing of pipeline
* test setting initial values in bit reversed order and getting results from FFT

**fft16_tb2**

* automated testbench
* calculates FFT of simple sinus signal and prints result as hex numbers to console
