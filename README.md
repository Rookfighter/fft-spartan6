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
