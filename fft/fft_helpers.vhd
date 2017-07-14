-- fft_helpers.vhd
--
-- Created on: 13 Jul 2017
--     Author: Fabian Meyer
--
-- This package provides a complex datatype and associated helper functions
-- for easier computation of a FFT. Operations are implemented using fixed
-- point arithmetic (ieee_proposed.fixed_pkg).
--
-- This code is mostly based on the sample provided by vapin, but made
-- synthesisable
-- http://vhdlguru.blogspot.de/2011/06/non-synthesisable-vhdl-code-for-8-point.html

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- declare package with helper functions for FFT
package fft_helpers is

    -- define decimal and fractional length of fixed point numbers
    constant DECLEN:  natural := 12;
    constant FRACLEN: natural := 12;
    constant FIXZERO: signed(DECLEN+FRACLEN-1 downto 0) := (others => '0');

    -- define complex number datatype, which will make the code more readable
    type complex is
        record
            r: signed(DECLEN+FRACLEN-1 downto 0);
            i: signed(DECLEN+FRACLEN-1 downto 0);
        end record;

    constant COMPZERO: complex := (FIXZERO, FIXZERO);

    type val_arr_fft8 is array (0 to 7) of complex;
    type phas_arr_fft8 is array (0 to 3) of complex;

    -- Adds two complex numbers
    function add (n1,n2: complex) return complex;
    -- Subtracts two complex numbers
    function sub (n1,n2: complex) return complex;
    -- Multiplies two complex numbers
    function mult (n1,n2: complex) return complex;

    function to_complex(r,i: std_logic_vector) return complex;

end fft_helpers;

package body fft_helpers is

    function add (n1,n2: complex) return complex is
        variable res: complex;
    begin
        -- simply use fixed point arithmetic addition
        res.r := resize(n1.r + n2.r, DECLEN+FRACLEN);
        res.i := resize(n1.i + n2.i, DECLEN+FRACLEN);
        return res;
    end add;

    --subtraction of complex numbers.
    function sub(n1,n2: complex) return complex is
        variable res: complex;
    begin
        -- simply use fixed point arithmetic subtraction
        res.r := resize(n1.r - n2.r, DECLEN+FRACLEN);
        res.i := resize(n1.i - n2.i, DECLEN+FRACLEN);
        return res;
    end sub;

    --multiplication of complex numbers.
    function mult(n1,n2: complex) return complex is
        variable res: complex;
    begin
        -- complex multiplication: A + jB * C + jD
        -- can be calculated as
        -- re: (A*C) - (B*D)
        -- im: (A*D) + (B*C)
        res.r := resize((n1.r * n2.r) - (n1.i * n2.i), DECLEN+FRACLEN);
        res.i := resize((n1.r * n2.i) + (n1.i * n2.r), DECLEN+FRACLEN);
        return res;
    end mult;

    function to_complex(r,i: std_logic_vector) return complex is
        variable res: complex;
    begin
        res.r := signed(r);
        res.i := signed(i);
        return res;
    end;

end fft_helpers;
