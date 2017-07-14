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
    port(din1:  in  complex;  -- first complex in val
         din2:  in  complex;  -- second complex in val
         w:     in  complex;  -- complex phasor (rotation vector)
         dout1: out complex;  -- first complex out val
         dout2: out complex); -- second complex out val
end butterfly;

architecture behavioral of butterfly is
begin

    -- butterfly operation:
    -- dout1 = din1 + din2 * W
    -- dout2 = din1 - din2 * W
    dout1 <= add(din1, mult(din2, w));
    dout2 <= sub(din1, mult(din2, w));

end behavioral;
