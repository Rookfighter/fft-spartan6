-- fft16_tb.vhd
--
-- Created on: 19 Jul 2017
--     Author: Fabian Meyer

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity fft16_tb is
end entity;

architecture behavioral of fft16_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component fft16
    generic(RSTDEF: std_logic := '0');
    port(rst:     in  std_logic; -- reset, RSTDEF active
         clk:     in  std_logic; -- clock, rising edge
         swrst:   in  std_logic; -- software reset, RSTDEF active
         en:      in  std_logic; -- enable, high active
         start:   in  std_logic; -- start FFT, high active
         set:     in  std_logic; -- load FFT with values, high active
         get:     in  std_logic; -- read FFT results, high active
         din:     in  complex;   -- datain for loading FFT
         done:    out std_logic; -- FFT is done, active high
         dout:    out complex);  -- data out for reading results
    end component;

    -- Clock period definitions
    constant clk_period: time := 10 ns;

    constant test_data: complex_arr(0 to 15) := (
        to_complex(0.0,0.0),
        to_complex(1.0,0.0),
        to_complex(2.0,0.0),
        to_complex(3.0,0.0),
        to_complex(4.0,0.0),
        to_complex(5.0,0.0),
        to_complex(6.0,0.0),
        to_complex(7.0,0.0),
        to_complex(8.0,0.0),
        to_complex(9.0,0.0),
        to_complex(10.0,0.0),
        to_complex(11.0,0.0),
        to_complex(12.0,0.0),
        to_complex(13.0,0.0),
        to_complex(14.0,0.0),
        to_complex(15.0,0.0)
    );

    -- Generics
    constant RSTDEF: std_logic := '0';

    -- Inputs
    signal rst:     std_logic := '0';
    signal clk:     std_logic := '0';
    signal swrst:   std_logic := '0';
    signal en:      std_logic := '0';
    signal start:   std_logic := '0';
    signal set:     std_logic := '0';
    signal get:     std_logic := '0';
    signal din:     complex := COMPZERO;

    -- Outputs
    signal done:  std_logic := '0';
    signal dout:  complex := COMPZERO;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: fft16
        generic map(RSTDEF => RSTDEF)
        port map(rst     => rst,
                 clk     => clk,
                 swrst   => swrst,
                 en      => en,
                 start   => start,
                 set     => set,
                 get     => get,
                 din     => din,
                 done    => done,
                 dout    => dout);

    -- Clock process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        wait for clk_period*10;

        rst <= '1';
        swrst <= '1';
        en <= '1';

        -- load data into FFT
        -- send set signal
        set <= '1';
        din <= test_data(0);
        wait for clk_period;
        set <= '0';

        for i in 1 to 15 loop
            din <= test_data(i);
            wait for clk_period;
        end loop;

        -- wait one extra cycle until data is stored to memory
        wait for clk_period;

        -- compute FFT
        start <= '1';
        wait for clk_period;
        start <= '0';

        wait for 50*clk_period;

        -- get results
        get <= '1';
        wait for clk_period;
        get <= '0';

        wait for 15*clk_period;

        wait;
    end process;

end;
