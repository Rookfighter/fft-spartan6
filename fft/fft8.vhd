-- fft8.vhd
--
-- Created on: 13 Jul 2017
--     Author: Fabian Meyer
--
-- Implementation of 8-Point FFT using radix-2 single path delay feedback
-- architecture for pipelining.

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
        port(mode:  in  std_logic; -- mode, '0' passthrough; '1' butterfly
             din1:  in  complex;   -- first complex in val
             din2:  in  complex;   -- second complex in val
             dout1: out complex;   -- first complex out val
             dout2: out complex);  -- second complex out val
    end component;

    -- import phasor component
    component phasor is
        generic(RSTDEF: std_logic := '0');
        port(rst:  in  std_logic; -- reset, RSTDEF active
             clk:  in  std_logic; -- clock, rising edge
             din:  in  complex;   -- complex in val
             w:    in  complex;   -- twiddle factor
             dout: out complex);  -- complex out val
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
    constant w: complex_arr(0 to N-1) := (
        to_complex(1.0, 0.0),
        to_complex(0.7071, -0.7071),
        to_complex(0.0, -1.0),
        to_complex(-0.7071, -0.7071),
        to_complex(1.0, 0.0),
        to_complex(0.7071, -0.7071),
        to_complex(0.0, -1.0),
        to_complex(-0.7071, -0.7071));

    signal bfout1: complex_arr(0 to N-1) := (others => COMPZERO);
    signal bfout2: complex_arr(0 to N-1) := (others => COMPZERO);

    signal bfin1: complex_arr(0 to N-1) := (others => COMPZERO);
    signal bfin2: complex_arr(0 to N-1) := (others => COMPZERO);

begin

    bfin2(0) <= din;
    dout     <= bfout1(N-1);

    gen1: for i in 0 to N-2 generate
        -- generate delay elements
        -- these are feedback connected with butterfly i
        -- bf output maps to delay input; delay output maps to bf input
        del: delay
        generic map(RSTDEF   => RSTDEF,
                    DELAYLEN => N-i-1)
        port map(rst  => rst,
                 clk  => clk,
                 din  => bfout2(i),
                 dout => bfin1(i));

        -- generate phasor elements
        -- multiply twiddle factor with butterfly output
        -- in sync with clock
        -- output is input of butterfly i+1
        phas: phasor
        generic map(RSTDEF   => RSTDEF)
        port map(rst  => rst,
                 clk  => clk,
                 w    => w(i),
                 din  => bfout2(i),
                 dout => bfin2(i+1));
    end generate;

    gen2: for i in 0 to N-1 generate
        bf: butterfly
        port map(mode  => '1',
                 din1  => bfin1(i),
                 din2  => bfin2(i),
                 dout1 => bfout1(i),
                 dout2 => bfout2(i));
    end generate;

    -- last bf has no delay element for bfin1
    -- delay its output by one clock cycle
    process(rst, clk)
    begin
        if rst = RSTDEF then
            bfin1(N-1) <= COMPZERO;
        elsif rising_edge(clk) then
            bfin1(N-1) <= bfout2(N-1);
        end if;
    end process;

end behavioral;
