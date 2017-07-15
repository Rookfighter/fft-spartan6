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
    port(rst:   in  std_logic; -- reset, RSTDEF active
         clk:   in  std_logic; -- clock, rising edge
         mode:  in  std_logic; -- mode, '0' passthrough; '1' butterfly
         din1:  in  complex;   -- first complex in val
         din2:  in  complex;   -- second complex in val
         w:     in  complex;   -- complex phasor, twiddle factor
         dout1: out complex;   -- first complex out val
         dout2: out complex);  -- second complex out val
end butterfly;

architecture behavioral of butterfly is
begin

    process(rst, clk) is
        variable din2w: complex := COMPZERO;
    begin
        if rst = RSTDEF then
            dout1 <= din1;
            dout2 <= din2;
        elsif rising_edge(clk) then
            if mode = '1' then
                -- butterfly operation
                -- dout1 = din1 + w * din2
                -- dout2 = din1 - w * din2
                din2w := mult(din2, w);
                dout1 <= add(din1, din2w);
                dout2 <= sub(din1, din2w);
            else
                dout1 <= din1;
                dout2 <= din2;
            end if;
        end if;
    end process;

end behavioral;
