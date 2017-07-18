-- butterfly.vhd
--
-- Created on: 13 Jul 2017
--     Author: Fabian Meyer
--
-- Butterfly component for the FFT.

library ieee;
library work;

use ieee.std_logic_1164.all;
use work.fft_helpers.all;

entity butterfly is
    generic(RSTDEF: std_logic := '0');
    port(rst:   in std_logic;  -- reset, RSTDEF active
         clk:   in std_logic;  -- clock, rising edge
         swrst: in std_logic;  -- software reset, RSTDEF active
         en:    in std_logic;  -- enable, high active
         din1:  in  complex;   -- first complex in val
         din2:  in  complex;   -- second complex in val
         w:     in  complex;   -- twiddle factor
         dout1: out complex;   -- first complex out val
         dout2: out complex);  -- second complex out val
end butterfly;

architecture behavioral of butterfly is
begin

    process(rst, clk) is
        variable tmp: complex := COMPZERO;
    begin
        if rst = RSTDEF then
            dout1 <= COMPZERO;
            dout2 <= COMPZERO;
        elsif rising_edge(clk) then
            if swrst = RSTDEF then
                dout1 <= COMPZERO;
                dout2 <= COMPZERO;
            elsif en = '1' then
                -- do butterfly Operation
                -- dout1 = din1 + w * din2
                -- dout2 = din1 - w * din2
                tmp := mult(w, din2);
                dout1 <= add(din1, tmp);
                dout2 <= sub(din1, tmp);
            end if;
        end if;
    end process;

end behavioral;
