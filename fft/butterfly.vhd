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
    port(mode:  in  std_logic; -- mode, '0' passthrough; '1' butterfly
         din1:  in  complex;   -- first complex in val
         din2:  in  complex;   -- second complex in val
         dout1: out complex;   -- first complex out val
         dout2: out complex);  -- second complex out val
end butterfly;

architecture behavioral of butterfly is
begin

    -- simply add / subtract both inputs, because
    -- complex phasor was already applied beforehands
    dout1 <= add(din1, din2) when mode = '1' else din1;
    dout2 <= sub(din1, din2) when mode = '1' else din2;

end behavioral;
