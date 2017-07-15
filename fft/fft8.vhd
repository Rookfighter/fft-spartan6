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
    generic(RSTDEF: std_logic := '0');
    port(rst:  in  std_logic; -- reset, RSTDEF active
         clk:  in  std_logic; -- clk, rising edge
         din:  in  complex;   -- din, input value
         dout: out complex);  -- dout, output value
end fft8;

architecture behavioral of fft8 is
    -- define that this is a N-point FFT
    constant N: natural := 8;

    -- import butterfly component
    component butterfly is
        generic(RSTDEF: std_logic := '0');
        port(rst:   in  std_logic; -- reset, RSTDEF active
             clk:   in  std_logic; -- clock, rising edge
             mode:  in  std_logic; -- mode, '0' passthrough; '1' butterfly
             din1:  in  complex;   -- first complex in val
             din2:  in  complex;   -- second complex in val
             w:     in  complex;   -- complex phasor, twiddle factor
             dout1: out complex;   -- first complex out val
             dout2: out complex);  -- second complex out val
    end component;

    -- import delay component
    component delay is
        generic(RSTDEF:   std_logic := '0';
                DELAYLEN: natural   := 8);  -- can hold 2**DELAYLEN data samples
        port(rst:  in  std_logic; -- reset , RSTDEF active
             clk:  in  std_logic; -- clk, rising edge
             din:  in  complex;   -- data in
             dout: out complex);  -- data out
    end component;

    -- complex phasor W_N = e**(-j*2*pi/N)
    -- W_N**i = cos(2*pi*i/N) - j*sin(2*pi*i/N)
    --
    -- (1.0,0.0), (0.7071,-0.7071), (0.0,-1.0), (-0.7071,-0.7071)
    type w_arr is array(0 to N-1) of complex;
    constant w: w_arr := (
        to_complex(1.0, 0.0),
        to_complex(0.7071, -0.7071),
        to_complex(0.0, -1.0),
        to_complex(-0.7071, -0.7071));

    signal bf2dl: complex_arr(0 to N-1) := (others => COMPZERO);

    signal bfin1: complex_arr(0 to N-1) := (others => COMPZERO);
    signal bfin2: complex_arr(0 to N-1) := (others => COMPZERO);

begin

    gen1: for i in 0 to N-2 generate
        del: delay
        generic map(RSTDEF   => RSTDEF,
                    DELAYLEN => N-i-1)
        port map(rst  => rst,
                 clk  => clk,
                 din  => bf2dl(i),
                 dout => bfin1(i));
     end generate;

     gen2: for i in 0 to N-1 generate
         bf: butterfly
         generic map(RSTDEF => RSTDEF);
         port(rst   => rst,
              clk   => clk,
              mode  => '1',
              din1  => bfin1(i),
              din2  => bfin2(i),
              w     => w(i),
              dout1 => bfin2(i+1),
              dout2 => bf2dl(i));
      end generate;
end behavioral;
