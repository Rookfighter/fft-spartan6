-- fft8.vhd
--
-- Created on: 14 Jul 2017
--     Author: Fabian Meyer
--
-- Basic implementation for fix point arithemtic.

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fix_nums is
    -- type for fixed point number
    subtype fixnum is std_logic_vector;

    -- add two fixed-point numbers
    function add(a,b: fixnum) return fixnum;
    -- subtract two fixed-point numbers
    function sub(a,b: fixnum) return fixnum;
    -- multiply two fixed-point numbers
    function mult(a,b: fixnum) return fixnum;
end fix_nums;

package body fix_nums is

    function add(a,b: fixnum) return fixnum is
    begin
        return fixnum(signed(a) + signed(b));
    end;

    function sub(a,b: fixnum) return fixnum is
    begin
        return fixnum(signed(a) - signed(b));
    end;

    function mult(a,b: fixnum) return fixnum is
    begin
        return fixnum(signed(a) * signed(b));
    end;

end fix_nums;
