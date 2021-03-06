-- fft_helpers.vhd
--
-- Created on: 13 Jul 2017
--     Author: Fabian Meyer
--
-- This package provides a complex datatype and associated helper functions
-- for easier computation of a FFT. Operations are implemented using fixed
-- point arithmetic.
--
-- This code is mostly based on the sample provided by vapin, but made
-- synthesisable
-- http://vhdlguru.blogspot.de/2011/06/non-synthesisable-vhdl-code-for-8-point.html

library ieee;
library ieee_proposed;

use ieee.std_logic_1164.all;
use ieee_proposed.fixed_pkg.all;
use ieee.numeric_std.all;

-- declare package with helper functions for FFT
package fft_helpers is

    -- define decimal and fractional length of fixed point numbers
    constant DECLEN:  natural := 16;
    constant FRACLEN: natural := 8;
    constant FIXLEN: natural := DECLEN + FRACLEN;
    constant FIXZERO: signed(DECLEN+FRACLEN-1 downto 0) := (others => '0');

    -- define complex number datatype, which will make the code more readable
    type complex is
        record
            r: signed(DECLEN+FRACLEN-1 downto 0);
            i: signed(DECLEN+FRACLEN-1 downto 0);
        end record;

    constant COMPZERO: complex := (FIXZERO, FIXZERO);

    -- array type for complex numbers
    type complex_arr is array (natural range <>) of complex;

    -- Adds two complex numbers
    function add (n1,n2: complex) return complex;
    -- Subtracts two complex numbers
    function sub (n1,n2: complex) return complex;
    -- Multiplies two complex numbers
    function mult (n1,n2: complex) return complex;
    -- converts two real numbers into a complex
    function to_complex(r,i: real) return complex;

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
        -- variable ac: signed(DECLEN+FRACLEN-1 downto 0);
        -- variable bd: signed(DECLEN+FRACLEN-1 downto 0);
        variable res: complex;
    begin
        -- complex multiplication: A + jB * C + jD
        -- can be calculated as
        -- re: (A*C) - (B*D)
        -- im: (A*D) + (B*C)
        res.r := resize(resize(n1.r * n2.r, DECLEN+FRACLEN) -
                        resize(n1.i * n2.i, DECLEN+FRACLEN),
                        DECLEN+FRACLEN);
        res.i := resize(resize(n1.r * n2.i, DECLEN+FRACLEN) +
                        resize(n1.i * n2.r, DECLEN+FRACLEN),
                        DECLEN+FRACLEN);

        -- complex multiplication: A + jB * C + jD
        -- can be calculated as
        -- re: (A*C) - (B*D)
        -- im: (A+B) * (C+D) - (A*C) - (B*D)
        -- ac := resize(n1.r * n2.r, DECLEN+FRACLEN);
        -- bd := resize(n1.i * n2.i, DECLEN+FRACLEN);
        --
        -- res.r := resize(ac - bd, DECLEN+FRACLEN);
        -- res.i := resize(
        --     resize(
        --         resize(
        --             resize(n1.r + n1.i, DECLEN+FRACLEN) *
        --             resize(n2.r + n2.i, DECLEN+FRACLEN),
        --             DECLEN+FRACLEN) -
        --         ac, DECLEN+FRACLEN) -
        --     bd, DECLEN+FRACLEN);

        return res;
    end mult;

    function to_complex(r,i: real) return complex is
        variable res: complex;
    begin
        res.r := signed(to_slv(to_sfixed(r, DECLEN-1, -FRACLEN)));
        res.i := signed(to_slv(to_sfixed(i, DECLEN-1, -FRACLEN)));
        return res;
    end;

end fft_helpers;
