-- delay.vhd
--
-- Created on: 15 Jul 2017
--     Author: Fabian Meyer
--
--
-- Circular FIFO delay element.

library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_helpers.all;

entity delay is
    generic(RSTDEF:   std_logic := '0';
            DELAYLEN: natural   := 8);  -- can hold 2**DELAYLEN data samples
    port(rst:  in  std_logic; -- reset , RSTDEF active
         clk:  in  std_logic; -- clk, rising edge
         din:  in  complex;   -- data in
         dout: out complex);  -- data out
end delay;

architecture behavioral of delay is
    -- counter to keep track of write index
    signal w_cnt: unsigned(DELAYLEN-1 downto 0) := (others => '1');
    -- counter to keep track of read index
    signal r_cnt: unsigned(DELAYLEN-1 downto 0) := (others => '0');

    -- data array for circular buffer
    signal data: complex_arr((2**DELAYLEN)-1 downto 0)) := (others => COMPZERO);
begin

    process(rst, clk) is
    begin
        if rst = RSTDEF then
            w_cnt <= (others => '1');
            r_cnt <= (others => '0');
            data  <= (others => COMPZERO);
        elsif rising_edge(clk) then
            -- increment counters
            w_cnt <= w_cnt + 1;
            r_cnt <= r_cnt + 1;
            -- apply current input at write index
            data(to_integer(w_cnt)) <= din;
            -- apply data at read index to output
            dout <= data(to_integer(r_cnt));
        end if;
    end process;

end architecture;
