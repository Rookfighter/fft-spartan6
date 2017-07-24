-- fft16_tb.vhd
--
-- Created on: 19 Jul 2017
--     Author: Fabian Meyer
--
-- This testbench simulates a 16-Point FFT automatically. It prints out the
-- result value in hex numbers and asserts the results.

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity fft16_tb2 is
end entity;

architecture behavioral of fft16_tb2 is

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

    -- simple sinus with fractional part cut-off
    -- Parameters: a=10000, f=1Hz, fs=16Hz
    constant test_data1: complex_arr(0 to 15) := (
        to_complex(0.0, 0.0),
        to_complex(3826.0, 0.0),
        to_complex(7071.0, 0.0),
        to_complex(9238.0, 0.0),
        to_complex(10000.0, 0.0),
        to_complex(9238.0, 0.0),
        to_complex(7071.0, 0.0),
        to_complex(3826.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(-3826.0, 0.0),
        to_complex(-7071.0, 0.0),
        to_complex(-9238.0, 0.0),
        to_complex(-10000.0, 0.0),
        to_complex(-9238.0, 0.0),
        to_complex(-7071.0, 0.0),
        to_complex(-3826.0, 0.0)
    );

    -- calculated using online FFT calculator
    -- https://sooeet.com/math/online-fft-calculator.php
    --
    -- Settings:
    -- Program data:        constant y = 1
    -- Window function:     No window
    -- Number of samples:   16 (2^4)
    -- Y-axis magnitude:    Real
    -- User data samples:   0.0 3826.0 7071.0 9238.0 10000.0 9238.0 7071.0
    --                      3826.0 0.0 -3826.0 -7071.0 -9238.0 -10000.0 -9238.0
    --                      -7071.0 -3826.0
    constant result_data1: complex_arr(0 to 15) := (
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(16.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0),
        to_complex(0.0, 0.0)
    );

    signal test_data: complex_arr(0 to 15);
    signal result_data: complex_arr(0 to 15);

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

    signal dout_results: complex_arr(0 to 15) := (others => COMPZERO);
    signal hlt: std_logic := '0';

    -- convert an unsigned value(4 bit) to a HEX digit (0-F)
    function to_hex_char(val: unsigned) return character is
        constant HEX: string := "0123456789ABCDEF";
    begin
        if (val < 16) then
            return HEX(to_integer(val)+1);
        else
            return 'X';
        end if;
    end function;

    -- convert unsigend to hex string representation
    function to_hex_str(val: unsigned) return string is
        constant LEN: natural := 6;
        variable mystr: string(1 to 2+LEN);
        variable idx: natural;
    begin
        mystr := "0x";
        for i in LEN-1 downto 0 loop
            idx := i * 4;
            mystr(2+(i+1)) := to_hex_char(val(idx+3 downto idx));
        end loop;

        return mystr;
    end function;

begin

    test_data   <= test_data1;
    result_data <= result_data1;

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
    clk_process: process
    begin
        if hlt = '0' then
            clk <= '0';
            wait for clk_period/2;
            clk <= '1';
            wait for clk_period/2;
        end if;
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
        wait for clk_period;

        -- read data from dout
        for i in 0 to 15 loop
            dout_results(i) <= dout;

            -- print the results to stdout
            report "[" & integer'image(i) & "] (" &
                to_hex_str(unsigned(dout.r)) &
                ", " &
                to_hex_str(unsigned(dout.i)) &
                ")";

            wait for clk_period;
        end loop;

        for i in 0 to 15 loop
            -- assert that results are correct
            -- only real values are of interest
            assert dout_results(i).r = result_data(i).r
                   report LF & "wrong value [" & integer'image(i) & "]" & LF &
                   "  expected: " & to_hex_str(unsigned(result_data(i).r)) & LF &
                   "  got:          " & to_hex_str(unsigned(dout_results(i).r))
                   severity error;
        end loop;

        -- halt simulation
        hlt <= '1';

        wait;
    end process;

end;
