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
use ieee.std_logic_1164.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

-- declare package with helper functions for FFT
package fft_helpers is

    -- define decimal and fractional length of fixed point numbers
    constant DECLEN := 12;
    constant FRACLEN := 12;

    -- define complex number datatype, which will make the code more readable
    type complex is
        record
            r: sfixed(DECLEN downto -FRACLEN);
            i: sfixed(DECLEN downto -FRACLEN);
        end record;

    type comp_array is array (0 to 7) of complex;
    type comp_array2 is array (0 to 3) of complex;

    -- Adds two complex numbers
    function add (n1,n2: complex) return complex;
    -- Subtracts two complex numbers
    function sub (n1,n2: complex) return complex;
    -- Multiplies two complex numbers
    function mult (n1,n2: complex) return complex;

end fft_helpers;

package body fft_helpers is

    function add (n1,n2: complex) return complex is
        variable sum: complex;
    begin
        -- simply use fixed point arithmetic addition
        sum.r := n1.r + n2.r;
        sum.i := n1.i + n2.i;
        return sum;
    end add;

    --subtraction of complex numbers.
    function sub(n1,n2 : complex) return complex is
        variable diff : complex;
    begin
        -- simply use fixed point arithmetic subtraction
        diff.r:=n1.r - n2.r;
        diff.i:=n1.i - n2.i;
        return diff;
    end sub;

    --multiplication of complex numbers.
    function mult(n1,n2 : complex) return complex is
        variable prod : complex;
    begin
        -- complex multiplication: A + jB * C + jD
        -- can be calculated as
        -- (A*C) - (B*D) + j((A*D) + (B*C))
        prod.r:=(n1.r * n2.r) - (n1.i * n2.i);
        prod.i:=(n1.r * n2.i) + (n1.i * n2.r);
        return prod;
    end mult;

end fft_helpers;
