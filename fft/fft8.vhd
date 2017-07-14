-- fft8.vhd
--
-- Created on: 13 Jul 2017
--     Author: Fabian Meyer
--
-- Implementation of 8-Point FFT.

library ieee;
library work;

use ieee.std_logic_1164.all;
use work.fft_helpers.all;

entity fft8 is
    port(x: in  val_arr_fft8;   --input signals in time domain
         y: out val_arr_fft8); --output signals in frequency domain
end fft8;

architecture behavioral of fft8 is
    -- import butterfly component
    component butterfly is
        port(din1:  in  complex;  -- first complex in val
             din2:  in  complex;  -- second complex in val
             w:     in  complex;  -- complex phasor (rotation vector)
             dout1: out complex;  -- first complex out val
             dout2: out complex); -- second complex out val
    end component;

    signal g1: val_arr_fft8 := (others => COMPZERO);
    signal g2: val_arr_fft8 := (others => COMPZERO);

    -- complex phasor W_N = e**(-j*2*pi/N)
    -- W_N**i = cos(2*pi*i/N) - j*sin(2*pi*i/N)
    --
    -- (1.0,0.0), (0.7071,-0.7071), (0.0,-1.0), (-0.7071,-0.7071)
    constant w: phas_arr_fft8 := (
        (COMPZERO),
        (COMPZERO),
        (COMPZERO),
        (COMPZERO));

begin
    --first stage of butterfly's.
    bf11: butterfly port map(x(0),x(4),w(0),g1(0),g1(1));
    bf12: butterfly port map(x(2),x(6),w(0),g1(2),g1(3));
    bf13: butterfly port map(x(1),x(5),w(0),g1(4),g1(5));
    bf14: butterfly port map(x(3),x(7),w(0),g1(6),g1(7));

    --second stage of butterfly's.
    bf21: butterfly port map(g1(0),g1(2),w(0),g2(0),g2(2));
    bf22: butterfly port map(g1(1),g1(3),w(2),g2(1),g2(3));
    bf23: butterfly port map(g1(4),g1(6),w(0),g2(4),g2(6));
    bf24: butterfly port map(g1(5),g1(7),w(2),g2(5),g2(7));

    --third stage of butterfly's.
    bf31: butterfly port map(g2(0),g2(4),w(0),y(0),y(4));
    bf32: butterfly port map(g2(1),g2(5),w(1),y(1),y(5));
    bf33: butterfly port map(g2(2),g2(6),w(2),y(2),y(6));
    bf34: butterfly port map(g2(3),g2(7),w(3),y(3),y(7));

end behavioral;
