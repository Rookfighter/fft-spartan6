-- phasor.vhd
--
-- Created on: 15 Jul 2017
--     Author: Fabian Meyer
--
-- Implements phasor which multiplies butterfy output with twiddle
-- factor.

library ieee;
library work;

use ieee.std_logic_1164.all;
use work.fft_helpers.all;

entity phasor is
    generic(RSTDEF: std_logic := '0');
    port(rst:  in  std_logic; -- reset, RSTDEF active
         clk:  in  std_logic; -- clock, rising edge
         din:  in  complex;   -- complex in val
         w:    in  complex;   -- twiddle factor
         dout: out complex);  -- complex out val
end phasor;

architecture behavioral of phasor is
    signal tmp: complex := COMPZERO;
begin

    dout <= tmp;

    process(rst, clk) is
    begin
        if rst = RSTDEF then
            tmp <= COMPZERO;
        elsif rising_edge(clk) then
            -- multiply input with twiddle factor
            -- clock synchronous
            tmp <= mult(din, w);
        end if;
    end process;

end behavioral;
